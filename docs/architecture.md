# TVM Architecture

The Trashfire Vending Machine (TVM) is a stateless, Python-based system that provides isolated environments for secure code execution using Firecracker microVMs. It offers cross-platform compatibility through Lima, with service mesh integration via Istio for seamless API access from host systems.

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

### Overall Architecture

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   Host OS     │     │    Lima VM    │     │  Kubernetes   │     │  Firecracker  │
│  (macOS/Win)  │     │   (Linux VM)  │     │ (Orchestrator)│     │  (Execution)  │
└───────┬───────┘     └───────┬───────┘     └───────┬───────┘     └───────┬───────┘
        │                     │                     │                     │
        │ 1. HTTP Request     │                     │                     │
        │ to pyroshell        │                     │                     │
        │─────────────────────►                     │                     │
        │                     │ 2. Forward to       │                     │
        │                     │ Istio Ingress       │                     │
        │                     │────────────────────►│                     │
        │                     │                     │ 3. Route to         │
        │                     │                     │ pyrovm service      │
        │                     │                     │────────────────────►│
        │                     │                     │                     │ 4. Start VM
        │                     │                     │                     │ and execute
        │                     │                     │                     │ code
        │                     │                     │                     │
        │                     │                     │ 5. Return results   │
        │                     │                     │◄────────────────────│
        │                     │ 6. Return via       │                     │
        │                     │ Istio Egress        │                     │
        │                     │◄────────────────────│                     │
        │ 7. HTTP Response    │                     │                     │
        │ with results        │                     │                     │
        │◄─────────────────────                     │                     │
        │                     │                     │                     │
```

## Components

### 1. pyroshell: Host API Gateway

**Purpose**: Acts as the entry point on the host machine, providing API access to the TVM system.

**Key Responsibilities**:
- Exposes HTTP/gRPC API endpoints for code execution requests
- Manages Lima VM lifecycle
- Forwards requests to Istio ingress gateway
- Returns execution results to clients
- Maintains zero state persistence

**Flow**:
1. Receives HTTP/gRPC requests from clients
2. Ensures Lima VM is running (starts if needed)
3. Forwards requests to Lima's exposed Istio ingress port
4. Awaits response from Lima/Istio
5. Returns execution results to client
6. Cleans up any temporary resources

### 2. pyrolima: Lima Management

**Purpose**: Manages the Lima virtualization layer with zero persistence.

**Key Responsibilities**:
- Creates ephemeral Lima configurations
- Manages VM lifecycle (start/stop)
- Configures port forwarding
- Ensures Kubernetes is running inside Lima
- Deploys and configures Istio

**Flow**:
1. Creates temporary Lima configuration
2. Starts Lima VM with necessary port forwarding
3. Verifies Kubernetes is running
4. Deploys Istio if not already present
5. Configures Istio gateways for external access
6. Monitors Lima VM health

### 3. pyrovm: Firecracker Management

**Purpose**: Manages Firecracker microVMs for code execution.

**Key Responsibilities**:
- Starts and stops Firecracker VMs
- Provides a REST API for code execution
- Manages ephemeral VM resources
- Integrates with Istio for service mesh capabilities
- Maintains zero state persistence

**Flow**:
1. Receives code execution request via Istio
2. Allocates ephemeral resources for Firecracker VM
3. Starts Firecracker with minimal configuration
4. Injects and executes code in the VM
5. Captures execution results
6. Terminates VM immediately after execution
7. Returns results via Istio

### 4. Istio Integration

**Purpose**: Provides connectivity between all layers of the system.

**Key Responsibilities**:
- Routes traffic from Lima to Kubernetes services
- Exposes Kubernetes services to Lima host
- Manages service mesh configuration
- Secures communication between components

**Flow**:
1. Receives traffic on ingress gateway from Lima host
2. Routes traffic to appropriate Kubernetes service
3. Applies traffic policies and security
4. Returns responses via egress gateway

## Version Compatibility Matrix

| Component | Minimum Version | Recommended Version | Notes |
|-----------|-----------------|---------------------|-------|
| Python    | 3.8+            | 3.11+               | Async/await support required |
| Lima      | 0.14.0+         | 0.17.0+             | Includes networking stability fixes |
| Kubernetes| 1.23+           | 1.27+               | K3s 1.27+ recommended inside Lima |
| Istio     | 1.16+           | 1.18+               | Minimal profile with reduced resource usage |
| Firecracker | 1.1.0+        | 1.3.0+              | Required for proper memory management |

## Cross-Platform Requirements

| Platform | Requirements | Special Considerations |
|----------|--------------|------------------------|
| macOS    | - macOS 12+ (Monterey)<br>- 8GB+ RAM<br>- Hyperkit or QEMU | - Uses Hyperkit by default<br>- VirtioFS for improved file performance |
| Linux    | - Ubuntu 20.04+/Fedora 36+<br>- KVM support<br>- 6GB+ RAM | - Direct KVM access<br>- Better performance than macOS/Windows |
| Windows  | - Windows 10/11<br>- WSL2 enabled<br>- 8GB+ RAM | - Uses WSL2 backend<br>- Slower file I/O performance<br>- May require special networking configuration |

## Performance Characteristics

| Metric | Expected Value | Notes |
|--------|---------------|-------|
| Cold start | 3-5 seconds | Includes Lima → K8s → Firecracker overhead |
| Warm start | 1-2 seconds | No snapshots due to statelessness |
| Memory overhead | ~150MB per microVM | Higher due to nested virtualization |
| CPU overhead | ~15-20% | Includes Istio and multi-layer virtualization |
| Max VMs per node | 10-20 | Limited by nested virtualization |
| Max concurrent requests | ~100 per Lima instance | Based on resource constraints |
| API latency | 50-100ms | Additional network hops through Lima/Istio |
| Network throughput | 100-500 Mbps | Limited by virtualization overhead |
| Disk I/O | 50-100 MB/s | Multiple filesystem layers impact performance |

## Security Considerations

### Multi-Layer Security Model

The system implements security at multiple layers:

1. **Host Isolation**
   - Lima VM provides first layer of isolation from host
   - Resource limits prevent host resource exhaustion
   - No persistent state eliminates data leakage risks

2. **Network Security**
   - Istio mTLS between all services
   - Network policies enforce traffic restrictions
   - Egress filtering prevents outbound connections from executed code

3. **VM Isolation**
   - Firecracker microVMs provide hardware-level isolation
   - Read-only root filesystem prevents persistence
   - Resource limits enforced at VM boundary

4. **Code Execution Security**
   - Languages execute in restricted environments
   - Network access disabled in execution context
   - Timeouts enforce maximum execution duration
   - Resource limits prevent denial of service

5. **Cross-Platform Security Considerations**
   - macOS: Relies on hypervisor framework security
   - Linux: Direct KVM security model
   - Windows: WSL2 container isolation

## Failure Recovery Flow

The system can recover from failures at any layer:

1. **Firecracker VM Failure**
   - Firecracker VM crashes → pyrovm pod detects failure → VM resources cleaned up → Next request starts fresh VM
   - No state loss due to complete statelessness

2. **Kubernetes Pod Failure**
   - Pod crashes → Kubernetes restarts pod → New pod initializes → System continues operation
   - Requests in flight receive error response → Client can retry

3. **Istio Component Failure**
   - Istio component fails → K8s restarts component → Traffic resumes
   - In-flight requests may fail → Client retry handling

4. **Lima VM Failure**
   - Lima VM crashes → pyroshell detects failure → Lima VM restarted with fresh config
   - Boot sequence repeats from step 4 → System ready in 60-90 seconds
   - Clients receive 503 errors during recovery → Can implement retry with backoff

5. **Host Process Failure**
   - pyroshell crashes → OS/supervisor restarts process → Fresh Lima VM started
   - Complete system reinitialization
   - No orphaned resources due to process cleanup on termination