"""
Firecracker management for the TVM system.

Manages Firecracker microVMs for code execution.
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import tempfile
import os
import uuid
import json
import asyncio
import logging
import aiofiles
import time
import shutil
from typing import Dict, Optional, List, Set, Tuple
import aiohttp
import threading
import socket
import fcntl
import struct
import resource
import psutil

from tvm.utils.logger import setup_logger

# Configure logging
logger = setup_logger("tvm-firecracker")

# Models
class ExecutionRequest(BaseModel):
    request_id: str
    code: str
    language: str
    language_version: Optional[str] = None
    timeout_ms: int = 5000
    memory_mb: int = 128
    cpu_count: int = 1

class ExecutionResponse(BaseModel):
    request_id: str
    stdout: str
    stderr: str
    exit_code: int
    execution_time_ms: int
    language_version: str

# VM execution statistics
execution_stats = {
    "total_requests": 0,
    "successful_executions": 0,
    "failed_executions": 0,
    "total_execution_time_ms": 0,
    "vm_starts": 0,
}

# Resource limits
MAX_CONCURRENT_VMS = 10  # Maximum number of concurrent VMs per pod
MAX_VM_LIFETIME_SECONDS = 60  # Maximum VM lifetime to prevent leaks
MAX_CONCURRENT_REQUESTS = 20  # Maximum concurrent requests

# Track active VMs - completely in-memory
active_vms: Dict[str, Dict] = {}

# Garbage collection lock
gc_lock = asyncio.Lock()

class FirecrackerManager:
    """Manages Firecracker microVMs for code execution."""
    
    def __init__(self):
        """Initialize the Firecracker manager."""
        # Configure system limits
        try:
            # Increase file descriptor limits
            resource.setrlimit(resource.RLIMIT_NOFILE, (10000, 10000))
            
            # Configure CPU and memory settings for optimal Firecracker performance
            os.system("echo 1 > /proc/sys/vm/overcommit_memory")
        except Exception as e:
            logger.warning(f"Failed to set system limits: {e}")
        
        # Start background garbage collection task
        self.gc_task = None
    
    async def start_garbage_collection(self):
        """Start the background garbage collection task."""
        if self.gc_task is None:
            self.gc_task = asyncio.create_task(self.garbage_collection_task())
    
    async def garbage_collection_task(self):
        """Background task to clean up orphaned VMs and resources."""
        while True:
            try:
                async with gc_lock:
                    current_time = time.time()
                    vm_ids_to_terminate = []
                    
                    # Find VMs that have been running too long
                    for vm_id, vm_info in active_vms.items():
                        start_time = vm_info.get("start_time", 0)
                        if current_time - start_time > MAX_VM_LIFETIME_SECONDS:
                            vm_ids_to_terminate.append(vm_id)
                    
                    # Terminate identified VMs
                    for vm_id in vm_ids_to_terminate:
                        logger.warning(f"Garbage collecting VM {vm_id} due to excessive lifetime")
                        try:
                            await self.terminate_vm(vm_id)
                        except Exception as e:
                            logger.error(f"Failed to garbage collect VM {vm_id}: {e}")
                    
                    # Clean up any orphaned socket files in /tmp
                    socket_files = [f for f in os.listdir("/tmp") if f.startswith("firecracker-") and f.endswith(".sock")]
                    for socket_file in socket_files:
                        socket_path = os.path.join("/tmp", socket_file)
                        vm_id = socket_file.replace("firecracker-", "").replace(".sock", "")
                        
                        if vm_id not in active_vms:
                            try:
                                os.unlink(socket_path)
                                logger.info(f"Cleaned up orphaned socket file: {socket_path}")
                            except:
                                pass
            
            except Exception as e:
                logger.error(f"Error in garbage collection task: {e}")
            
            # Run garbage collection every 10 seconds
            await asyncio.sleep(10)
    
    async def execute_code(self, request: ExecutionRequest) -> Dict:
        """
        Execute code in a completely stateless Firecracker VM.
        
        Args:
            request: The execution request
            
        Returns:
            The execution response
        """
        # Update statistics
        execution_stats["total_requests"] += 1
        
        start_time = time.time()
        
        try:
            # Create a temporary directory for VM resources
            # Use /dev/shm if available for better performance
            base_dir = "/dev/shm" if os.path.exists("/dev/shm") else "/tmp"
            vm_dir = tempfile.mkdtemp(prefix="pyrovm-", dir=base_dir)
            
            # Validate language and version
            language_image = self.get_language_image(request.language, request.language_version)
            if not language_image:
                raise ValueError(f"Unsupported language or version: {request.language} {request.language_version}")
            
            # Write code to temporary file
            code_path = os.path.join(vm_dir, f"code.{self.get_file_extension(request.language)}")
            async with aiofiles.open(code_path, 'w') as f:
                await f.write(request.code)
            
            # Start and configure Firecracker VM
            vm_id = await self.start_vm(
                vm_dir=vm_dir,
                memory_mb=request.memory_mb,
                cpu_count=request.cpu_count,
                language_image=language_image
            )
            
            # Execute code in VM with timeout
            try:
                result = await asyncio.wait_for(
                    self.execute_in_vm(vm_id, code_path, request.language),
                    timeout=request.timeout_ms / 1000
                )
                execution_stats["successful_executions"] += 1
            except asyncio.TimeoutError:
                result = {
                    "stdout": "",
                    "stderr": "Execution timed out",
                    "exit_code": -1
                }
                execution_stats["failed_executions"] += 1
            finally:
                # Schedule VM termination
                asyncio.create_task(self.terminate_vm(vm_id))
            
            # Calculate execution time
            execution_time_ms = int((time.time() - start_time) * 1000)
            execution_stats["total_execution_time_ms"] += execution_time_ms
            
            return {
                "request_id": request.request_id,
                "stdout": result.get("stdout", ""),
                "stderr": result.get("stderr", ""),
                "exit_code": result.get("exit_code", -1),
                "execution_time_ms": execution_time_ms,
                "language_version": request.language_version or self.get_default_version(request.language)
            }
        
        except Exception as e:
            logger.error(f"Error executing code: {str(e)}")
            execution_stats["failed_executions"] += 1
            raise
    
    async def start_vm(self, vm_dir: str, memory_mb: int, cpu_count: int, language_image: str) -> str:
        """
        Start a completely stateless Firecracker VM.
        
        Args:
            vm_dir: The directory for VM resources
            memory_mb: The amount of memory to allocate to the VM
            cpu_count: The number of CPU cores to allocate to the VM
            language_image: The container image for the language runtime
            
        Returns:
            The VM ID
        """
        # Generate unique VM ID
        vm_id = str(uuid.uuid4())
        execution_stats["vm_starts"] += 1
        
        # Create Firecracker socket path
        socket_path = os.path.join("/tmp", f"firecracker-{vm_id}.sock")
        
        # Prepare VM configuration
        kernel_path = "/usr/local/bin/vmlinux"  # Path to kernel in the container
        rootfs_path = "/usr/local/bin/rootfs.ext4"  # Path to rootfs in the container
        
        # Start Firecracker process
        process = await asyncio.create_subprocess_exec(
            "firecracker",
            "--api-sock", socket_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        # Configure VM via API
        # Wait for socket to be available
        for _ in range(10):
            if os.path.exists(socket_path):
                break
            await asyncio.sleep(0.1)
        
        # Configure VM via HTTP API
        async with aiohttp.ClientSession() as session:
            # Configure boot source
            boot_config = {
                "kernel_image_path": kernel_path,
                "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
            }
            async with session.put(
                f"http://localhost/firecracker.socket/boot-source",
                json=boot_config
            ) as response:
                if response.status != 204:
                    raise Exception(f"Failed to configure boot source: {await response.text()}")
            
            # Configure machine resources
            machine_config = {
                "vcpu_count": cpu_count,
                "mem_size_mib": memory_mb,
                "track_dirty_pages": False  # No snapshotting
            }
            async with session.put(
                f"http://localhost/firecracker.socket/machine-config",
                json=machine_config
            ) as response:
                if response.status != 204:
                    raise Exception(f"Failed to configure machine: {await response.text()}")
            
            # Configure rootfs
            rootfs_config = {
                "drive_id": "rootfs",
                "path_on_host": rootfs_path,
                "is_root_device": True,
                "is_read_only": True  # Read-only for statelessness
            }
            async with session.put(
                f"http://localhost/firecracker.socket/drives/rootfs",
                json=rootfs_config
            ) as response:
                if response.status != 204:
                    raise Exception(f"Failed to configure rootfs: {await response.text()}")
            
            # Start VM
            async with session.put(
                f"http://localhost/firecracker.socket/actions",
                json={"action_type": "InstanceStart"}
            ) as response:
                if response.status != 204:
                    raise Exception(f"Failed to start VM: {await response.text()}")
        
        # Store VM information
        active_vms[vm_id] = {
            "process": process,
            "socket_path": socket_path,
            "vm_dir": vm_dir,
            "start_time": time.time()
        }
        
        return vm_id
    
    async def execute_in_vm(self, vm_id: str, code_path: str, language: str) -> Dict:
        """
        Execute code in VM and return results.
        
        Args:
            vm_id: The VM ID
            code_path: The path to the code file
            language: The programming language
            
        Returns:
            The execution results
        """
        if vm_id not in active_vms:
            raise Exception(f"VM {vm_id} not found")
        
        vm_info = active_vms[vm_id]
        vm_dir = vm_info["vm_dir"]
        
        # Simple execution for demonstration
        # In a real implementation, you would inject the code into the VM
        # and execute it using vsock or similar mechanism
        
        # Prepare execution command based on language
        command = self.get_execution_command(language, code_path)
        
        # Execute the code
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=vm_dir
        )
        
        stdout, stderr = await process.communicate()
        
        return {
            "stdout": stdout.decode('utf-8', errors='replace'),
            "stderr": stderr.decode('utf-8', errors='replace'),
            "exit_code": process.returncode
        }
    
    async def terminate_vm(self, vm_id: str) -> bool:
        """
        Terminate VM and clean up all resources.
        
        Args:
            vm_id: The VM ID
            
        Returns:
            True if VM was terminated successfully, False otherwise
        """
        if vm_id not in active_vms:
            return False
        
        vm_info = active_vms[vm_id]
        
        try:
            # Stop Firecracker process
            process = vm_info["process"]
            try:
                process.terminate()
                await asyncio.wait_for(process.wait(), timeout=2.0)
            except:
                # Force kill if graceful termination fails
                try:
                    process.kill()
                except:
                    pass
            
            # Clean up socket
            socket_path = vm_info["socket_path"]
            if os.path.exists(socket_path):
                try:
                    os.unlink(socket_path)
                except:
                    pass
            
            # Clean up VM directory
            vm_dir = vm_info["vm_dir"]
            if os.path.exists(vm_dir):
                try:
                    shutil.rmtree(vm_dir)
                except:
                    pass
            
            # Remove from active VMs
            del active_vms[vm_id]
            
            return True
        except Exception as e:
            logger.error(f"Error terminating VM {vm_id}: {e}")
            return False
    
    def get_language_image(self, language: str, version: Optional[str] = None) -> str:
        """
        Get container image for language and version.
        
        Args:
            language: The programming language
            version: The language version
            
        Returns:
            The container image name
        """
        language_images = {
            "python": {
                "3.8": "python:3.8-slim",
                "3.9": "python:3.9-slim",
                "3.10": "python:3.10-slim", 
                "3.11": "python:3.11-slim",
                None: "python:3.11-slim"  # Default
            },
            "javascript": {
                "16": "node:16-slim",
                "18": "node:18-slim",
                "20": "node:20-slim",
                None: "node:18-slim"  # Default
            },
            "ruby": {
                "2.7": "ruby:2.7-slim",
                "3.0": "ruby:3.0-slim",
                "3.1": "ruby:3.1-slim",
                None: "ruby:3.1-slim"  # Default
            },
            "go": {
                "1.18": "golang:1.18-alpine",
                "1.19": "golang:1.19-alpine",
                "1.20": "golang:1.20-alpine",
                None: "golang:1.20-alpine"  # Default
            },
            "rust": {
                "1.65": "rust:1.65-slim",
                "1.70": "rust:1.70-slim",
                None: "rust:1.70-slim"  # Default
            },
            "java": {
                "11": "openjdk:11-slim",
                "17": "openjdk:17-slim",
                None: "openjdk:17-slim"  # Default
            },
            "c": {
                "gcc11": "gcc:11",
                "clang14": "silkeh/clang:14",
                None: "gcc:11"  # Default
            },
            "cpp": {
                "gcc11": "gcc:11",
                "clang14": "silkeh/clang:14",
                None: "gcc:11"  # Default
            }
        }
        
        if language not in language_images:
            return None
        
        versions = language_images[language]
        if version not in versions:
            # Return default version
            return versions[None]
        
        return versions[version]
    
    def get_default_version(self, language: str) -> str:
        """
        Get default version for language.
        
        Args:
            language: The programming language
            
        Returns:
            The default version
        """
        defaults = {
            "python": "3.11",
            "javascript": "18",
            "ruby": "3.1",
            "go": "1.20",
            "rust": "1.70",
            "java": "17",
            "c": "gcc11",
            "cpp": "gcc11"
        }
        
        return defaults.get(language, "")
    
    def get_file_extension(self, language: str) -> str:
        """
        Get file extension for language.
        
        Args:
            language: The programming language
            
        Returns:
            The file extension
        """
        extensions = {
            "python": "py",
            "javascript": "js",
            "ruby": "rb",
            "go": "go",
            "rust": "rs",
            "java": "java",
            "c": "c",
            "cpp": "cpp"
        }
        
        return extensions.get(language, "txt")
    
    def get_execution_command(self, language: str, code_path: str) -> List[str]:
        """
        Get execution command for language.
        
        Args:
            language: The programming language
            code_path: The path to the code file
            
        Returns:
            The execution command
        """
        commands = {
            "python": ["python", code_path],
            "javascript": ["node", code_path],
            "ruby": ["ruby", code_path],
            "go": ["go", "run", code_path],
            "rust": ["rustc", code_path, "-o", "output", "&&", "./output"],
            "java": ["javac", code_path, "&&", "java", "Main"],
            "c": ["gcc", code_path, "-o", "output", "&&", "./output"],
            "cpp": ["g++", code_path, "-o", "output", "&&", "./output"]
        }
        
        return commands.get(language, ["cat", code_path])
    
    def get_stats(self) -> Dict:
        """
        Get execution statistics.
        
        Returns:
            The execution statistics
        """
        return {
            **execution_stats,
            "active_vms": len(active_vms)
        }