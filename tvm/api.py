"""
TVM API Server

Provides the main API endpoints for the TVM system.
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
import uuid
import os
import asyncio
import logging
from typing import Dict, Optional, List

from tvm.utils.logger import setup_logger
from tvm.pyrolima.lima import StatelessLimaManager

# Configure logging
logger = setup_logger("tvm-api")

# Models
class CodeExecutionRequest(BaseModel):
    code: str = Field(..., description="Source code to execute")
    language: str = Field(..., description="Programming language")
    language_version: Optional[str] = Field(None, description="Specific language version")
    timeout_ms: int = Field(5000, description="Execution timeout in milliseconds")
    memory_mb: int = Field(128, description="Memory limit in MB")
    cpu_count: int = Field(1, description="Number of CPU cores")
    
    class Config:
        schema_extra = {
            "example": {
                "code": "print('Hello, World!')",
                "language": "python",
                "language_version": "3.11",
                "timeout_ms": 5000,
                "memory_mb": 128,
                "cpu_count": 1
            }
        }

class CodeExecutionResponse(BaseModel):
    request_id: str = Field(..., description="Unique execution request ID")
    stdout: str = Field(..., description="Standard output from execution")
    stderr: str = Field(..., description="Standard error from execution")
    exit_code: int = Field(..., description="Exit code from execution")
    execution_time_ms: int = Field(..., description="Execution time in milliseconds")
    language: str = Field(..., description="Programming language")
    language_version: str = Field(..., description="Language version used for execution")

class HealthResponse(BaseModel):
    status: str = Field(..., description="Health status")
    version: str = Field(..., description="API version")
    lima_status: str = Field(..., description="Lima VM status")
    kubernetes_status: Optional[str] = Field(None, description="Kubernetes status")
    istio_status: Optional[str] = Field(None, description="Istio status")

# FastAPI application
app = FastAPI(
    title="TVM API Server",
    description="Stateless code execution in isolated environments",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Track running Lima instances - in memory only
lima_manager = None
# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 1.0  # seconds

@app.on_event("startup")
async def startup_event():
    """Initialize resources on startup."""
    global lima_manager
    lima_manager = StatelessLimaManager()
    logger.info("TVM API server started")

@app.on_event("shutdown")
async def shutdown_event():
    """Clean up resources on shutdown."""
    global lima_manager
    if lima_manager and lima_manager.lima_running:
        logger.info("Stopping Lima VM during shutdown")
        lima_manager.stop_lima()
    logger.info("TVM API server stopped")

@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint.
    
    Returns:
        Health status of the TVM system
    """
    global lima_manager
    
    # Check Lima status
    lima_status = "Not running"
    kubernetes_status = None
    istio_status = None
    
    if lima_manager and lima_manager.lima_running:
        lima_status = "Running"
        
        # Check Kubernetes status
        try:
            k8s_running = await _check_kubernetes_health()
            kubernetes_status = "Running" if k8s_running else "Not running"
            
            # Check Istio status
            if k8s_running:
                istio_running = await _check_istio_health()
                istio_status = "Running" if istio_running else "Not running"
        except:
            kubernetes_status = "Error"
    
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        lima_status=lima_status,
        kubernetes_status=kubernetes_status,
        istio_status=istio_status
    )

@app.post("/api/execute", response_model=CodeExecutionResponse)
async def execute_code(request: CodeExecutionRequest, background_tasks: BackgroundTasks):
    """
    Execute code in an isolated microVM.
    Completely stateless operation with no persistence.
    
    Args:
        request: The code execution request
        background_tasks: Background tasks for cleanup
        
    Returns:
        The code execution response
    """
    global lima_manager
    
    # Validate language and version
    if not _is_supported_language(request.language, request.language_version):
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported language or version: {request.language} {request.language_version}"
        )
    
    # Validate resource limits
    if not _validate_resource_limits(request):
        raise HTTPException(
            status_code=400,
            detail="Resource limits exceed maximum allowed values"
        )
    
    # Ensure Lima is running
    lima_running = await _ensure_lima_running()
    if not lima_running:
        raise HTTPException(
            status_code=500,
            detail="Failed to start virtualization environment"
        )
    
    # Generate ephemeral request ID
    request_id = str(uuid.uuid4())
    logger.info(f"Processing execution request {request_id} for {request.language}")
    
    # Circuit breaker pattern for retries
    for attempt in range(MAX_RETRIES):
        try:
            # Forward request to Istio ingress gateway
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "http://localhost:15000/api/execute", 
                    json={
                        "request_id": request_id,
                        "code": request.code,
                        "language": request.language,
                        "language_version": request.language_version,
                        "timeout_ms": request.timeout_ms,
                        "memory_mb": request.memory_mb,
                        "cpu_count": request.cpu_count
                    },
                    timeout=request.timeout_ms / 1000 + 3  # Add buffer for network
                )
                
                if response.status_code != 200:
                    if attempt < MAX_RETRIES - 1:
                        logger.warning(f"Request {request_id} failed with status {response.status_code}, retrying...")
                        await asyncio.sleep(RETRY_DELAY * (attempt + 1))  # Exponential backoff
                        continue
                    
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Execution service error: {response.text}"
                    )
                    
                result = response.json()
                logger.info(f"Request {request_id} completed successfully")
                return CodeExecutionResponse(
                    request_id=request_id,
                    stdout=result.get("stdout", ""),
                    stderr=result.get("stderr", ""),
                    exit_code=result.get("exit_code", -1),
                    execution_time_ms=result.get("execution_time_ms", 0),
                    language=request.language,
                    language_version=result.get("language_version", request.language_version or "")
                )
                
        except httpx.TimeoutException:
            if attempt < MAX_RETRIES - 1:
                logger.warning(f"Request {request_id} timed out, retrying...")
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))
                continue
                
            logger.error(f"Request {request_id} failed after {MAX_RETRIES} attempts")
            raise HTTPException(
                status_code=408,
                detail="Execution timed out after multiple attempts"
            )
        except Exception as e:
            logger.error(f"Unexpected error for request {request_id}: {str(e)}")
            if attempt < MAX_RETRIES - 1:
                await asyncio.sleep(RETRY_DELAY * (attempt + 1))
                continue
                
            raise HTTPException(
                status_code=500,
                detail=f"Internal server error: {str(e)}"
            )
    
    # This should never be reached due to the loop structure
    raise HTTPException(status_code=500, detail="Internal server error")

async def _ensure_lima_running():
    """
    Ensure Lima VM is running, start if needed.
    
    Returns:
        True if Lima is running, False otherwise
    """
    global lima_manager
    
    if not lima_manager:
        lima_manager = StatelessLimaManager()
    
    if not lima_manager.lima_running:
        logger.info("Starting Lima VM")
        # Start Lima with required ports
        ports = {
            8080: 80,    # HTTP
            8443: 443,   # HTTPS
            15000: 15000,  # Istio ingress
            15443: 15443,  # Istio egress
        }
        return lima_manager.start_lima(forwarded_ports=ports)
    
    # Check health of existing Lima VM
    if not await _check_lima_health():
        logger.warning("Lima VM is unhealthy, restarting")
        lima_manager.stop_lima()
        # Re-run this function to start Lima
        return await _ensure_lima_running()
    
    return True

async def _check_lima_health():
    """
    Check if Lima VM is healthy.
    
    Returns:
        True if Lima is healthy, False otherwise
    """
    try:
        # Simple health check by trying to connect to Istio ingress
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "http://localhost:15000/healthz",
                timeout=2.0
            )
            return response.status_code == 200
    except:
        return False

async def _check_kubernetes_health():
    """
    Check if Kubernetes is healthy.
    
    Returns:
        True if Kubernetes is healthy, False otherwise
    """
    global lima_manager
    
    if not lima_manager or not lima_manager.lima_running:
        return False
    
    try:
        # Check if nodes are ready
        result = await asyncio.create_subprocess_exec(
            "limactl", "shell", lima_manager.instance_name, "kubectl", "get", "nodes",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await result.communicate()
        
        return result.returncode == 0 and b"Ready" in stdout
    except:
        return False

async def _check_istio_health():
    """
    Check if Istio is healthy.
    
    Returns:
        True if Istio is healthy, False otherwise
    """
    global lima_manager
    
    if not lima_manager or not lima_manager.lima_running:
        return False
    
    try:
        # Check if Istio pods are running
        result = await asyncio.create_subprocess_exec(
            "limactl", "shell", lima_manager.instance_name, "kubectl", "get", "pods", "-n", "istio-system",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await result.communicate()
        
        return result.returncode == 0 and b"istiod" in stdout and b"Running" in stdout
    except:
        return False

def _is_supported_language(language: str, version: Optional[str] = None) -> bool:
    """
    Check if language and version are supported.
    
    Args:
        language: The programming language
        version: The language version
        
    Returns:
        True if the language and version are supported, False otherwise
    """
    supported_languages = {
        "python": ["3.8", "3.9", "3.10", "3.11", None],
        "javascript": ["16", "18", "20", None],
        "ruby": ["2.7", "3.0", "3.1", None],
        "go": ["1.18", "1.19", "1.20", None],
        "rust": ["1.65", "1.70", None],
        "java": ["11", "17", None],
        "c": ["gcc11", "clang14", None],
        "cpp": ["gcc11", "clang14", None]
    }
    
    if language not in supported_languages:
        return False
    
    if version is not None and version not in supported_languages[language]:
        return False
    
    return True

def _validate_resource_limits(request: CodeExecutionRequest) -> bool:
    """
    Validate that resource limits are within allowed ranges.
    
    Args:
        request: The code execution request
        
    Returns:
        True if resource limits are valid, False otherwise
    """
    # Maximum allowed values
    max_memory = 2048  # MB
    max_cpu = 4  # cores
    max_timeout = 60000  # ms
    
    # Language-specific limits
    language_limits = {
        "python": {"memory": 2048, "cpu": 4, "timeout": 60000},
        "javascript": {"memory": 1536, "cpu": 4, "timeout": 30000},
        "ruby": {"memory": 1024, "cpu": 2, "timeout": 30000},
        "go": {"memory": 1024, "cpu": 4, "timeout": 30000},
        "rust": {"memory": 1024, "cpu": 4, "timeout": 30000},
        "java": {"memory": 2048, "cpu": 4, "timeout": 60000},
        "c": {"memory": 1024, "cpu": 4, "timeout": 30000},
        "cpp": {"memory": 1024, "cpu": 4, "timeout": 30000}
    }
    
    # Get language-specific limits or use defaults
    limits = language_limits.get(request.language, {"memory": max_memory, "cpu": max_cpu, "timeout": max_timeout})
    
    # Check if requested resources exceed limits
    if request.memory_mb > limits["memory"]:
        return False
    if request.cpu_count > limits["cpu"]:
        return False
    if request.timeout_ms > limits["timeout"]:
        return False
    
    return True