#!/usr/bin/env python3
"""
TVM Command Line Interface

Provides command-line tools for managing the TVM system.
"""

import typer
from rich.console import Console
from rich.table import Table
import uvicorn
import os
import sys
import signal
import subprocess
import time
import psutil
import yaml
from typing import Optional

from tvm.utils.logger import setup_logger

# Initialize logger
logger = setup_logger("tvm-cli")

# Initialize Typer app
app = typer.Typer(help="Trashfire Vending Machine (TVM) - Stateless Code Execution System")
console = Console()

@app.command()
def start(
    host: str = typer.Option("0.0.0.0", help="Host to bind the API server to"),
    port: int = typer.Option(8080, help="Port to bind the API server to"),
    debug: bool = typer.Option(False, help="Enable debug mode"),
):
    """Start the TVM API server."""
    console.print("[bold green]Starting TVM API server...[/bold green]")
    
    # Start server
    try:
        uvicorn.run("tvm.api:app", host=host, port=port, reload=debug)
    except KeyboardInterrupt:
        console.print("[bold yellow]Stopping TVM API server...[/bold yellow]")
    except Exception as e:
        console.print(f"[bold red]Error starting TVM API server: {e}[/bold red]")
        sys.exit(1)

@app.command()
def stop():
    """Stop all TVM components."""
    console.print("[bold yellow]Stopping TVM components...[/bold yellow]")
    
    # Find and stop Lima instances
    try:
        result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
        if result.returncode == 0:
            instances = yaml.safe_load(result.stdout) or []
            if instances:
                for instance in instances:
                    if instance.get("name", "").startswith("tvm-"):
                        console.print(f"Stopping Lima instance: {instance['name']}")
                        subprocess.run(["limactl", "stop", "--force", instance["name"]])
                        subprocess.run(["limactl", "delete", "--force", instance["name"]])
    except Exception as e:
        console.print(f"[bold red]Error stopping Lima instances: {e}[/bold red]")
    
    # Find and stop TVM processes
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = ' '.join(proc.info['cmdline'] or [])
            if 'tvm.api:app' in cmdline:
                console.print(f"Stopping TVM process: {proc.info['pid']}")
                os.kill(proc.info['pid'], signal.SIGTERM)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    console.print("[bold green]TVM components stopped.[/bold green]")

@app.command()
def status():
    """Check status of TVM components."""
    console.print("[bold blue]TVM System Status[/bold blue]")
    
    table = Table(show_header=True)
    table.add_column("Component")
    table.add_column("Status")
    table.add_column("Details")
    
    # Check API server
    api_running = False
    api_pid = None
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = ' '.join(proc.info['cmdline'] or [])
            if 'tvm.api:app' in cmdline:
                api_running = True
                api_pid = proc.info['pid']
                break
        except:
            pass
    
    table.add_row(
        "API Server", 
        "[green]Running[/green]" if api_running else "[red]Stopped[/red]",
        f"PID: {api_pid}" if api_pid else ""
    )
    
    # Check Lima
    lima_running = False
    lima_name = None
    try:
        result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
        if result.returncode == 0:
            instances = yaml.safe_load(result.stdout) or []
            if instances:
                for instance in instances:
                    if instance.get("name", "").startswith("tvm-") and instance.get("status") == "Running":
                        lima_running = True
                        lima_name = instance.get("name")
                        break
    except:
        pass
    
    table.add_row(
        "Lima VM", 
        "[green]Running[/green]" if lima_running else "[red]Stopped[/red]",
        f"Instance: {lima_name}" if lima_name else ""
    )
    
    # Check Kubernetes (if Lima is running)
    k8s_running = False
    k8s_version = None
    if lima_running and lima_name:
        try:
            result = subprocess.run(
                ["limactl", "shell", lima_name, "kubectl", "version", "--short"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0 and "Server Version" in result.stdout:
                k8s_running = True
                for line in result.stdout.splitlines():
                    if "Server Version" in line:
                        k8s_version = line.split("Server Version: ")[-1].strip()
                        break
        except:
            pass
    
    table.add_row(
        "Kubernetes", 
        "[green]Running[/green]" if k8s_running else "[red]Stopped[/red]",
        f"Version: {k8s_version}" if k8s_version else ""
    )
    
    # Check Istio (if K8s is running)
    istio_running = False
    istio_version = None
    if k8s_running and lima_name:
        try:
            result = subprocess.run(
                ["limactl", "shell", lima_name, "kubectl", "get", "pods", "-n", "istio-system"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0 and "istiod" in result.stdout and "Running" in result.stdout:
                istio_running = True
                # Try to get Istio version
                version_result = subprocess.run(
                    ["limactl", "shell", lima_name, "kubectl", "get", "deployment", "-n", "istio-system", "istiod", "-o", "jsonpath='{.spec.template.spec.containers[0].image}'"],
                    capture_output=True, text=True, check=False
                )
                if version_result.returncode == 0:
                    image = version_result.stdout.strip("'")
                    if ":" in image:
                        istio_version = image.split(":")[-1]
        except:
            pass
    
    table.add_row(
        "Istio", 
        "[green]Running[/green]" if istio_running else "[red]Stopped[/red]",
        f"Version: {istio_version}" if istio_version else ""
    )
    
    # Check TVM deployment (if Istio is running)
    tvm_running = False
    tvm_pods = None
    if istio_running and lima_name:
        try:
            result = subprocess.run(
                ["limactl", "shell", lima_name, "kubectl", "get", "pods", "-n", "tvm", "-l", "app=pyrovm"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0 and "Running" in result.stdout:
                tvm_running = True
                # Count running pods
                running_pods = 0
                for line in result.stdout.splitlines()[1:]:  # Skip header
                    if "Running" in line:
                        running_pods += 1
                tvm_pods = f"{running_pods} pods"
        except:
            pass
    
    table.add_row(
        "TVM Deployment", 
        "[green]Running[/green]" if tvm_running else "[red]Stopped[/red]",
        tvm_pods if tvm_pods else ""
    )
    
    console.print(table)

@app.command()
def logs(
    follow: bool = typer.Option(False, "--follow", "-f", help="Follow logs"),
    lines: int = typer.Option(100, "--lines", "-n", help="Number of lines to show"),
    component: str = typer.Option(None, "--component", "-c", help="Component to show logs for (api, lima, k8s, istio, tvm)"),
):
    """View TVM logs."""
    if component == "api":
        # Show API server logs
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if 'tvm.api:app' in cmdline:
                    console.print(f"[bold blue]API server logs (PID: {proc.info['pid']})[/bold blue]")
                    # On most systems, we can't directly access process stdout/stderr
                    # So we suggest using system tools
                    console.print("[yellow]Use system tools to view process logs:[/yellow]")
                    console.print(f"  sudo lsof -p {proc.info['pid']} | grep log")
                    console.print(f"  journalctl _PID={proc.info['pid']}")
                    return
            except:
                pass
        console.print("[bold red]API server not running[/bold red]")
    elif component == "lima" or component is None:
        # Show Lima logs
        lima_name = None
        try:
            result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
            if result.returncode == 0:
                instances = yaml.safe_load(result.stdout) or []
                if instances:
                    for instance in instances:
                        if instance.get("name", "").startswith("tvm-"):
                            lima_name = instance.get("name")
                            break
        except:
            pass
        
        if lima_name:
            console.print(f"[bold blue]Lima logs for instance {lima_name}[/bold blue]")
            cmd = ["limactl", "shell", lima_name, "journalctl", f"-n", str(lines)]
            if follow:
                cmd.append("-f")
            subprocess.run(cmd)
        else:
            console.print("[bold red]No TVM Lima instance found[/bold red]")
    elif component in ["k8s", "kubernetes"]:
        # Show Kubernetes logs
        lima_name = None
        try:
            result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
            if result.returncode == 0:
                instances = yaml.safe_load(result.stdout) or []
                if instances:
                    for instance in instances:
                        if instance.get("name", "").startswith("tvm-") and instance.get("status") == "Running":
                            lima_name = instance.get("name")
                            break
        except:
            pass
        
        if lima_name:
            console.print(f"[bold blue]Kubernetes logs[/bold blue]")
            cmd = ["limactl", "shell", lima_name, "journalctl", "-u", "k3s", f"-n", str(lines)]
            if follow:
                cmd.append("-f")
            subprocess.run(cmd)
        else:
            console.print("[bold red]No running TVM Lima instance found[/bold red]")
    elif component == "istio":
        # Show Istio logs
        lima_name = None
        try:
            result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
            if result.returncode == 0:
                instances = yaml.safe_load(result.stdout) or []
                if instances:
                    for instance in instances:
                        if instance.get("name", "").startswith("tvm-") and instance.get("status") == "Running":
                            lima_name = instance.get("name")
                            break
        except:
            pass
        
        if lima_name:
            console.print(f"[bold blue]Istio logs[/bold blue]")
            cmd = ["limactl", "shell", lima_name, "kubectl", "logs", "-n", "istio-system", "-l", "app=istiod", f"--tail={lines}"]
            if follow:
                cmd.append("-f")
            subprocess.run(cmd)
        else:
            console.print("[bold red]No running TVM Lima instance found[/bold red]")
    elif component == "tvm":
        # Show TVM deployment logs
        lima_name = None
        try:
            result = subprocess.run(["limactl", "list", "--format", "yaml"], capture_output=True, text=True)
            if result.returncode == 0:
                instances = yaml.safe_load(result.stdout) or []
                if instances:
                    for instance in instances:
                        if instance.get("name", "").startswith("tvm-") and instance.get("status") == "Running":
                            lima_name = instance.get("name")
                            break
        except:
            pass
        
        if lima_name:
            console.print(f"[bold blue]TVM deployment logs[/bold blue]")
            cmd = ["limactl", "shell", lima_name, "kubectl", "logs", "-n", "tvm", "-l", "app=pyrovm", f"--tail={lines}"]
            if follow:
                cmd.append("-f")
            subprocess.run(cmd)
        else:
            console.print("[bold red]No running TVM Lima instance found[/bold red]")
    else:
        console.print(f"[bold red]Unknown component: {component}[/bold red]")
        console.print("Available components: api, lima, k8s, istio, tvm")

@app.command()
def setup():
    """Set up the TVM system."""
    from tvm.utils.setup import setup_system
    setup_system()

if __name__ == "__main__":
    app()