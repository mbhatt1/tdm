# Trashfire Vending Machine (TVM)

A stateless, Python-based system that provides isolated environments for secure code execution using Firecracker microVMs. It offers cross-platform compatibility through Lima, with service mesh integration via Istio for seamless API access from host systems.

## Design Principles

1. **Complete Statelessness**: Zero persistent state across all system components
2. **Cross-Platform Compatibility**: Consistent behavior across macOS, Linux, and Windows
3. **Strong Isolation**: Hardware-level VM isolation for untrusted code
4. **Service Mesh Integration**: Seamless connectivity via Istio across system boundaries
5. **Python First**: Pure Python implementation for maximum portability
6. **Realistic Performance Expectations**: Honest performance characteristics accounting for virtualization overhead
7. **Version Independence**: Clear version compatibility matrix with minimal version coupling
8. **Robust Failure Handling**: Graceful recovery from failures at any layer
9. **Complete Resource Cleanup**: No orphaned resources in any failure scenario

## System Architecture

The system consists of four primary layers:

1. **Host Layer** (macOS/Windows/Linux)
2. **Lima Layer** (Virtualization abstraction)
3. **Kubernetes Layer** (Orchestration)
4. **Firecracker Layer** (Execution environment)

## Components

### 1. pyroshell: Host API Gateway

Acts as the entry point on the host machine, providing API access to the TVM system.

### 2. pyrolima: Lima Management

Manages the Lima virtualization layer with zero persistence.

### 3. pyrovm: Firecracker Management

Manages Firecracker microVMs for code execution.

### 4. Istio Integration

Provides connectivity between all layers of the system.

## Supported Programming Languages

- Python (3.8, 3.9, 3.10, 3.11)
- JavaScript (Node 16, 18, 20)
- Ruby (2.7, 3.0, 3.1)
- Go (1.18, 1.19, 1.20)
- Rust (1.65, 1.70)
- Java (11, 17)
- C/C++ (GCC 11, Clang 14)

## Installation

```bash
# Clone the repository
git clone https://github.com/example/tvm.git
cd tvm

# Install the package
pip install -e .
```

## Usage

```bash
# Start the TVM system
tvm start

# Execute code
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

# Check system status
tvm status

# Stop the TVM system
tvm stop
```

## Requirements

- Python 3.8+
- Lima 0.14.0+
- Kubernetes 1.23+ (K3s 1.27+ recommended inside Lima)
- Istio 1.16+
- Firecracker 1.1.0+

## License

MIT