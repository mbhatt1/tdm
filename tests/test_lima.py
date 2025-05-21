"""
Tests for the Lima manager.
"""

import pytest
import os
import tempfile
import yaml
import json
from unittest.mock import patch, MagicMock

from tvm.pyrolima.lima import StatelessLimaManager

@pytest.fixture
def lima_manager():
    """Create a Lima manager for testing."""
    with patch("platform.system", return_value="Darwin"), \
         patch("psutil.virtual_memory") as mock_memory, \
         patch("psutil.cpu_count", return_value=4):
        
        # Mock memory
        mock_memory_info = MagicMock()
        mock_memory_info.total = 16 * 1024 * 1024 * 1024  # 16 GB
        mock_memory.return_value = mock_memory_info
        
        # Create manager
        manager = StatelessLimaManager()
        yield manager

def test_init(lima_manager):
    """Test initialization."""
    assert lima_manager.memory == "12GiB"  # 75% of 16 GB
    assert lima_manager.cpu == 3  # 75% of 4 cores
    assert lima_manager.lima_running is False
    assert lima_manager.instance_name is None
    assert lima_manager.temp_dir is None
    assert lima_manager.host_platform == "Darwin"
    assert lima_manager.virtualization_backend == "hyperkit"
    assert lima_manager.network_mode == "bridged"

def test_adapt_to_platform():
    """Test platform adaptation."""
    # Test macOS
    with patch("platform.system", return_value="Darwin"), \
         patch("psutil.virtual_memory") as mock_memory, \
         patch("psutil.cpu_count", return_value=4):
        
        # Mock memory
        mock_memory_info = MagicMock()
        mock_memory_info.total = 16 * 1024 * 1024 * 1024  # 16 GB
        mock_memory.return_value = mock_memory_info
        
        # Create manager
        manager = StatelessLimaManager()
        
        assert manager.host_platform == "Darwin"
        assert manager.virtualization_backend == "hyperkit"
        assert manager.network_mode == "bridged"
    
    # Test Windows
    with patch("platform.system", return_value="Windows"), \
         patch("psutil.virtual_memory") as mock_memory, \
         patch("psutil.cpu_count", return_value=4):
        
        # Mock memory
        mock_memory_info = MagicMock()
        mock_memory_info.total = 16 * 1024 * 1024 * 1024  # 16 GB
        mock_memory.return_value = mock_memory_info
        
        # Create manager
        manager = StatelessLimaManager()
        
        assert manager.host_platform == "Windows"
        assert manager.virtualization_backend == "wsl2"
        assert manager.network_mode == "host"
    
    # Test Linux
    with patch("platform.system", return_value="Linux"), \
         patch("psutil.virtual_memory") as mock_memory, \
         patch("psutil.cpu_count", return_value=4):
        
        # Mock memory
        mock_memory_info = MagicMock()
        mock_memory_info.total = 16 * 1024 * 1024 * 1024  # 16 GB
        mock_memory.return_value = mock_memory_info
        
        # Create manager
        manager = StatelessLimaManager()
        
        assert manager.host_platform == "Linux"
        assert manager.virtualization_backend == "qemu"
        assert manager.network_mode == "bridged"

def test_generate_lima_config(lima_manager):
    """Test generating Lima configuration."""
    # Test with port forwarding
    forwarded_ports = {
        8080: 80,
        8443: 443,
        15000: 15000,
        15443: 15443
    }
    
    config = lima_manager._generate_lima_config(forwarded_ports)
    
    # Check basic configuration
    assert config["memory"] == "12GiB"
    assert config["cpus"] == 3
    assert len(config["mounts"]) == 1
    assert config["containerd"]["system"] is True
    assert config["containerd"]["user"] is False
    
    # Check port forwarding
    assert len(config["portForwards"]) == 4
    for port_forward in config["portForwards"]:
        assert port_forward["hostPort"] in forwarded_ports
        assert port_forward["guestPort"] == forwarded_ports[port_forward["hostPort"]]
    
    # Check provisioning
    assert len(config["provision"]) == 1
    assert config["provision"][0]["mode"] == "system"
    assert "script" in config["provision"][0]
    
    # Check platform-specific configuration
    assert config["arch"] in ["x86_64", "aarch64"]
    assert "rosetta" in config
    assert config["mountType"] == "virtiofs"

def test_get_provision_script(lima_manager):
    """Test getting provisioning script."""
    script = lima_manager._get_provision_script()
    
    # Check that the script contains important sections
    assert "#!/bin/bash" in script
    assert "set -eux -o pipefail" in script
    assert "curl -sfL https://get.k3s.io" in script
    assert "ISTIO_VERSION=" in script
    assert "istioctl install" in script
    assert "kubectl create namespace tvm" in script
    assert "docker pull" in script

def test_start_lima(lima_manager):
    """Test starting Lima."""
    # Create a temporary directory
    with tempfile.TemporaryDirectory() as temp_dir, \
         patch("tempfile.mkdtemp", return_value=temp_dir), \
         patch("subprocess.run") as mock_run, \
         patch.object(lima_manager, "_wait_for_lima_ready", return_value=True), \
         patch.object(lima_manager, "_wait_for_k8s_ready", return_value=True), \
         patch.object(lima_manager, "_deploy_tvm_components", return_value=True):
        
        # Start Lima
        result = lima_manager.start_lima({8080: 80})
        
        # Check result
        assert result is True
        assert lima_manager.lima_running is True
        assert lima_manager.instance_name is not None
        assert lima_manager.temp_dir == temp_dir
        
        # Check that subprocess.run was called
        mock_run.assert_called()
        
        # Check that the config file was created
        config_path = os.path.join(temp_dir, "lima.yaml")
        assert os.path.exists(config_path)
        
        # Check the config file content
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)
            assert config["memory"] == "12GiB"
            assert config["cpus"] == 3

def test_stop_lima(lima_manager):
    """Test stopping Lima."""
    # Set up the manager
    lima_manager.lima_running = True
    lima_manager.instance_name = "tvm-test"
    lima_manager.temp_dir = tempfile.mkdtemp()
    
    # Mock subprocess.run
    with patch("subprocess.run") as mock_run, \
         patch.object(lima_manager, "_cleanup") as mock_cleanup:
        
        # Stop Lima
        result = lima_manager.stop_lima()
        
        # Check result
        assert result is True
        assert lima_manager.lima_running is False
        
        # Check that subprocess.run was called
        mock_run.assert_called()
        
        # Check that cleanup was called
        mock_cleanup.assert_called_once()
    
    # Clean up
    if os.path.exists(lima_manager.temp_dir):
        os.rmdir(lima_manager.temp_dir)

def test_cleanup(lima_manager):
    """Test cleanup."""
    # Create a temporary directory
    temp_dir = tempfile.mkdtemp()
    lima_manager.temp_dir = temp_dir
    
    # Cleanup
    lima_manager._cleanup()
    
    # Check that the directory was removed
    assert not os.path.exists(temp_dir)
    assert lima_manager.temp_dir is None

def test_wait_for_lima_ready(lima_manager):
    """Test waiting for Lima to be ready."""
    # Set up the manager
    lima_manager.instance_name = "tvm-test"
    
    # Mock subprocess.run
    with patch("subprocess.run") as mock_run:
        # Mock successful response
        mock_process = MagicMock()
        mock_process.stdout = "ready"
        mock_process.returncode = 0
        mock_run.return_value = mock_process
        
        # Wait for Lima
        result = lima_manager._wait_for_lima_ready()
        
        # Check result
        assert result is True
        
        # Check that subprocess.run was called
        mock_run.assert_called()
    
    # Mock failed response
    with patch("subprocess.run", side_effect=Exception("Failed")):
        # Wait for Lima
        result = lima_manager._wait_for_lima_ready()
        
        # Check result
        assert result is False

def test_wait_for_k8s_ready(lima_manager):
    """Test waiting for Kubernetes to be ready."""
    # Set up the manager
    lima_manager.instance_name = "tvm-test"
    
    # Mock subprocess.run
    with patch("subprocess.run") as mock_run:
        # Mock successful response for nodes
        mock_nodes_process = MagicMock()
        mock_nodes_process.stdout = "node-1   Ready"
        mock_nodes_process.returncode = 0
        
        # Mock successful response for Istio
        mock_istio_process = MagicMock()
        mock_istio_process.stdout = "istiod-1234   Running"
        mock_istio_process.returncode = 0
        
        # Set up the mock to return different values for different calls
        mock_run.side_effect = [mock_nodes_process, mock_istio_process]
        
        # Wait for K8s
        result = lima_manager._wait_for_k8s_ready()
        
        # Check result
        assert result is True
        
        # Check that subprocess.run was called
        assert mock_run.call_count == 2
    
    # Mock failed response
    with patch("subprocess.run", side_effect=Exception("Failed")):
        # Wait for K8s
        result = lima_manager._wait_for_k8s_ready()
        
        # Check result
        assert result is False

def test_deploy_tvm_components(lima_manager):
    """Test deploying TVM components."""
    # Set up the manager
    lima_manager.instance_name = "tvm-test"
    lima_manager.temp_dir = tempfile.mkdtemp()
    
    # Mock subprocess.run
    with patch("subprocess.run") as mock_run, \
         patch("json.loads") as mock_json_loads:
        
        # Mock successful response for kubectl apply
        mock_apply_process = MagicMock()
        mock_apply_process.returncode = 0
        
        # Mock successful response for kubectl get deployment
        mock_get_process = MagicMock()
        mock_get_process.stdout = "{}"
        mock_get_process.returncode = 0
        
        # Set up the mock to return different values for different calls
        mock_run.side_effect = [mock_apply_process, mock_get_process]
        
        # Mock JSON response
        mock_json_loads.return_value = {
            "status": {
                "readyReplicas": 1
            }
        }
        
        # Deploy components
        result = lima_manager._deploy_tvm_components()
        
        # Check result
        assert result is True
        
        # Check that subprocess.run was called
        assert mock_run.call_count == 2
        
        # Check that the manifest file was created
        manifest_path = os.path.join(lima_manager.temp_dir, "tvm-manifest.yaml")
        assert os.path.exists(manifest_path)
    
    # Clean up
    if os.path.exists(lima_manager.temp_dir):
        os.rmdir(lima_manager.temp_dir)