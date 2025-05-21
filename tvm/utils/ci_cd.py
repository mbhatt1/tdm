"""
CI/CD workflow generator for the TVM system.
"""

def generate_github_workflow() -> str:
    """
    Generate GitHub Actions workflow for CI/CD.
    
    Returns:
        GitHub Actions workflow as a string
    """
    workflow = """
name: TVM CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  release:
    types: [ published ]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: ['3.9', '3.11']
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -e ".[dev]"
    
    - name: Lint with flake8
      run: |
        pip install flake8
        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
    
    - name: Test with pytest
      run: |
        pip install pytest pytest-cov
        pytest --cov=./ --cov-report=xml
    
    - name: Upload coverage report
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        fail_ci_if_error: true

  build:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' || github.event_name == 'release'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Login to GitHub Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.repository_owner }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Set image tags
      id: tags
      run: |
        SHA_TAG="ghcr.io/${{ github.repository_owner }}/tvm/pyrovm:$(git rev-parse --short HEAD)"
        if [[ "${{ github.event_name }}" == "release" ]]; then
          VERSION="${{ github.event.release.tag_name }}"
          VERSION_TAG="ghcr.io/${{ github.repository_owner }}/tvm/pyrovm:${VERSION}"
          LATEST_TAG="ghcr.io/${{ github.repository_owner }}/tvm/pyrovm:latest"
          echo "::set-output name=tags::${SHA_TAG},${VERSION_TAG},${LATEST_TAG}"
        else
          echo "::set-output name=tags::${SHA_TAG}"
        fi
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.tags.outputs.tags }}
        platforms: linux/amd64,linux/arm64
    
    - name: Generate API documentation
      if: github.event_name == 'release'
      run: |
        pip install sphinx sphinx-rtd-theme
        sphinx-build -b html docs/source docs/build/html
    
    - name: Deploy documentation
      if: github.event_name == 'release'
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./docs/build/html
"""
    return workflow

def generate_dockerfile() -> str:
    """
    Generate Dockerfile for the TVM system.
    
    Returns:
        Dockerfile as a string
    """
    dockerfile = """
FROM ubuntu:22.04 as builder

# Install dependencies
RUN apt-get update && apt-get install -y \\
    build-essential \\
    curl \\
    git \\
    python3 \\
    python3-pip \\
    && rm -rf /var/lib/apt/lists/*

# Install Rust for Firecracker
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone and build Firecracker
RUN git clone https://github.com/firecracker-microvm/firecracker.git /firecracker
WORKDIR /firecracker
RUN git checkout v1.3.0
RUN cargo build --release

# Download kernel and rootfs
RUN mkdir -p /usr/local/bin
RUN curl -fsSL -o /usr/local/bin/vmlinux https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin
RUN curl -fsSL -o /usr/local/bin/rootfs.ext4 https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4

FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    iproute2 \\
    iptables \\
    && rm -rf /var/lib/apt/lists/*

# Copy Firecracker binary and resources
COPY --from=builder /firecracker/target/release/firecracker /usr/local/bin/
COPY --from=builder /usr/local/bin/vmlinux /usr/local/bin/
COPY --from=builder /usr/local/bin/rootfs.ext4 /usr/local/bin/

# Set up working directory
WORKDIR /app

# Copy application code
COPY . /app/

# Install Python dependencies
RUN pip install --no-cache-dir -e .

# Expose port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["python", "-m", "tvm.pyrovm.api"]
"""
    return dockerfile

def generate_docker_compose() -> str:
    """
    Generate Docker Compose configuration for the TVM system.
    
    Returns:
        Docker Compose configuration as a string
    """
    docker_compose = """
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    privileged: true
    restart: unless-stopped
    environment:
      - STATELESS_MODE=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
"""
    return docker_compose