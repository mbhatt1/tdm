# TVM Installation Guide

This guide provides instructions for installing the Trashfire Vending Machine (TVM) system on different platforms.

## Prerequisites

Before installing TVM, ensure you have the following prerequisites installed:

### Common Requirements

- Python 3.8 or later
- pip (Python package manager)
- Git

### Platform-Specific Requirements

#### macOS

- macOS 12 (Monterey) or later
- Homebrew package manager
- Lima virtualization tool (v0.14.0 or later)
- At least 8GB of RAM
- At least 20GB of free disk space

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Lima
brew install lima
```

#### Linux

- Ubuntu 20.04+, Fedora 36+, or other modern Linux distribution
- KVM virtualization support
- Lima virtualization tool (v0.14.0 or later)
- At least 6GB of RAM
- At least 20GB of free disk space

```bash
# Check KVM support
ls -l /dev/kvm

# If KVM is not available, you may need to enable virtualization in BIOS/UEFI

# Install Lima (Ubuntu/Debian)
curl -LO https://github.com/lima-vm/lima/releases/download/v0.17.0/lima_0.17.0_amd64.deb
sudo dpkg -i lima_0.17.0_amd64.deb

# Install Lima (Fedora/RHEL)
curl -LO https://github.com/lima-vm/lima/releases/download/v0.17.0/lima-0.17.0-1.x86_64.rpm
sudo rpm -i lima-0.17.0-1.x86_64.rpm
```

#### Windows

- Windows 10/11
- WSL2 enabled
- Ubuntu 20.04 or later installed in WSL2
- At least 8GB of RAM
- At least 20GB of free disk space

```powershell
# Enable WSL2 (run in PowerShell as Administrator)
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Restart your computer

# Set WSL2 as default
wsl --set-default-version 2

# Install Ubuntu from Microsoft Store
# Then, follow the Linux installation instructions within WSL2
```

## Installation Methods

### Method 1: Install from PyPI (Recommended)

The simplest way to install TVM is using pip:

```bash
# Install TVM
pip install tvm-system

# Verify installation
tvm --version
```

### Method 2: Install from Source

For the latest development version or to contribute to TVM, install from source:

```bash
# Clone the repository
git clone https://github.com/example/tvm.git
cd tvm

# Install in development mode
pip install -e .

# Verify installation
tvm --version
```

### Method 3: Using Docker

TVM can also be run using Docker:

```bash
# Pull the Docker image
docker pull ghcr.io/example/tvm/pyrovm:latest

# Run TVM in Docker
docker run -d --privileged -p 8080:8080 ghcr.io/example/tvm/pyrovm:latest
```

## Post-Installation Setup

After installing TVM, you need to set up the system:

```bash
# Run the setup command
tvm setup

# This will:
# 1. Check prerequisites
# 2. Install Python dependencies
# 3. Configure platform-specific settings
# 4. Create command-line entry point
```

## Verifying Installation

To verify that TVM is installed correctly:

```bash
# Check TVM version
tvm --version

# Check TVM status
tvm status

# Start TVM
tvm start

# Test with a simple Python code execution
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "print(\"Hello, World!\")",
    "language": "python",
    "language_version": "3.11",
    "timeout_ms": 5000,
    "memory_mb": 128,
    "cpu_count": 1
  }'

# Stop TVM
tvm stop
```

## Troubleshooting

### Common Issues

#### Lima fails to start

If Lima fails to start, check the logs:

```bash
limactl shell <instance-name> sudo journalctl -u k3s
```

Ensure you have enough disk space and memory available.

#### Permission issues with Firecracker

If you encounter permission issues with Firecracker:

```bash
# Check if you have access to /dev/kvm
ls -l /dev/kvm

# Add your user to the kvm group
sudo usermod -aG kvm $USER
newgrp kvm
```

#### Network connectivity issues

If you encounter network connectivity issues:

```bash
# Check if ports are correctly forwarded
limactl shell <instance-name> netstat -tulpn

# Check Istio status
limactl shell <instance-name> kubectl get pods -n istio-system
```

### Getting Help

If you encounter issues not covered in this guide:

- Check the [GitHub Issues](https://github.com/example/tvm/issues)
- Join the [Discord community](https://discord.gg/example-tvm)
- Contact support at support@example.com