# TVM API Reference

This document provides a comprehensive reference for the TVM API.

## Base URL

The base URL for all API endpoints is:

```
http://localhost:8080
```

## Authentication

The TVM API does not currently require authentication. All endpoints are publicly accessible.

## API Endpoints

### Execute Code

Execute code in an isolated environment.

**Endpoint:** `/api/execute`

**Method:** `POST`

**Content-Type:** `application/json`

**Request Body:**

```json
{
  "code": "print('Hello, World!')",
  "language": "python",
  "language_version": "3.11",
  "timeout_ms": 5000,
  "memory_mb": 128,
  "cpu_count": 1
}
```

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | The source code to execute |
| `language` | string | Yes | The programming language |
| `language_version` | string | No | The language version (defaults to latest supported) |
| `timeout_ms` | integer | No | Execution timeout in milliseconds (default: 5000) |
| `memory_mb` | integer | No | Memory limit in MB (default: 128) |
| `cpu_count` | integer | No | Number of CPU cores (default: 1) |

**Response:**

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

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `request_id` | string | Unique ID for the execution request |
| `stdout` | string | Standard output from the execution |
| `stderr` | string | Standard error from the execution |
| `exit_code` | integer | Exit code from the execution |
| `execution_time_ms` | integer | Execution time in milliseconds |
| `language` | string | The programming language used |
| `language_version` | string | The language version used |

**Status Codes:**

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid parameters |
| 408 | Request Timeout - Execution timed out |
| 500 | Internal Server Error - System error during execution |
| 503 | Service Unavailable - System is starting up or overloaded |

**Example:**

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

### Health Check

Check the health of the TVM system.

**Endpoint:** `/api/health`

**Method:** `GET`

**Response:**

```json
{
  "status": "healthy",
  "version": "1.0.0",
  "lima_status": "Running",
  "kubernetes_status": "Running",
  "istio_status": "Running"
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Health status of the TVM system |
| `version` | string | API version |
| `lima_status` | string | Status of the Lima VM |
| `kubernetes_status` | string | Status of Kubernetes (if Lima is running) |
| `istio_status` | string | Status of Istio (if Kubernetes is running) |

**Status Codes:**

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 503 | Service Unavailable - System is unhealthy |

**Example:**

```bash
curl -X GET http://localhost:8080/api/health
```

## Supported Languages

### Python

**Supported Versions:** 3.8, 3.9, 3.10, 3.11

**Default Version:** 3.11

**Resource Limits:**
- Memory: 2048 MB
- CPU: 4 cores
- Timeout: 60000 ms

**Example:**

```json
{
  "code": "print('Hello from Python!')",
  "language": "python",
  "language_version": "3.11"
}
```

### JavaScript (Node.js)

**Supported Versions:** 16, 18, 20

**Default Version:** 18

**Resource Limits:**
- Memory: 1536 MB
- CPU: 4 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "console.log('Hello from JavaScript!');",
  "language": "javascript",
  "language_version": "18"
}
```

### Ruby

**Supported Versions:** 2.7, 3.0, 3.1

**Default Version:** 3.1

**Resource Limits:**
- Memory: 1024 MB
- CPU: 2 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "puts 'Hello from Ruby!'",
  "language": "ruby",
  "language_version": "3.1"
}
```

### Go

**Supported Versions:** 1.18, 1.19, 1.20

**Default Version:** 1.20

**Resource Limits:**
- Memory: 1024 MB
- CPU: 4 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "package main\n\nimport \"fmt\"\n\nfunc main() {\n  fmt.Println(\"Hello from Go!\")\n}",
  "language": "go",
  "language_version": "1.20"
}
```

### Rust

**Supported Versions:** 1.65, 1.70

**Default Version:** 1.70

**Resource Limits:**
- Memory: 1024 MB
- CPU: 4 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "fn main() {\n  println!(\"Hello from Rust!\");\n}",
  "language": "rust",
  "language_version": "1.70"
}
```

### Java

**Supported Versions:** 11, 17

**Default Version:** 17

**Resource Limits:**
- Memory: 2048 MB
- CPU: 4 cores
- Timeout: 60000 ms

**Example:**

```json
{
  "code": "public class Main {\n  public static void main(String[] args) {\n    System.out.println(\"Hello from Java!\");\n  }\n}",
  "language": "java",
  "language_version": "17"
}
```

### C

**Supported Versions:** gcc11, clang14

**Default Version:** gcc11

**Resource Limits:**
- Memory: 1024 MB
- CPU: 4 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "#include <stdio.h>\n\nint main() {\n  printf(\"Hello from C!\\n\");\n  return 0;\n}",
  "language": "c",
  "language_version": "gcc11"
}
```

### C++

**Supported Versions:** gcc11, clang14

**Default Version:** gcc11

**Resource Limits:**
- Memory: 1024 MB
- CPU: 4 cores
- Timeout: 30000 ms

**Example:**

```json
{
  "code": "#include <iostream>\n\nint main() {\n  std::cout << \"Hello from C++!\" << std::endl;\n  return 0;\n}",
  "language": "cpp",
  "language_version": "gcc11"
}
```

## Error Handling

### Error Response Format

```json
{
  "detail": "Error message describing the issue"
}
```

### Common Error Messages

| Error | Description |
|-------|-------------|
| `Unsupported language or version: {language} {version}` | The specified language or version is not supported |
| `Resource limits exceed maximum allowed values` | The requested resources exceed the maximum allowed values |
| `Failed to start virtualization environment` | Failed to start the Lima VM |
| `Execution service error: {error}` | Error from the execution service |
| `Execution timed out after multiple attempts` | The execution timed out after multiple retry attempts |
| `Internal server error: {error}` | Internal server error |

## Rate Limiting

The TVM API does not currently implement rate limiting. However, resource constraints may limit the number of concurrent requests that can be processed.

## Versioning

The TVM API is currently at version 1.0.0. The API version is included in the response to the `/api/health` endpoint.

## OpenAPI Specification

The TVM API is documented using the OpenAPI specification. The OpenAPI documentation is available at:

```
http://localhost:8080/api/docs
```

The OpenAPI JSON specification is available at:

```
http://localhost:8080/api/openapi.json
```

## Client Libraries

### Python Client

```python
import requests

def execute_code(code, language, language_version=None, timeout_ms=5000, memory_mb=128, cpu_count=1):
    url = "http://localhost:8080/api/execute"
    payload = {
        "code": code,
        "language": language,
        "timeout_ms": timeout_ms,
        "memory_mb": memory_mb,
        "cpu_count": cpu_count
    }
    
    if language_version:
        payload["language_version"] = language_version
    
    response = requests.post(url, json=payload)
    response.raise_for_status()
    
    return response.json()

# Example usage
result = execute_code("print('Hello, World!')", "python", "3.11")
print(result["stdout"])
```

### JavaScript Client

```javascript
async function executeCode(code, language, languageVersion = null, timeoutMs = 5000, memoryMb = 128, cpuCount = 1) {
  const url = "http://localhost:8080/api/execute";
  const payload = {
    code,
    language,
    timeout_ms: timeoutMs,
    memory_mb: memoryMb,
    cpu_count: cpuCount
  };
  
  if (languageVersion) {
    payload.language_version = languageVersion;
  }
  
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return await response.json();
}

// Example usage
executeCode("console.log('Hello, World!');", "javascript", "18")
  .then(result => console.log(result.stdout))
  .catch(error => console.error(error));