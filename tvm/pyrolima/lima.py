"""
Lima management for the TVM system.

Manages the Lima virtualization layer with zero persistence.
"""

import os
import subprocess
import tempfile
import yaml
import time
import shutil
import logging
import json
import platform
import psutil
from typing import Dict, Optional, List, Tuple

from tvm.utils.logger import setup_logger

# Configure logging
logger = setup_logger("tvm-lima")

class StatelessLimaManager:
    """Manages Lima VM with no persistent state."""
    
    def __init__(self, memory: str = "4GiB", cpu: int = 4):
        """
        Initialize with resource configuration but store nothing on disk.
        
        Args:
            memory: The amount of memory to allocate to the VM
            cpu: The number of CPU cores to allocate to the VM
        """
        self.memory = memory
        self.cpu = cpu
        self.lima_running = False
        self.instance_name = None
        self.temp_dir = None
        
        # Detect host platform and adjust configuration
        self.host_platform = platform.system()
        self.adapt_to_platform()
    
    def adapt_to_platform(self):
        """Adapt configuration based on host platform."""
        # Detect available resources
        total_memory = psutil.virtual_memory().total
        total_cpus = psutil.cpu_count(logical=False) or 2
        
        # Use at most 75% of system resources
        lima_memory_gb = max(2, int(total_memory * 0.75 / (1024 * 1024 * 1024)))
        lima_cpus = max(2, int(total_cpus * 0.75))
        
        self.memory = f"{lima_memory_gb}GiB"
        self.cpu = lima_cpus
        
        # Platform-specific adjustments
        if self.host_platform == "Darwin":
            # macOS specific settings
            self.virtualization_backend = "hyperkit"
            self.network_mode = "bridged"
        elif self.host_platform == "Windows":
            # Windows specific settings
            self.virtualization_backend = "wsl2"
            self.network_mode = "host"
        else:
            # Linux specific settings
            self.virtualization_backend = "qemu"
            self.network_mode = "bridged"
            
        logger.info(f"Configured for {self.host_platform} with {self.memory} RAM, {self.cpu} CPUs")
    
    def start_lima(self, forwarded_ports: Dict[int, int]) -> bool:
        """
        Start Lima VM with specified port forwarding.
        All configuration is ephemeral and not persisted.
        
        Args:
            forwarded_ports: Dictionary mapping host ports to guest ports
            
        Returns:
            True if Lima was started successfully, False otherwise
        """
        try:
            # Create temporary directory for Lima files
            self.temp_dir = tempfile.mkdtemp(prefix="tvm-lima-")
            logger.info(f"Created temporary directory at {self.temp_dir}")
            
            # Generate platform-specific configuration
            config = self._generate_lima_config(forwarded_ports)
            
            # Write configuration to temporary file
            config_path = os.path.join(self.temp_dir, "lima.yaml")
            with open(config_path, 'w') as f:
                yaml.dump(config, f)
            
            # Generate unique instance name
            self.instance_name = f"tvm-{os.getpid()}"
            logger.info(f"Starting Lima instance: {self.instance_name}")
            
            # Create a Lima instance with the config file
            try:
                # First, create the instance directory
                lima_home = os.path.expanduser("~/.lima")
                instance_dir = os.path.join(lima_home, self.instance_name)
                os.makedirs(instance_dir, exist_ok=True)
                
                # Copy the config file to the instance directory
                instance_config = os.path.join(instance_dir, "lima.yaml")
                shutil.copy(config_path, instance_config)
                
                # Start Lima with the instance name
                logger.info(f"Starting Lima instance with command: limactl start {self.instance_name}")
                subprocess.run(
                    ["limactl", "start", self.instance_name],
                    check=True
                )
            except Exception as e:
                logger.error(f"Error starting Lima: {e}")
                raise
            
            # Wait for Lima to be ready
            if not self._wait_for_lima_ready():
                logger.error("Timed out waiting for Lima to be ready")
                self._cleanup()
                return False
            
            # Wait for k3s and Istio to be ready
            if not self._wait_for_k8s_ready():
                logger.error("Timed out waiting for Kubernetes to be ready")
                self._cleanup()
                return False
            
            # Deploy TVM components
            if not self._deploy_tvm_components():
                logger.error("Failed to deploy TVM components")
                self._cleanup()
                return False
            
            self.lima_running = True
            logger.info(f"Lima instance {self.instance_name} successfully started")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start Lima: {e}")
            # Clean up on failure
            self._cleanup()
            return False
    
    def _generate_lima_config(self, forwarded_ports: Dict[int, int]) -> Dict:
        """
        Generate Lima configuration based on platform.
        
        Args:
            forwarded_ports: Dictionary mapping host ports to guest ports
            
        Returns:
            Lima configuration dictionary
        """
        # Base configuration
        config = {
            "memory": self.memory,
            "cpus": self.cpu,
            # Required images field
            "images": [
                {
                    "location": "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img",
                    "arch": "x86_64"
                },
                {
                    "location": "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img",
                    "arch": "aarch64"
                }
            ],
            "mounts": [
                # Only ephemeral mounts for code execution
                {
                    "location": "~",
                    "writable": False
                }
            ],
            "containerd": {
                "system": True,
                "user": False,
            },
            "portForwards": [
                {"guestPort": guest, "hostPort": host}
                for host, guest in forwarded_ports.items()
            ],
            "provision": [
                {
                    "mode": "system",
                    "script": self._get_provision_script()
                }
            ],
        }
        
        # Platform specific overrides
        if self.host_platform == "Darwin":
            config["arch"] = "x86_64" if platform.processor() == "i386" else "aarch64"
            # Some Lima versions expect rosetta to be an object, not a boolean
            if platform.processor() == "i386" and platform.machine() == "arm64":
                # Need Rosetta
                config["rosetta"] = {}  # Empty object instead of boolean
            else:
                # Don't need Rosetta, omit the field entirely
                pass
            config["mountType"] = "virtiofs"  # Better performance on macOS
        elif self.host_platform == "Windows":
            # WSL2 specific settings
            config["wsl2"] = {
                "networkingMode": "bridged",
                "kernelCommandLine": "VSK_CPUS_PER_NUMA=8"  # Better performance on Windows
            }
        
        return config
    
    def _get_provision_script(self) -> str:
        """
        Get the provisioning script for Lima VM.
        
        Returns:
            Provisioning script as a string
        """
        return """#!/bin/bash
set -eux -o pipefail

# Detect if we're running on WSL2 or other virtualization
IS_WSL2=false
if grep -q WSL2 /proc/version; then
  IS_WSL2=true
fi

# Install k3s for lightweight Kubernetes
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.27.1+k3s1 sh -s - --disable traefik

# Configure kubectl
mkdir -p $HOME/.kube
sudo cat /etc/rancher/k3s/k3s.yaml > $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# Verify k3s is running
timeout 120s bash -c 'until kubectl get nodes | grep -q "Ready"; do sleep 2; done'

# Install Istioctl
ISTIO_VERSION=1.18.2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
export PATH=$PATH:$PWD/istio-$ISTIO_VERSION/bin

# Install minimal Istio
istioctl install --set profile=minimal -y \
  --set values.pilot.resources.requests.cpu=10m \
  --set values.pilot.resources.requests.memory=128Mi \
  --set values.pilot.resources.limits.cpu=100m \
  --set values.pilot.resources.limits.memory=256Mi

# Enable istio injection in default namespace
kubectl label namespace default istio-injection=enabled --overwrite

# Create namespace for TVM
kubectl create namespace tvm
kubectl label namespace tvm istio-injection=enabled

# Pre-pull container images to speed up later operations
images=(
  "tvm/pyrovm:latest"
  "python:3.11-slim"
  "python:3.10-slim"
  "python:3.9-slim"
  "python:3.8-slim"
  "node:20-slim"
  "node:18-slim"
  "node:16-slim"
  "ruby:3.1-slim"
  "ruby:3.0-slim"
  "ruby:2.7-slim"
  "golang:1.20-alpine"
  "golang:1.19-alpine"
  "golang:1.18-alpine"
)

for img in "${images[@]}"; do
  nohup docker pull $img &
done

# Configure Istio health check endpoint
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: health-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - istio-system/health-gateway
  http:
  - match:
    - uri:
        exact: /healthz
    route:
    - destination:
        host: istiod
        port:
          number: 15014
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: health-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF

echo 'TVM environment ready'
"""
    
    def _wait_for_lima_ready(self) -> bool:
        """
        Wait for Lima VM to be ready.
        
        Returns:
            True if Lima is ready, False otherwise
        """
        max_attempts = 30
        for i in range(max_attempts):
            try:
                result = subprocess.run(
                    ["limactl", "shell", self.instance_name, "echo", "ready"],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if "ready" in result.stdout:
                    return True
            except:
                pass
            logger.info(f"Waiting for Lima VM to be ready... ({i+1}/{max_attempts})")
            time.sleep(2)
        return False
    
    def _wait_for_k8s_ready(self) -> bool:
        """
        Wait for Kubernetes to be ready in Lima VM.
        
        Returns:
            True if Kubernetes is ready, False otherwise
        """
        max_attempts = 60  # 2 minutes timeout
        for i in range(max_attempts):
            try:
                # Check if nodes are ready
                result = subprocess.run(
                    ["limactl", "shell", self.instance_name, "kubectl", "get", "nodes"],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if "Ready" in result.stdout:
                    # Check if Istio is running
                    result = subprocess.run(
                        ["limactl", "shell", self.instance_name, 
                         "kubectl", "get", "pods", "-n", "istio-system"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    if "Running" in result.stdout and "istiod" in result.stdout:
                        logger.info("Kubernetes and Istio are ready")
                        return True
            except Exception as e:
                logger.warning(f"Error checking K8s status: {e}")
                
            logger.info(f"Waiting for Kubernetes and Istio to be ready... ({i+1}/{max_attempts})")
            time.sleep(2)
        return False
    
    def _deploy_tvm_components(self) -> bool:
        """
        Deploy TVM components to Kubernetes.
        
        Returns:
            True if deployment was successful, False otherwise
        """
        try:
            # Create TVM deployment manifest
            manifest = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pyrovm
  namespace: tvm
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pyrovm
  template:
    metadata:
      labels:
        app: pyrovm
    spec:
      containers:
      - name: pyrovm
        image: tvm/pyrovm:latest
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: STATELESS_MODE
          value: "true"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: pyrovm
  namespace: tvm
spec:
  selector:
    app: pyrovm
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tvm-gateway
  namespace: tvm
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tvm-vs
  namespace: tvm
spec:
  hosts:
  - "*"
  gateways:
  - tvm-gateway
  http:
  - match:
    - uri:
        prefix: "/api/execute"
    route:
    - destination:
        host: pyrovm
        port:
          number: 80
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "gateway-error,connect-failure,refused-stream,unavailable,cancelled,resource-exhausted"
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: pyrovm
  namespace: tvm
spec:
  host: pyrovm
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
"""
            # Write manifest to temporary file
            manifest_path = os.path.join(self.temp_dir, "tvm-manifest.yaml")
            with open(manifest_path, 'w') as f:
                f.write(manifest)
            
            # Apply manifest
            logger.info("Deploying TVM components to Kubernetes")
            subprocess.run(
                ["limactl", "shell", self.instance_name, "kubectl", "apply", "-f", "/tmp/tvm-manifest.yaml"],
                check=True,
                input=manifest,
                text=True
            )
            
            # Wait for deployment to be ready
            max_attempts = 30
            for i in range(max_attempts):
                try:
                    result = subprocess.run(
                        ["limactl", "shell", self.instance_name,
                         "kubectl", "get", "deployment", "pyrovm", "-n", "tvm", "-o", "json"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    
                    if result.returncode == 0:
                        deployment_info = json.loads(result.stdout)
                        status = deployment_info.get("status", {})
                        ready_replicas = status.get("readyReplicas", 0)
                        
                        if ready_replicas > 0:
                            logger.info(f"TVM deployment ready with {ready_replicas} replicas")
                            return True
                except Exception as e:
                    logger.warning(f"Error checking deployment status: {e}")
                
                logger.info(f"Waiting for TVM deployment to be ready... ({i+1}/{max_attempts})")
                time.sleep(2)
                
            logger.error("Timed out waiting for TVM deployment")
            return False
            
        except Exception as e:
            logger.error(f"Failed to deploy TVM components: {e}")
            return False
    
    def stop_lima(self) -> bool:
        """
        Stop Lima VM immediately without saving state.
        
        Returns:
            True if Lima was stopped successfully, False otherwise
        """
        if not self.lima_running:
            return True
            
        try:
            logger.info(f"Stopping Lima instance {self.instance_name}")
            
            # Try different command formats for stopping Lima
            try:
                # First try with --force flag
                subprocess.run(
                    ["limactl", "stop", "--force", self.instance_name],
                    check=True
                )
            except subprocess.CalledProcessError:
                # If that fails, try without --force flag
                logger.info("First stop attempt failed, trying without --force flag")
                try:
                    subprocess.run(
                        ["limactl", "stop", self.instance_name],
                        check=True
                    )
                except subprocess.CalledProcessError:
                    logger.warning("Both stop attempts failed, continuing with deletion")
            
            # Try different command formats for deleting Lima
            try:
                # First try with --force flag
                subprocess.run(
                    ["limactl", "delete", "--force", self.instance_name],
                    check=True
                )
            except subprocess.CalledProcessError:
                # If that fails, try without --force flag
                logger.info("First delete attempt failed, trying without --force flag")
                try:
                    subprocess.run(
                        ["limactl", "delete", self.instance_name],
                        check=True
                    )
                except subprocess.CalledProcessError:
                    logger.warning("Both delete attempts failed")
            
            self.lima_running = False
            self._cleanup()
            logger.info(f"Lima instance {self.instance_name} stopped and deleted")
            return True
        except Exception as e:
            logger.error(f"Failed to stop Lima: {e}")
            # Try harder to clean up
            try:
                subprocess.run(
                    ["limactl", "delete", self.instance_name],
                    check=False
                )
            except:
                pass
            self._cleanup()
            return False
    
    def _cleanup(self):
        """Clean up all temporary resources."""
        if self.temp_dir and os.path.exists(self.temp_dir):
            try:
                shutil.rmtree(self.temp_dir)
                self.temp_dir = None
                logger.info("Cleaned up temporary resources")
            except Exception as e:
                logger.error(f"Failed to clean up temporary directory: {e}")