"""
FastAPI server for the Firecracker VM service.
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import logging
from typing import Dict, Optional

from tvm.utils.logger import setup_logger
from tvm.pyrovm.firecracker import FirecrackerManager, ExecutionRequest, ExecutionResponse

# Configure logging
logger = setup_logger("tvm-pyrovm-api")

# FastAPI application
app = FastAPI(title="PyroVM - Stateless Firecracker Manager")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Firecracker manager
firecracker_manager = None

# Semaphore to limit concurrent executions
concurrency_limiter = None

@app.on_event("startup")
async def startup_event():
    """Initialize resources on startup."""
    global firecracker_manager, concurrency_limiter
    
    logger.info("PyroVM service starting")
    
    # Initialize Firecracker manager
    firecracker_manager = FirecrackerManager()
    
    # Initialize concurrency limiter
    concurrency_limiter = asyncio.Semaphore(20)  # Maximum concurrent requests
    
    # Start background garbage collection task
    await firecracker_manager.start_garbage_collection()

@app.on_event("shutdown")
async def shutdown_event():
    """Clean up resources on shutdown."""
    logger.info("PyroVM service shutting down")
    
    # Stop all active VMs
    if firecracker_manager:
        for vm_id in list(firecracker_manager.active_vms.keys()):
            try:
                await firecracker_manager.terminate_vm(vm_id)
            except:
                pass

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes."""
    # Check if Firecracker manager is initialized
    if not firecracker_manager:
        raise HTTPException(status_code=503, detail="Firecracker manager not initialized")
    
    # Get statistics
    stats = firecracker_manager.get_stats()
    
    # If too many active VMs, report unhealthy
    if stats["active_vms"] >= 20:  # Maximum concurrent VMs
        raise HTTPException(status_code=503, detail="Too many active VMs")
    
    return {
        "status": "healthy",
        "active_vms": stats["active_vms"],
        "stats": stats
    }

@app.post("/execute", response_model=ExecutionResponse)
async def execute_code(request: ExecutionRequest, background_tasks: BackgroundTasks):
    """
    Execute code in completely stateless Firecracker VM.
    No snapshots or persistence of any kind.
    
    Args:
        request: The execution request
        background_tasks: Background tasks for cleanup
        
    Returns:
        The execution response
    """
    # Check if Firecracker manager is initialized
    if not firecracker_manager:
        raise HTTPException(status_code=503, detail="Firecracker manager not initialized")
    
    # Acquire semaphore to limit concurrent executions
    async with concurrency_limiter:
        try:
            # Execute code
            result = await firecracker_manager.execute_code(request)
            
            return ExecutionResponse(
                request_id=result["request_id"],
                stdout=result["stdout"],
                stderr=result["stderr"],
                exit_code=result["exit_code"],
                execution_time_ms=result["execution_time_ms"],
                language_version=result["language_version"]
            )
        
        except Exception as e:
            logger.error(f"Error executing code: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Execution failed: {str(e)}"
            )