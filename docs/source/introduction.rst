Introduction
============

What is TVM?
-----------

Trashfire Vending Machine (TVM) is a stateless, Python-based system that provides isolated environments for secure code execution using Firecracker microVMs. It offers cross-platform compatibility through Lima, with service mesh integration via Istio for seamless API access from host systems.

Key Features
-----------

- **Complete Statelessness**: Zero persistent state across all system components
- **Cross-Platform Compatibility**: Consistent behavior across macOS, Linux, and Windows
- **Strong Isolation**: Hardware-level VM isolation for untrusted code
- **Service Mesh Integration**: Seamless connectivity via Istio across system boundaries
- **Python First**: Pure Python implementation for maximum portability
- **Realistic Performance Expectations**: Honest performance characteristics accounting for virtualization overhead
- **Version Independence**: Clear version compatibility matrix with minimal version coupling
- **Robust Failure Handling**: Graceful recovery from failures at any layer
- **Complete Resource Cleanup**: No orphaned resources in any failure scenario

Supported Languages
------------------

TVM supports the following programming languages:

- Python (3.8, 3.9, 3.10, 3.11)
- JavaScript (Node 16, 18, 20)
- Ruby (2.7, 3.0, 3.1)
- Go (1.18, 1.19, 1.20)
- Rust (1.65, 1.70)
- Java (11, 17)
- C/C++ (GCC 11, Clang 14)

System Architecture
------------------

The system consists of four primary layers:

1. **Host Layer** (macOS/Windows/Linux)
2. **Lima Layer** (Virtualization abstraction)
3. **Kubernetes Layer** (Orchestration)
4. **Firecracker Layer** (Execution environment)

Components
---------

- **pyroshell**: The host API gateway that provides the entry point for the TVM system.
- **pyrolima**: The Lima management component that handles the virtualization layer.
- **pyrovm**: The Firecracker management component that handles the VM layer.
- **config**: Configuration management for the TVM system.
- **utils**: Utility functions and helpers for the TVM system.

Use Cases
--------

TVM is designed for the following use cases:

- **Code Execution Platforms**: Safely execute untrusted code in isolated environments
- **Online IDEs and Code Editors**: Provide a secure backend for code execution
- **Programming Competitions**: Execute and evaluate code submissions
- **Educational Platforms**: Run student code in a safe environment
- **API Testing**: Test API integrations with different programming languages
- **Continuous Integration**: Execute tests in isolated environments
- **Serverless Computing**: Run functions in isolated environments

Getting Started
--------------

To get started with TVM, see the :doc:`installation` and :doc:`usage` guides.