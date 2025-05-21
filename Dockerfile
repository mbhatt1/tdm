FROM ubuntu:22.04 as builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    python3 \
    python3-pip \
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
RUN apt-get update && apt-get install -y \
    curl \
    iproute2 \
    iptables \
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