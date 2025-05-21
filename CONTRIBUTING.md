# Contributing to TVM

Thank you for your interest in contributing to the Trashfire Vending Machine (TVM) project! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please read it before contributing.

## How Can I Contribute?

### Reporting Bugs

If you find a bug in TVM:

1. Check if the bug has already been reported in the [GitHub Issues](https://github.com/example/tvm/issues).
2. If not, create a new issue with a clear description of the bug, steps to reproduce, and expected behavior.
3. If possible, include a minimal code example that reproduces the bug.

### Suggesting Enhancements

If you want to suggest an enhancement:

1. Check if the enhancement has already been suggested in the [GitHub Issues](https://github.com/example/tvm/issues).
2. If not, create a new issue with a clear description of the enhancement and why it would be useful.
3. If possible, include examples of how the enhancement would be used.

### Pull Requests

1. Fork the repository.
2. Create a new branch for your changes.
3. Make your changes.
4. Run the tests to ensure your changes don't break existing functionality.
5. Submit a pull request.

## Development Environment

See the [Development Guide](docs/development.md) for instructions on setting up a development environment.

## Coding Guidelines

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

## Testing

TVM uses pytest for testing. To run the tests:

```bash
# Run all tests
pytest

# Run tests with coverage
pytest --cov=tvm

# Run specific tests
pytest tests/test_api.py
```

## Pull Request Process

1. Ensure your code follows the project's style guidelines.
2. Ensure all tests pass.
3. Update the documentation if necessary.
4. Submit a pull request with a clear description of the changes.
5. Wait for code review and address any feedback.
6. Once approved, your changes will be merged into the main branch.

## License

By contributing to TVM, you agree that your contributions will be licensed under the project's MIT License.