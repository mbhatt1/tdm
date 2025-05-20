# Trashfire Vending Machine (TVM)

A Kubernetes-native solution for managing lightweight virtual machines using Firecracker. It enables users to create, manage, and execute code within isolated microVMs, with support for Model Context Protocol (MCP) sessions.

## Overview

Trashfire Vending Machine (TVM) consists of several components:

```
┌─────────────────────────────────────────────────────────────────┐
│                       Kubernetes Cluster                         │
│                                                                  │
│  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐    │
│  │     Node 1    │    │     Node 2    │    │     Node 3    │    │
│  │               │    │               │    │               │    │
│  │ ┌───────────┐ │    │ ┌───────────┐ │    │ ┌───────────┐ │    │
│  │ │ lime-ctrl │ │    │ │kvm-device-│ │    │ │firecracker│ │    │
│  │ │           │ │    │ │  plugin   │ │    │ │   host    │ │    │
│  │ └───────────┘ │    │ └───────────┘ │    │ └───────────┘ │    │
│  │       │       │    │       │       │    │       │       │    │
│  │       ▼       │    │       ▼       │    │       ▼       │    │
│  │ ┌───────────┐ │    │ ┌───────────┐ │    │ ┌───────────┐ │    │
│  │ │  MicroVM  │ │    │ │  MicroVM  │ │    │ │  MicroVM  │ │    │
│  │ │           │ │    │ │           │ │    │ │           │ │    │
│  │ └───────────┘ │    │ └───────────┘ │    │ └───────────┘ │    │
│  └───────────────┘    └───────────────┘    └───────────────┘    │
└─────────────────────────────────────────────────────────────────┘
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

### flintlock
The flintlock component:
- Runs Firecracker microVMs
- Manages VM lifecycle (start, stop, snapshot)
- Provides isolation between VMs
- Executes commands within VMs

## Custom Resources

### MicroVM
The MicroVM Custom Resource Definition (CRD) defines the schema for microVMs in Kubernetes:
- VM specifications (CPU, memory, image)
- VM status and lifecycle information
- Support for snapshots and persistent storage

### MCPSession
The MCPSession CRD defines the schema for MCP sessions:
- Session specifications (user, group, VM)
- Session status and activity information
- Connection details

## Features

- **Isolated Execution**: Run code in isolated microVMs for security and resource control
- **MCP Support**: Use the Model Context Protocol to interact with models
- **Kubernetes Native**: Fully integrated with Kubernetes for orchestration and management
- **Cross-Platform**: Works on both Linux and non-Linux platforms (with some limitations)
- **Resource Efficiency**: Lightweight VMs with minimal overhead

## Getting Started

### Prerequisites
- Kubernetes cluster
- KVM-enabled nodes (for Linux)
- Lima (for macOS)

### Installation
1. Apply the CRDs:
   ```
   kubectl apply -f deploy/crds/
   ```

2. Deploy the components:
   ```
   kubectl apply -f deploy/
   ```

### Usage

#### Creating a MicroVM
```yaml
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MicroVM
metadata:
  name: test-microvm
spec:
  image: ubuntu:20.04
  cpu: 1
  memory: 512
  mcpMode: true
```

#### Creating an MCP Session
```yaml
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MCPSession
metadata:
  name: test-session
spec:
  userId: user123
  groupId: group456
  vmId: test-microvm
```

#### Executing Code
```bash
./scripts/vvm.sh execute "print('Hello from Firecracker!')"
```

## Why "Trashfire Vending Machine"?

Because sometimes you need a quick, disposable environment to run potentially dangerous code - like getting a snack from a vending machine that might be on fire. It's convenient, isolated, and you can walk away when you're done!

## License

This project is licensed under the MIT License - see the LICENSE file for details.