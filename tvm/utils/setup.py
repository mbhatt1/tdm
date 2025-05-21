"""
Setup utility for the TVM system.
"""

import subprocess
import sys
import os
import time
import platform
import logging
import shutil
from typing import Dict, List, Tuple, Optional

from tvm.utils.logger import setup_logger

# Configure logging
logger = setup_logger("tvm-setup")

def check_prerequisites() -> bool:
    """
    Check if required software is installed.
    
    Returns:
        True if all prerequisites are installed, False otherwise
    """
    # Platform-specific prerequisites
    if platform.system() == "Darwin":  # macOS
        prereqs = ["lima", "python3", "pip3", "brew"]
        install_cmd = "brew install {}"
    elif platform.system() == "Linux":
        prereqs = ["lima", "python3", "pip3", "docker"]
        install_cmd = "sudo apt-get install -y {}"
    elif platform.system() == "Windows":
        prereqs = ["wsl", "python", "pip"]
        install_cmd = "Please install {} manually"
    else:
        logger.error(f"Unsupported platform: {platform.system()}")
        return False
    
    missing = []
    
    for cmd in prereqs:
        try:
            subprocess.run(["which", cmd], capture_output=True, check=True)
        except:
            missing.append(cmd)
    
    if missing:
        logger.warning(f"Missing prerequisites: {', '.join(missing)}")
        logger.info("Install missing prerequisites with:")
        for cmd in missing:
            logger.info(install_cmd.format(cmd))
        return False
    
    return True

def setup_system() -> bool:
    """
    Set up the complete TVM system.
    
    Returns:
        True if setup was successful, False otherwise
    """
    if not check_prerequisites():
        logger.error("Prerequisites check failed. Please install required software.")
        return False
    
    logger.info("Starting TVM system setup")
    
    # Install Python dependencies
    logger.info("Installing Python dependencies")
    try:
        subprocess.run([
            sys.executable, "-m", "pip", "install", 
            "fastapi", "uvicorn", "httpx", "pyyaml", "pydantic", 
            "aiofiles", "psutil", "typer", "rich"
        ], check=True)
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to install Python dependencies: {e}")
        return False
    
    # Create directory for TVM
    home_dir = os.path.expanduser("~")
    tvm_dir = os.path.join(home_dir, ".tvm")
    
    # Don't use the directory for persistence, just for scripts
    os.makedirs(tvm_dir, exist_ok=True)
    logger.info(f"Created TVM directory at {tvm_dir}")
    
    # Set up platform-specific configurations
    if platform.system() == "Darwin":  # macOS
        setup_macos()
    elif platform.system() == "Linux":
        setup_linux()
    elif platform.system() == "Windows":
        setup_windows()
    
    # Create command-line entry point
    create_cli_entrypoint(tvm_dir)
    
    logger.info("TVM system setup complete!")
    logger.info("Run 'tvm start' to start the API server.")
    
    return True

def setup_macos() -> None:
    """macOS-specific setup."""
    logger.info("Performing macOS-specific setup")
    
    # Check and increase file descriptor limits
    try:
        result = subprocess.run(["launchctl", "limit", "maxfiles"], capture_output=True, text=True, check=True)
        current_limits = result.stdout.strip().split()
        if len(current_limits) >= 3:
            soft_limit = int(current_limits[1])
            if soft_limit < 10240:
                # Increase file descriptor limits
                logger.info("Increasing file descriptor limits")
                subprocess.run(["sudo", "launchctl", "limit", "maxfiles", "10240", "unlimited"], check=True)
    except Exception as e:
        logger.warning(f"Failed to check/update file descriptor limits: {e}")
    
    # Check Lima version and availability
    try:
        # Just check if Lima is available
        result = subprocess.run(["limactl", "version"], capture_output=True, text=True)
        if result.returncode == 0:
            logger.info(f"Lima is available: {result.stdout.strip()}")
        else:
            logger.warning("Lima version check failed, but continuing anyway")
    except Exception as e:
        logger.warning(f"Failed to check Lima version: {e}")

def setup_linux() -> None:
    """Linux-specific setup."""
    logger.info("Performing Linux-specific setup")
    
    # Check KVM access
    if os.path.exists("/dev/kvm"):
        try:
            # Check if current user has access to KVM
            access = os.access("/dev/kvm", os.R_OK | os.W_OK)
            if not access:
                logger.warning("Current user doesn't have access to /dev/kvm")
                logger.info("To fix: sudo usermod -aG kvm $USER && newgrp kvm")
        except:
            pass
    else:
        logger.warning("KVM device not found. Virtualization may not be available.")
    
    # Check and increase file descriptor limits
    try:
        subprocess.run(["sudo", "sysctl", "-w", "fs.file-max=100000"], check=True)
        
        # Add to sysctl.conf if not already there
        sysctl_file = "/etc/sysctl.conf"
        if os.path.exists(sysctl_file):
            with open(sysctl_file, 'r') as f:
                content = f.read()
                if "fs.file-max=100000" not in content:
                    logger.info("Adding file descriptor limits to sysctl.conf")
                    with open(sysctl_file, 'a') as f:
                        f.write("\n# TVM: Increase file descriptor limits\n")
                        f.write("fs.file-max=100000\n")
    except Exception as e:
        logger.warning(f"Failed to update sysctl configuration: {e}")

def setup_windows() -> None:
    """Windows-specific setup."""
    logger.info("Performing Windows-specific setup")
    
    # Check WSL2
    try:
        result = subprocess.run(["wsl", "--status"], capture_output=True, text=True, check=True)
        if "2" not in result.stdout:
            logger.warning("WSL2 may not be properly configured")
            logger.info("Run: wsl --set-default-version 2")
    except:
        logger.warning("Failed to check WSL status")
    
    # Check Ubuntu distribution
    try:
        result = subprocess.run(["wsl", "-l", "-v"], capture_output=True, text=True, check=True)
        if "Ubuntu" not in result.stdout:
            logger.warning("Ubuntu distribution not found in WSL")
            logger.info("Install Ubuntu with: wsl --install -d Ubuntu")
    except:
        logger.warning("Failed to check WSL distributions")

def create_cli_entrypoint(tvm_dir: str) -> None:
    """
    Create command-line entry point.
    
    Args:
        tvm_dir: The TVM directory path
    """
    logger.info("Creating command-line entry point")
    
    # Create CLI script
    cli_script = os.path.join(tvm_dir, "tvm.py")
    with open(cli_script, 'w') as f:
        f.write("""#!/usr/bin/env python3
import sys
import os

# Add the parent directory to sys.path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from tvm.cli import app

if __name__ == "__main__":
    app()
""")
    
    # Make script executable
    os.chmod(cli_script, 0o755)
    
    # Create symlink to user's bin directory if possible
    user_bin = os.path.expanduser("~/bin")
    if not os.path.exists(user_bin):
        os.makedirs(user_bin, exist_ok=True)
    
    try:
        symlink_path = os.path.join(user_bin, "tvm")
        if os.path.exists(symlink_path):
            os.unlink(symlink_path)
        os.symlink(cli_script, symlink_path)
        logger.info(f"Created symlink at {symlink_path}")
        
        # Check if ~/bin is in PATH
        if user_bin not in os.environ.get("PATH", "").split(os.pathsep):
            logger.warning(f"{user_bin} is not in PATH")
            logger.info(f"Add to PATH with: export PATH=\"{user_bin}:$PATH\"")
    except Exception as e:
        logger.warning(f"Failed to create symlink: {e}")
        logger.info(f"Run TVM with: python3 {cli_script}")

if __name__ == "__main__":
    setup_system()