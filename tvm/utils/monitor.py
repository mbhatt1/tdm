"""
Monitoring utility for the TVM system.
"""

import psutil
import time
import json
import os
import platform
import subprocess
import logging
from typing import Dict, List, Tuple, Optional

from tvm.utils.logger import setup_logger

# Configure logging
logger = setup_logger("tvm-monitor")

class StatelessMonitor:
    """Monitoring system with no persistence."""
    
    def __init__(self, interval: int = 5):
        """
        Initialize the monitoring system.
        
        Args:
            interval: The monitoring interval in seconds
        """
        self.interval = interval
        self.start_time = time.time()
        self.prev_network = psutil.net_io_counters()
        self.prev_disk = psutil.disk_io_counters()
        self.prev_time = time.time()
    
    def get_system_metrics(self) -> Dict:
        """
        Get current system metrics.
        
        Returns:
            A dictionary of system metrics
        """
        # Base metrics
        current_time = time.time()
        metrics = {
            "timestamp": current_time,
            "uptime": current_time - self.start_time,
            "cpu": {
                "percent": psutil.cpu_percent(interval=0.1),
                "count": psutil.cpu_count(),
                "load": os.getloadavg() if platform.system() != "Windows" else [0, 0, 0]
            },
            "memory": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
                "percent": psutil.virtual_memory().percent
            },
            "disk": {
                "total": psutil.disk_usage('/').total,
                "free": psutil.disk_usage('/').free,
                "percent": psutil.disk_usage('/').percent
            }
        }
        
        # Calculate network rate
        current_network = psutil.net_io_counters()
        time_delta = current_time - self.prev_time
        
        if time_delta > 0:
            metrics["network"] = {
                "bytes_sent": current_network.bytes_sent,
                "bytes_recv": current_network.bytes_recv,
                "send_rate": (current_network.bytes_sent - self.prev_network.bytes_sent) / time_delta,
                "recv_rate": (current_network.bytes_recv - self.prev_network.bytes_recv) / time_delta
            }
        
        # Calculate disk I/O rate
        current_disk = psutil.disk_io_counters()
        
        if time_delta > 0:
            metrics["disk_io"] = {
                "read_bytes": current_disk.read_bytes,
                "write_bytes": current_disk.write_bytes,
                "read_rate": (current_disk.read_bytes - self.prev_disk.read_bytes) / time_delta,
                "write_rate": (current_disk.write_bytes - self.prev_disk.write_bytes) / time_delta
            }
        
        # Update previous values
        self.prev_network = current_network
        self.prev_disk = current_disk
        self.prev_time = current_time
        
        return metrics
    
    def get_lima_metrics(self) -> Dict:
        """
        Get metrics for Lima VM.
        
        Returns:
            A dictionary of Lima metrics
        """
        lima_metrics = {
            "instances": [],
            "running_count": 0
        }
        
        try:
            # Get Lima instances without using persistent state
            result = subprocess.run(
                ["limactl", "list", "--format", "json"],
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode == 0:
                instances = json.loads(result.stdout)
                
                for instance in instances:
                    if instance.get("name", "").startswith("tvm-"):
                        lima_metrics["instances"].append({
                            "name": instance.get("name"),
                            "status": instance.get("status"),
                            "arch": instance.get("arch"),
                            "cpus": instance.get("cpus"),
                            "memory": instance.get("memory")
                        })
                        
                        if instance.get("status") == "Running":
                            lima_metrics["running_count"] += 1
        except Exception as e:
            logger.warning(f"Failed to get Lima metrics: {e}")
        
        return lima_metrics
    
    def get_kubernetes_metrics(self) -> Dict:
        """
        Get metrics for Kubernetes inside Lima.
        
        Returns:
            A dictionary of Kubernetes metrics
        """
        k8s_metrics = {
            "nodes": [],
            "pods": {
                "total": 0,
                "running": 0,
                "pending": 0,
                "failed": 0
            },
            "deployment_status": {},
            "istio_status": {}
        }
        
        try:
            # Find a running Lima instance
            result = subprocess.run(
                ["limactl", "list", "--format", "json"],
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode == 0:
                instances = json.loads(result.stdout)
                lima_instance = None
                
                for instance in instances:
                    if instance.get("name", "").startswith("tvm-") and instance.get("status") == "Running":
                        lima_instance = instance.get("name")
                        break
                
                if lima_instance:
                    # Get nodes
                    result = subprocess.run(
                        ["limactl", "shell", lima_instance, "kubectl", "get", "nodes", "-o", "json"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    
                    if result.returncode == 0:
                        nodes_data = json.loads(result.stdout)
                        for node in nodes_data.get("items", []):
                            node_status = {
                                "name": node.get("metadata", {}).get("name"),
                                "ready": False,
                                "cpu": "unknown",
                                "memory": "unknown"
                            }
                            
                            # Check node conditions
                            for condition in node.get("status", {}).get("conditions", []):
                                if condition.get("type") == "Ready" and condition.get("status") == "True":
                                    node_status["ready"] = True
                            
                            # Get capacity
                            capacity = node.get("status", {}).get("capacity", {})
                            node_status["cpu"] = capacity.get("cpu", "unknown")
                            node_status["memory"] = capacity.get("memory", "unknown")
                            
                            k8s_metrics["nodes"].append(node_status)
                    
                    # Get pods
                    result = subprocess.run(
                        ["limactl", "shell", lima_instance, "kubectl", "get", "pods", "--all-namespaces", "-o", "json"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    
                    if result.returncode == 0:
                        pods_data = json.loads(result.stdout)
                        
                        for pod in pods_data.get("items", []):
                            phase = pod.get("status", {}).get("phase")
                            
                            k8s_metrics["pods"]["total"] += 1
                            
                            if phase == "Running":
                                k8s_metrics["pods"]["running"] += 1
                            elif phase == "Pending":
                                k8s_metrics["pods"]["pending"] += 1
                            elif phase == "Failed":
                                k8s_metrics["pods"]["failed"] += 1
                    
                    # Get TVM deployment status
                    result = subprocess.run(
                        ["limactl", "shell", lima_instance, "kubectl", "get", "deployment", "pyrovm", "-n", "tvm", "-o", "json"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    
                    if result.returncode == 0:
                        deployment_data = json.loads(result.stdout)
                        
                        k8s_metrics["deployment_status"] = {
                            "name": "pyrovm",
                            "desired": deployment_data.get("spec", {}).get("replicas", 0),
                            "current": deployment_data.get("status", {}).get("replicas", 0),
                            "available": deployment_data.get("status", {}).get("availableReplicas", 0),
                            "ready": deployment_data.get("status", {}).get("readyReplicas", 0)
                        }
                    
                    # Get Istio status
                    result = subprocess.run(
                        ["limactl", "shell", lima_instance, "kubectl", "get", "pods", "-n", "istio-system", "-o", "json"],
                        capture_output=True,
                        text=True,
                        check=False
                    )
                    
                    if result.returncode == 0:
                        istio_pods = json.loads(result.stdout)
                        istio_status = {
                            "istiod": "NotFound",
                            "ingress": "NotFound",
                            "egress": "NotFound"
                        }
                        
                        for pod in istio_pods.get("items", []):
                            name = pod.get("metadata", {}).get("name", "")
                            phase = pod.get("status", {}).get("phase")
                            
                            if "istiod" in name:
                                istio_status["istiod"] = phase
                            elif "ingressgateway" in name:
                                istio_status["ingress"] = phase
                            elif "egressgateway" in name:
                                istio_status["egress"] = phase
                        
                        k8s_metrics["istio_status"] = istio_status
        except Exception as e:
            logger.warning(f"Failed to get Kubernetes metrics: {e}")
        
        return k8s_metrics
    
    def monitor_system(self):
        """Monitor system metrics at specified interval."""
        logger.info("Starting stateless monitoring")
        
        try:
            while True:
                # Get all metrics
                system_metrics = self.get_system_metrics()
                lima_metrics = self.get_lima_metrics()
                k8s_metrics = self.get_kubernetes_metrics()
                
                # Combine metrics
                all_metrics = {
                    "system": system_metrics,
                    "lima": lima_metrics,
                    "kubernetes": k8s_metrics
                }
                
                # Print metrics to console only - no persistence
                print(json.dumps(all_metrics, indent=2))
                
                # Sleep until next check
                time.sleep(self.interval)
        except KeyboardInterrupt:
            logger.info("Monitoring stopped")
        except Exception as e:
            logger.error(f"Error in monitoring: {e}")

def start_monitoring(interval: int = 5):
    """
    Start monitoring the TVM system.
    
    Args:
        interval: The monitoring interval in seconds
    """
    monitor = StatelessMonitor(interval=interval)
    monitor.monitor_system()

if __name__ == "__main__":
    start_monitoring()