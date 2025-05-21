"""
Tests for the Firecracker manager.
"""

import pytest
import asyncio
import os
import tempfile
from unittest.mock import patch, MagicMock, AsyncMock

from tvm.pyrovm.firecracker import FirecrackerManager, ExecutionRequest

@pytest.fixture
def firecracker_manager():
    """Create a Firecracker manager for testing."""
    manager = FirecrackerManager()
    # Patch the garbage collection task to avoid background tasks during tests
    manager.gc_task = None
    return manager

@pytest.fixture
def execution_request():
    """Create a sample execution request."""
    return ExecutionRequest(
        request_id="test-request-id",
        code="print('Hello, World!')",
        language="python",
        language_version="3.11",
        timeout_ms=5000,
        memory_mb=128,
        cpu_count=1
    )

def test_get_language_image(firecracker_manager):
    """Test getting language images."""
    # Test valid languages and versions
    assert firecracker_manager.get_language_image("python", "3.11") == "python:3.11-slim"
    assert firecracker_manager.get_language_image("javascript", "18") == "node:18-slim"
    assert firecracker_manager.get_language_image("ruby", "3.1") == "ruby:3.1-slim"
    
    # Test default versions
    assert firecracker_manager.get_language_image("python", None) == "python:3.11-slim"
    assert firecracker_manager.get_language_image("javascript", None) == "node:18-slim"
    
    # Test invalid language
    assert firecracker_manager.get_language_image("invalid-language", None) is None

def test_get_file_extension(firecracker_manager):
    """Test getting file extensions."""
    assert firecracker_manager.get_file_extension("python") == "py"
    assert firecracker_manager.get_file_extension("javascript") == "js"
    assert firecracker_manager.get_file_extension("ruby") == "rb"
    assert firecracker_manager.get_file_extension("go") == "go"
    assert firecracker_manager.get_file_extension("rust") == "rs"
    assert firecracker_manager.get_file_extension("java") == "java"
    assert firecracker_manager.get_file_extension("c") == "c"
    assert firecracker_manager.get_file_extension("cpp") == "cpp"
    assert firecracker_manager.get_file_extension("invalid-language") == "txt"

def test_get_execution_command(firecracker_manager):
    """Test getting execution commands."""
    assert firecracker_manager.get_execution_command("python", "code.py") == ["python", "code.py"]
    assert firecracker_manager.get_execution_command("javascript", "code.js") == ["node", "code.js"]
    assert firecracker_manager.get_execution_command("ruby", "code.rb") == ["ruby", "code.rb"]
    assert firecracker_manager.get_execution_command("go", "code.go") == ["go", "run", "code.go"]
    assert firecracker_manager.get_execution_command("invalid-language", "code.txt") == ["cat", "code.txt"]

@pytest.mark.asyncio
async def test_start_vm(firecracker_manager):
    """Test starting a VM."""
    # Create a temporary directory for the VM
    with tempfile.TemporaryDirectory() as vm_dir:
        # Mock the subprocess and aiohttp
        with patch("asyncio.create_subprocess_exec", return_value=AsyncMock()) as mock_subprocess, \
             patch("aiohttp.ClientSession") as mock_session, \
             patch("os.path.exists", return_value=True):
            
            # Mock the aiohttp response
            mock_response = AsyncMock()
            mock_response.status = 204
            mock_session.return_value.__aenter__.return_value.put.return_value.__aenter__.return_value = mock_response
            
            # Start the VM
            vm_id = await firecracker_manager.start_vm(
                vm_dir=vm_dir,
                memory_mb=128,
                cpu_count=1,
                language_image="python:3.11-slim"
            )
            
            # Check that the VM was started
            assert vm_id in firecracker_manager.active_vms
            assert firecracker_manager.active_vms[vm_id]["vm_dir"] == vm_dir
            assert "process" in firecracker_manager.active_vms[vm_id]
            assert "socket_path" in firecracker_manager.active_vms[vm_id]
            assert "start_time" in firecracker_manager.active_vms[vm_id]
            
            # Check that the subprocess was called
            mock_subprocess.assert_called_once()
            
            # Clean up
            await firecracker_manager.terminate_vm(vm_id)

@pytest.mark.asyncio
async def test_execute_in_vm(firecracker_manager):
    """Test executing code in a VM."""
    # Create a temporary directory for the VM
    with tempfile.TemporaryDirectory() as vm_dir:
        # Create a test code file
        code_path = os.path.join(vm_dir, "code.py")
        with open(code_path, "w") as f:
            f.write("print('Hello, World!')")
        
        # Mock the VM
        vm_id = "test-vm-id"
        firecracker_manager.active_vms[vm_id] = {
            "vm_dir": vm_dir,
            "process": AsyncMock(),
            "socket_path": "/tmp/test-socket",
            "start_time": 0
        }
        
        # Mock the subprocess
        with patch("asyncio.create_subprocess_exec") as mock_subprocess:
            # Mock the process
            mock_process = AsyncMock()
            mock_process.communicate.return_value = (b"Hello, World!", b"")
            mock_process.returncode = 0
            mock_subprocess.return_value = mock_process
            
            # Execute the code
            result = await firecracker_manager.execute_in_vm(vm_id, code_path, "python")
            
            # Check the result
            assert result["stdout"] == "Hello, World!"
            assert result["stderr"] == ""
            assert result["exit_code"] == 0
            
            # Check that the subprocess was called
            mock_subprocess.assert_called_once_with(
                "python", code_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=vm_dir
            )
            
            # Clean up
            await firecracker_manager.terminate_vm(vm_id)

@pytest.mark.asyncio
async def test_terminate_vm(firecracker_manager):
    """Test terminating a VM."""
    # Create a temporary directory for the VM
    with tempfile.TemporaryDirectory() as vm_dir:
        # Mock the VM
        vm_id = "test-vm-id"
        mock_process = AsyncMock()
        mock_process.wait.return_value = 0
        
        firecracker_manager.active_vms[vm_id] = {
            "vm_dir": vm_dir,
            "process": mock_process,
            "socket_path": "/tmp/test-socket",
            "start_time": 0
        }
        
        # Mock os.path.exists and os.unlink
        with patch("os.path.exists", return_value=True), \
             patch("os.unlink"):
            
            # Terminate the VM
            result = await firecracker_manager.terminate_vm(vm_id)
            
            # Check the result
            assert result is True
            assert vm_id not in firecracker_manager.active_vms
            
            # Check that the process was terminated
            mock_process.terminate.assert_called_once()