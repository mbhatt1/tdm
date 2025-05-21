# TVM Usage Guide

This guide provides instructions for using the Trashfire Vending Machine (TVM) system.

## Command Line Interface

TVM provides a command-line interface (CLI) for managing the system.

### Basic Commands

```bash
# Start the TVM API server
tvm start

# Check the status of TVM components
tvm status

# Stop all TVM components
tvm stop

# View TVM logs
tvm logs

# View logs for a specific component
tvm logs --component api
tvm logs --component lima
tvm logs --component k8s
tvm logs --component istio
tvm logs --component tvm

# Follow logs in real-time
tvm logs --follow

# Show the last N lines of logs
tvm logs --lines 100
```

## API Usage

TVM provides a REST API for executing code in isolated environments.

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/execute` | POST | Execute code in an isolated environment |
| `/api/health` | GET | Check the health of the TVM system |

### Executing Code

To execute code, send a POST request to the `/api/execute` endpoint:

```bash
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
```

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | The source code to execute |
| `language` | string | Yes | The programming language |
| `language_version` | string | No | The language version (defaults to latest supported) |
| `timeout_ms` | integer | No | Execution timeout in milliseconds (default: 5000) |
| `memory_mb` | integer | No | Memory limit in MB (default: 128) |
| `cpu_count` | integer | No | Number of CPU cores (default: 1) |

#### Response Format

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "stdout": "Hello, World!",
  "stderr": "",
  "exit_code": 0,
  "execution_time_ms": 42,
  "language": "python",
  "language_version": "3.11"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `request_id` | string | Unique ID for the execution request |
| `stdout` | string | Standard output from the execution |
| `stderr` | string | Standard error from the execution |
| `exit_code` | integer | Exit code from the execution |
| `execution_time_ms` | integer | Execution time in milliseconds |
| `language` | string | The programming language used |
| `language_version` | string | The language version used |

### Health Check

To check the health of the TVM system, send a GET request to the `/api/health` endpoint:

```bash
curl -X GET http://localhost:8080/api/health
```

#### Response Format

```json
{
  "status": "healthy",
  "version": "1.0.0",
  "lima_status": "Running",
  "kubernetes_status": "Running",
  "istio_status": "Running"
}
```

## Supported Languages

TVM supports the following programming languages:

### Python

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "print(\"Hello from Python!\")",
    "language": "python",
    "language_version": "3.11"
  }'
```

Supported versions: 3.8, 3.9, 3.10, 3.11

### JavaScript (Node.js)

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "console.log(\"Hello from JavaScript!\");",
    "language": "javascript",
    "language_version": "18"
  }'
```

Supported versions: 16, 18, 20

### Ruby

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "puts \"Hello from Ruby!\"",
    "language": "ruby",
    "language_version": "3.1"
  }'
```

Supported versions: 2.7, 3.0, 3.1

### Go

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "package main\n\nimport \"fmt\"\n\nfunc main() {\n  fmt.Println(\"Hello from Go!\")\n}",
    "language": "go",
    "language_version": "1.20"
  }'
```

Supported versions: 1.18, 1.19, 1.20

### Rust

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "fn main() {\n  println!(\"Hello from Rust!\");\n}",
    "language": "rust",
    "language_version": "1.70"
  }'
```

Supported versions: 1.65, 1.70

### Java

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "public class Main {\n  public static void main(String[] args) {\n    System.out.println(\"Hello from Java!\");\n  }\n}",
    "language": "java",
    "language_version": "17"
  }'
```

Supported versions: 11, 17

### C

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "#include <stdio.h>\n\nint main() {\n  printf(\"Hello from C!\\n\");\n  return 0;\n}",
    "language": "c",
    "language_version": "gcc11"
  }'
```

Supported versions: gcc11, clang14

### C++

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "#include <iostream>\n\nint main() {\n  std::cout << \"Hello from C++!\" << std::endl;\n  return 0;\n}",
    "language": "cpp",
    "language_version": "gcc11"
  }'
```

Supported versions: gcc11, clang14

## Resource Limits

TVM enforces resource limits for code execution to prevent abuse and ensure fair usage.

### Default Limits

| Resource | Default | Maximum | Description |
|----------|---------|---------|-------------|
| Memory | 128 MB | 2048 MB | Maximum memory usage |
| CPU | 1 core | 4 cores | Number of CPU cores |
| Execution Time | 5000 ms | 60000 ms | Maximum execution time |

### Language-Specific Limits

| Language | Memory Limit | CPU Limit | Time Limit |
|----------|--------------|-----------|------------|
| Python | 2048 MB | 4 cores | 60000 ms |
| JavaScript | 1536 MB | 4 cores | 30000 ms |
| Ruby | 1024 MB | 2 cores | 30000 ms |
| Go | 1024 MB | 4 cores | 30000 ms |
| Rust | 1024 MB | 4 cores | 30000 ms |
| Java | 2048 MB | 4 cores | 60000 ms |
| C | 1024 MB | 4 cores | 30000 ms |
| C++ | 1024 MB | 4 cores | 30000 ms |

## Error Handling

TVM returns appropriate HTTP status codes and error messages for different error scenarios.

### Common Error Codes

| Status Code | Description | Example |
|-------------|-------------|---------|
| 400 | Bad Request | Invalid language or version, invalid resource limits |
| 408 | Request Timeout | Execution timed out |
| 500 | Internal Server Error | System error during execution |
| 503 | Service Unavailable | System is starting up or overloaded |

### Error Response Format

```json
{
  "detail": "Error message describing the issue"
}
```

## Advanced Usage

### Using Docker

TVM can be run using Docker:

```bash
# Run TVM in Docker
docker run -d --privileged -p 8080:8080 ghcr.io/example/tvm/pyrovm:latest
```

### Using Docker Compose

TVM can be run using Docker Compose:

```bash
# Run TVM with Docker Compose
docker-compose up -d
```

### Monitoring

TVM provides monitoring capabilities:

```bash
# Start monitoring
python -m tvm.utils.monitor

# Monitor with custom interval (in seconds)
python -m tvm.utils.monitor --interval 10
```

## Examples

### Python Example: Fibonacci Sequence

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "def fibonacci(n):\n    a, b = 0, 1\n    for _ in range(n):\n        a, b = b, a + b\n    return a\n\nfor i in range(10):\n    print(fibonacci(i))",
    "language": "python",
    "language_version": "3.11"
  }'
```

### JavaScript Example: Web Server

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "const http = require(\"http\");\n\nconst server = http.createServer((req, res) => {\n  res.writeHead(200, {\"Content-Type\": \"text/plain\"});\n  res.end(\"Hello, World!\");\n});\n\nserver.listen(3000, () => {\n  console.log(\"Server running at http://localhost:3000/\");\n});\n\n// Note: This server will not be accessible outside the VM",
    "language": "javascript",
    "language_version": "18"
  }'
```

### Go Example: Concurrency

```bash
curl -X POST http://localhost:8080/api/execute \
  -H "Content-Type: application/json" \
  -d '{
    "code": "package main\n\nimport (\n  \"fmt\"\n  \"time\"\n)\n\nfunc worker(id int, jobs <-chan int, results chan<- int) {\n  for j := range jobs {\n    fmt.Println(\"worker\", id, \"started job\", j)\n    time.Sleep(time.Second)\n    fmt.Println(\"worker\", id, \"finished job\", j)\n    results <- j * 2\n  }\n}\n\nfunc main() {\n  jobs := make(chan int, 5)\n  results := make(chan int, 5)\n\n  for w := 1; w <= 3; w++ {\n    go worker(w, jobs, results)\n  }\n\n  for j := 1; j <= 5; j++ {\n    jobs <- j\n  }\n  close(jobs)\n\n  for a := 1; a <= 5; a++ {\n    <-results\n  }\n}",
    "language": "go",
    "language_version": "1.20"
  }'