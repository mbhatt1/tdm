# TVM Development Guide

This guide provides information for developers who want to contribute to the Trashfire Vending Machine (TVM) system.

## Development Environment Setup

### Prerequisites

- Python 3.8 or later
- pip (Python package manager)
- Git
- Docker (for building and testing container images)
- Lima (for local testing)
- Kubernetes knowledge (for understanding the orchestration layer)
- Istio knowledge (for understanding the service mesh)
- Firecracker knowledge (for understanding the VM layer)

### Setting Up the Development Environment

1. Clone the repository:

```bash
git clone https://github.com/example/tvm.git
cd tvm
```

2. Create a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install the package in development mode:

```bash
pip install -e ".[dev]"
```

4. Install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

## Project Structure

The TVM project is organized as follows:

```
tvm/
├── docs/                  # Documentation
├── tests/                 # Tests
├── tvm/                   # Main package
│   ├── config/            # Configuration
│   ├── pyroshell/         # Host API gateway
│   ├── pyrolima/          # Lima management
│   ├── pyrovm/            # Firecracker management
│   └── utils/             # Utilities
├── .gitignore             # Git ignore file
├── Dockerfile             # Dockerfile for building container images
├── docker-compose.yml     # Docker Compose configuration
├── README.md              # Project README
└── setup.py               # Package setup file
```

### Key Components

- **pyroshell**: The host API gateway that provides the entry point for the TVM system.
- **pyrolima**: The Lima management component that handles the virtualization layer.
- **pyrovm**: The Firecracker management component that handles the VM layer.
- **config**: Configuration management for the TVM system.
- **utils**: Utility functions and helpers for the TVM system.

## Development Workflow

### Making Changes

1. Create a new branch for your changes:

```bash
git checkout -b feature/your-feature-name
```

2. Make your changes to the codebase.

3. Run the tests to ensure your changes don't break existing functionality:

```bash
pytest
```

4. Run the linter to ensure your code follows the project's style guidelines:

```bash
flake8
```

5. Commit your changes:

```bash
git add .
git commit -m "Add your feature description"
```

6. Push your changes to the remote repository:

```bash
git push origin feature/your-feature-name
```

7. Create a pull request on GitHub.

### Running Tests

TVM uses pytest for testing. To run the tests:

```bash
# Run all tests
pytest

# Run tests with coverage
pytest --cov=tvm

# Run specific tests
pytest tests/test_api.py
```

### Building Documentation

TVM uses Sphinx for documentation. To build the documentation:

```bash
# Install Sphinx
pip install sphinx sphinx-rtd-theme

# Build the documentation
cd docs
make html
```

The documentation will be available in the `docs/build/html` directory.

### Building Container Images

TVM uses Docker for containerization. To build the container image:

```bash
# Build the image
docker build -t tvm/pyrovm:latest .

# Run the image
docker run -d --privileged -p 8080:8080 tvm/pyrovm:latest
```

## Adding a New Language

To add support for a new programming language:

1. Update the `get_language_image` method in `tvm/pyrovm/firecracker.py`:

```python
def get_language_image(self, language: str, version: Optional[str] = None) -> str:
    language_images = {
        # Existing languages...
        "new-language": {
            "version1": "new-language:version1",
            "version2": "new-language:version2",
            None: "new-language:version1"  # Default
        }
    }
    
    # Rest of the method...
```

2. Update the `get_file_extension` method in `tvm/pyrovm/firecracker.py`:

```python
def get_file_extension(self, language: str) -> str:
    extensions = {
        # Existing languages...
        "new-language": "ext"
    }
    
    # Rest of the method...
```

3. Update the `get_execution_command` method in `tvm/pyrovm/firecracker.py`:

```python
def get_execution_command(self, language: str, code_path: str) -> List[str]:
    commands = {
        # Existing languages...
        "new-language": ["new-language", code_path]
    }
    
    # Rest of the method...
```

4. Update the `_is_supported_language` method in `tvm/api.py`:

```python
def _is_supported_language(language: str, version: Optional[str] = None) -> bool:
    supported_languages = {
        # Existing languages...
        "new-language": ["version1", "version2", None]
    }
    
    # Rest of the method...
```

5. Update the `_validate_resource_limits` method in `tvm/api.py`:

```python
def _validate_resource_limits(request: CodeExecutionRequest) -> bool:
    # Existing code...
    
    language_limits = {
        # Existing languages...
        "new-language": {"memory": 1024, "cpu": 2, "timeout": 30000}
    }
    
    # Rest of the method...
```

6. Add tests for the new language in `tests/test_firecracker.py` and `tests/test_api.py`.

7. Update the documentation in `docs/usage.md` and `docs/api.md`.

## Adding a New Feature

To add a new feature to TVM:

1. Identify the component that needs to be modified.

2. Make the necessary changes to the codebase.

3. Add tests for the new feature.

4. Update the documentation.

5. Submit a pull request.

## Debugging

### Debugging the API Server

To debug the API server:

```bash
# Start the API server in debug mode
tvm start --debug

# View the logs
tvm logs --component api --follow
```

### Debugging Lima

To debug Lima:

```bash
# View Lima logs
tvm logs --component lima --follow

# Directly access Lima
limactl shell <instance-name>

# View Lima status
limactl list
```

### Debugging Kubernetes

To debug Kubernetes:

```bash
# View Kubernetes logs
tvm logs --component k8s --follow

# Directly access Kubernetes
limactl shell <instance-name> kubectl get pods --all-namespaces

# View Kubernetes status
limactl shell <instance-name> kubectl get nodes
```

### Debugging Istio

To debug Istio:

```bash
# View Istio logs
tvm logs --component istio --follow

# Directly access Istio
limactl shell <instance-name> kubectl get pods -n istio-system

# View Istio status
limactl shell <instance-name> istioctl proxy-status
```

### Debugging Firecracker

To debug Firecracker:

```bash
# View TVM deployment logs
tvm logs --component tvm --follow

# Directly access TVM deployment
limactl shell <instance-name> kubectl get pods -n tvm

# View TVM deployment status
limactl shell <instance-name> kubectl describe deployment pyrovm -n tvm
```

## Performance Tuning

### Lima Performance

To tune Lima performance:

1. Adjust the memory and CPU allocation in `tvm/pyrolima/lima.py`:

```python
def __init__(self, memory: str = "4GiB", cpu: int = 4):
    # ...
```

2. Adjust the Lima configuration in `tvm/pyrolima/lima.py`:

```python
def _generate_lima_config(self, forwarded_ports: Dict[int, int]) -> Dict:
    # ...
```

### Kubernetes Performance

To tune Kubernetes performance:

1. Adjust the K3s configuration in `tvm/pyrolima/lima.py`:

```python
def _get_provision_script(self) -> str:
    # ...
    # Modify the K3s installation command
    # ...
```

### Istio Performance

To tune Istio performance:

1. Adjust the Istio configuration in `tvm/pyrolima/lima.py`:

```python
def _get_provision_script(self) -> str:
    # ...
    # Modify the Istio installation command
    # ...
```

### Firecracker Performance

To tune Firecracker performance:

1. Adjust the VM resource limits in `tvm/pyrovm/firecracker.py`:

```python
async def start_vm(self, vm_dir: str, memory_mb: int, cpu_count: int, language_image: str) -> str:
    # ...
```

2. Adjust the concurrency limits in `tvm/pyrovm/api.py`:

```python
# Resource limits
MAX_CONCURRENT_VMS = 10  # Maximum number of concurrent VMs per pod
MAX_VM_LIFETIME_SECONDS = 60  # Maximum VM lifetime to prevent leaks
MAX_CONCURRENT_REQUESTS = 20  # Maximum concurrent requests
```

## CI/CD Pipeline

TVM uses GitHub Actions for CI/CD. The pipeline is defined in `.github/workflows/ci.yml`.

### Pipeline Stages

1. **Test**: Run tests on multiple platforms and Python versions.
2. **Build**: Build the container image and push it to the GitHub Container Registry.
3. **Documentation**: Generate and deploy the documentation.

### Running the Pipeline Locally

To run the pipeline locally:

```bash
# Install act
brew install act  # On macOS

# Run the pipeline
act -j test
```

## Release Process

To release a new version of TVM:

1. Update the version number in `tvm/__init__.py`:

```python
__version__ = "x.y.z"
```

2. Update the version number in `setup.py`:

```python
setup(
    name="tvm",
    version="x.y.z",
    # ...
)
```

3. Update the CHANGELOG.md file with the changes in the new version.

4. Commit the changes:

```bash
git add .
git commit -m "Release x.y.z"
```

5. Tag the release:

```bash
git tag -a vx.y.z -m "Release x.y.z"
```

6. Push the changes and tag:

```bash
git push origin main
git push origin vx.y.z
```

7. Create a release on GitHub.

## Contributing Guidelines

### Code Style

TVM follows the PEP 8 style guide for Python code. We use flake8 for linting and black for code formatting.

```bash
# Run flake8
flake8

# Run black
black .
```

### Documentation Style

TVM uses Google-style docstrings for Python code:

```python
def function(arg1: type, arg2: type) -> return_type:
    """
    Function description.
    
    Args:
        arg1: Description of arg1
        arg2: Description of arg2
        
    Returns:
        Description of return value
        
    Raises:
        ExceptionType: Description of when this exception is raised
    """
    # Function implementation
```

### Commit Message Style

TVM follows the Conventional Commits specification for commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- feat: A new feature
- fix: A bug fix
- docs: Documentation changes
- style: Changes that do not affect the meaning of the code
- refactor: Code changes that neither fix a bug nor add a feature
- perf: Code changes that improve performance
- test: Adding or modifying tests
- chore: Changes to the build process or auxiliary tools

Example:

```
feat(pyrovm): add support for Rust language

Add support for executing Rust code in isolated Firecracker VMs.

Closes #123
```

### Pull Request Process

1. Ensure your code follows the project's style guidelines.
2. Ensure all tests pass.
3. Update the documentation if necessary.
4. Submit a pull request with a clear description of the changes.
5. Wait for code review and address any feedback.
6. Once approved, your changes will be merged into the main branch.

## Community

### Getting Help

If you need help with TVM development:

- Check the [GitHub Issues](https://github.com/example/tvm/issues)
- Join the [Discord community](https://discord.gg/example-tvm)
- Contact the maintainers at maintainers@example.com

### Reporting Bugs

If you find a bug in TVM:

1. Check if the bug has already been reported in the [GitHub Issues](https://github.com/example/tvm/issues).
2. If not, create a new issue with a clear description of the bug, steps to reproduce, and expected behavior.
3. If possible, include a minimal code example that reproduces the bug.

### Requesting Features

If you want to request a new feature:

1. Check if the feature has already been requested in the [GitHub Issues](https://github.com/example/tvm/issues).
2. If not, create a new issue with a clear description of the feature and why it would be useful.
3. If possible, include examples of how the feature would be used.

## License

TVM is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.