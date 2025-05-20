# Trashfire Dispenser Machine

A Kubernetes-native solution for managing lightweight virtual machines using Firecracker. It enables users to create, manage, and execute code within isolated microVMs, with support for Model Context Protocol (MCP) sessions.

## Architecture

The system consists of several components:

- **lime-ctrl**: A Kubernetes controller for managing MicroVM resources
- **kvm-device-plugin**: A Kubernetes device plugin for exposing KVM devices to pods
- **Flintlock**: A service for creating and managing Firecracker microVMs
- **MCP (Model Context Protocol)**: A protocol for communication between models and microVMs

## Prerequisites

- Kubernetes cluster
- KVM-enabled nodes
- Containerd runtime
- Lima (for macOS development)

## Getting Started

### ⚠️ IMPORTANT: Running on macOS

This project requires Linux with KVM and Kubernetes. On macOS, all commands must be run **inside a Lima VM**, not directly on macOS.

### ⚠️ IMPORTANT: Firecracker Requirements

Firecracker requires KVM to run properly. When running in a Lima VM, nested virtualization might not be available, which means Firecracker might not work as expected. The deployment is configured to handle this gracefully for demonstration purposes, but for a full production deployment, you would need to run this on a Kubernetes cluster with KVM support.

### Quick Start with Lima Wrapper (Recommended)

The easiest way to get started on macOS is to use the Lima wrapper script, which handles all the setup, building, and deployment in one step:

```bash
# Make the wrapper script executable
chmod +x scripts/lima-wrapper.sh

# Run the wrapper script
./scripts/lima-wrapper.sh
```

This script will:
1. Create a Lima VM with Kubernetes if it doesn't exist
2. Copy all project files to the VM (excluding macOS metadata files)
3. Install Go (with architecture detection) and other dependencies
4. Fix the go.mod file to ensure compatibility
5. Create simple implementations for the controllers
6. Build the binaries and Docker images
7. Deploy the components to Kubernetes
8. Run tests to verify the deployment

After the script completes, you can access the Lima VM with:

```bash
limactl shell vvm-dev
cd /tmp/trashfire-dispenser-machine
```

### Manual Setup with Lima

If you prefer to set up the environment manually:

```bash
# Make the setup script executable
chmod +x scripts/setup-lima.sh

# Run the setup script
./scripts/setup-lima.sh
```

This script will:
1. Create a Lima VM with Kubernetes
2. Copy the project files to the VM
3. Install dependencies
4. Build the project and Docker images
5. Deploy the components to Kubernetes

### Working Inside the Lima VM

After setup, you can access the Lima VM with:

```bash
limactl shell vvm-dev
```

Inside the VM, navigate to the project directory:

```bash
cd /tmp/trashfire-dispenser-machine
```

### Building the Components (Inside Lima VM)

```bash
# Build all components
make build

# Build Docker images
sudo docker build -t lime-ctrl:latest -f build/lime-ctrl/Dockerfile .
sudo docker build -t kvm-device-plugin:latest -f build/kvm-device-plugin/Dockerfile .
```

### Deploying to Kubernetes (Inside Lima VM)

```bash
# Create the namespace
kubectl create namespace vvm-system

# Install CRDs (use --validate=false to bypass validation errors)
kubectl apply -f deploy/crds/ --validate=false

# Deploy all components
kubectl apply -f deploy/ --validate=false
```

### Testing the Deployment (Inside Lima VM)

```bash
# Make the test script executable
chmod +x scripts/test-deployment.sh

# Run the test script
./scripts/test-deployment.sh
```

## Usage

### Creating a MicroVM

Create a MicroVM resource:

```yaml
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MicroVM
metadata:
  name: test-vm
spec:
  image: ubuntu:20.04
  cpu: 1
  memory: 512
  mcpMode: true
```

Apply it to the cluster:

```bash
kubectl apply -f test-vm.yaml --validate=false
```

### Creating an MCP Session

Create an MCPSession resource:

```yaml
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MCPSession
metadata:
  name: test-session
spec:
  userId: "user123"
  groupId: "group456"
  vmId: "test-vm"  # Optional, will create a new VM if not specified
```

Apply it to the cluster:

```bash
kubectl apply -f test-session.yaml --validate=false
```

### Executing Code in a MicroVM

You can execute code in a MicroVM using the provided script:

```bash
./examples/execute-code.sh --vm-id test-vm --code "print('Hello, World!')"
```

## Components

### lime-ctrl

The lime-ctrl component is a Kubernetes controller that manages MicroVM custom resources. It provides:
- API server for creating, managing, and executing code in microVMs
- Integration with Kubernetes for resource management
- Support for MCP sessions
- One-time code execution capabilities

### kvm-device-plugin

The kvm-device-plugin is a Kubernetes device plugin that:
- Discovers and advertises KVM devices to the Kubernetes cluster
- Allocates KVM devices to pods that request them
- Monitors the health of KVM devices

### Flintlock

Flintlock is a service for creating and managing Firecracker microVMs. It:
- Runs Firecracker microVMs
- Manages VM lifecycle (start, stop)
- Provides isolation between VMs
- Executes commands within VMs

### MCP (Model Context Protocol)

The MCP component provides:
- Session management for models
- Communication between models and microVMs
- Tool and resource access for models

## Development

### Directory Structure

- `cmd/`: Command-line applications
  - `lime-ctrl/`: The lime-ctrl controller
  - `kvm-device-plugin/`: The KVM device plugin
- `pkg/`: Library code
  - `apis/`: API definitions
  - `controller/`: Controller implementations
  - `deviceplugin/`: Device plugin implementation
  - `flintlock/`: Flintlock client
  - `mcp/`: MCP implementation
- `deploy/`: Kubernetes deployment manifests
  - `crds/`: Custom Resource Definitions
- `build/`: Build-related files
  - `lime-ctrl/`: lime-ctrl build files
  - `kvm-device-plugin/`: kvm-device-plugin build files
- `scripts/`: Helper scripts
  - `lima-wrapper.sh`: All-in-one script for setup, build, and deployment in Lima
  - `setup-lima.sh`: Script for setting up Lima VM
  - `test-deployment.sh`: Script for testing the deployment

### Building and Testing

See the Makefile for various build and test targets.

## Troubleshooting

### Error: "the server could not find the requested resource"

If you see errors like:
```
Error from server (NotFound): the server could not find the requested resource (post namespaces)
```

This means you're trying to run kubectl commands directly on macOS instead of inside the Lima VM. Make sure to:

1. Run `limactl shell vvm-dev` to enter the Lima VM
2. Navigate to `/tmp/trashfire-dispenser-machine`
3. Run your commands there

### Validation Errors

When applying Kubernetes resources, you may see validation errors. Use the `--validate=false` flag to bypass them:

```bash
kubectl apply -f deploy/crds/ --validate=false
```

### Firecracker Crashes

If Firecracker is crashing, it might be because KVM is not available in the Lima VM. This is expected as Lima may not support nested virtualization. For a full production deployment, you would need to run this on a Kubernetes cluster with KVM support.

## License

This project is licensed under the MIT License - see the LICENSE file for details.