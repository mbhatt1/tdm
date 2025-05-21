"""
Tests for the TVM API.
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

from tvm.api import app

client = TestClient(app)

@pytest.fixture
def mock_lima_manager():
    """Mock the Lima manager."""
    with patch("tvm.api.StatelessLimaManager") as mock:
        instance = MagicMock()
        instance.lima_running = True
        instance.instance_name = "tvm-test"
        mock.return_value = instance
        yield instance

def test_health_check(mock_lima_manager):
    """Test the health check endpoint."""
    # Mock the Kubernetes and Istio health checks
    with patch("tvm.api._check_kubernetes_health", return_value=True), \
         patch("tvm.api._check_istio_health", return_value=True):
        response = client.get("/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["lima_status"] == "Running"
        assert data["kubernetes_status"] == "Running"
        assert data["istio_status"] == "Running"

def test_execute_code_validation():
    """Test code execution request validation."""
    # Test with invalid language
    response = client.post(
        "/api/execute",
        json={
            "code": "print('Hello, World!')",
            "language": "invalid-language",
            "timeout_ms": 5000,
            "memory_mb": 128,
            "cpu_count": 1
        }
    )
    assert response.status_code == 400
    assert "Unsupported language" in response.json()["detail"]
    
    # Test with invalid resource limits
    response = client.post(
        "/api/execute",
        json={
            "code": "print('Hello, World!')",
            "language": "python",
            "timeout_ms": 5000,
            "memory_mb": 9999,  # Too much memory
            "cpu_count": 1
        }
    )
    assert response.status_code == 400
    assert "Resource limits" in response.json()["detail"]

@pytest.mark.asyncio
async def test_execute_code_success(mock_lima_manager):
    """Test successful code execution."""
    # Mock the Lima health check
    with patch("tvm.api._check_lima_health", return_value=True), \
         patch("httpx.AsyncClient.post") as mock_post:
        # Mock the response from the Istio ingress
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "stdout": "Hello, World!",
            "stderr": "",
            "exit_code": 0,
            "execution_time_ms": 100,
            "language_version": "3.11"
        }
        mock_post.return_value = mock_response
        
        # Make the request
        response = client.post(
            "/api/execute",
            json={
                "code": "print('Hello, World!')",
                "language": "python",
                "language_version": "3.11",
                "timeout_ms": 5000,
                "memory_mb": 128,
                "cpu_count": 1
            }
        )
        
        # Check the response
        assert response.status_code == 200
        data = response.json()
        assert data["stdout"] == "Hello, World!"
        assert data["stderr"] == ""
        assert data["exit_code"] == 0
        assert data["execution_time_ms"] == 100
        assert data["language"] == "python"
        assert data["language_version"] == "3.11"