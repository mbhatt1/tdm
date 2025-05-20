package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"time"
)

// ExecutionRequest represents a request to execute code in a MicroVM
type ExecutionRequest struct {
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
	Timeout int               `json:"timeout"`
}

// ExecutionResponse represents the response from executing code in a MicroVM
type ExecutionResponse struct {
	Status   string `json:"status"`
	Output   string `json:"output"`
	ExitCode int    `json:"exitCode"`
	Error    string `json:"error,omitempty"`
}

func main() {
	fmt.Println("Starting lime-ctrl...")
	
	// Create a channel to handle MicroVM requests
	go handleMicroVMRequests()
	
	// Create a channel to handle MCPSession requests
	go handleMCPSessionRequests()
	
	// Create a channel to handle code execution requests
	go handleCodeExecutionRequests()
	
	// Keep the main goroutine alive
	for {
		fmt.Println("Lime controller running...")
		
		// Check if there are any status files
		checkStatusFiles()
		
		time.Sleep(60 * time.Second)
	}
}

func handleMicroVMRequests() {
	fmt.Println("Starting MicroVM request handler...")
	
	// Simulate handling MicroVM requests
	for {
		// Check if there are any MicroVM requests
		fmt.Println("Checking for MicroVM requests...")
		
		// Write to the flintlock request file
		writeToFile("/var/lib/flintlock/microvms/requests.txt", "MicroVM request from lime-ctrl")
		
		// Sleep for a while
		time.Sleep(30 * time.Second)
	}
}

func handleMCPSessionRequests() {
	fmt.Println("Starting MCPSession request handler...")
	
	// Simulate handling MCPSession requests
	for {
		// Check if there are any MCPSession requests
		fmt.Println("Checking for MCPSession requests...")
		
		// Write to the flintlock request file
		writeToFile("/var/lib/flintlock/microvms/mcp_requests.txt", "MCPSession request from lime-ctrl")
		
		// Sleep for a while
		time.Sleep(45 * time.Second)
	}
}

func handleCodeExecutionRequests() {
	fmt.Println("Starting code execution request handler...")
	
	// Simulate handling code execution requests
	for {
		// Check if there are any code execution requests
		fmt.Println("Checking for code execution requests...")
		
		// Create a sample Python code execution request
		createSampleCodeExecutionRequest()
		
		// Process any execution requests
		processExecutionRequests()
		
		// Sleep for a while
		time.Sleep(20 * time.Second)
	}
}

func createSampleCodeExecutionRequest() {
	// Create a sample Python script
	pythonScript := `
import os
import sys
import json
import time
from datetime import datetime

def main():
    print("=== Virtual VM (VVM) System Demo ===")
    print("Current time:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("Python version:", sys.version)
    print("Process ID:", os.getpid())
    
    # Simulate some computation
    print("\\nPerforming computation...")
    result = 0
    for i in range(1000000):
        result += i
    print("Sum of numbers from 0 to 999999:", result)
    
    # Simulate file operations
    print("\\nPerforming file operations...")
    with open("/tmp/vvm_test_file.txt", "w") as f:
        f.write("This file was created by the VVM system\\n")
        f.write("Current time: " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "\\n")
    
    print("File created successfully")
    with open("/tmp/vvm_test_file.txt", "r") as f:
        content = f.read()
    print("File content:\\n" + content)
    
    # Return a JSON result
    result_dict = {
        "status": "success",
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "computation_result": result,
        "file_created": "/tmp/vvm_test_file.txt"
    }
    
    print("\\nJSON result:")
    print(json.dumps(result_dict, indent=2))
    return result_dict

if __name__ == "__main__":
    main()
`
	
	// Write the Python script to a file
	writeToFile("/var/lib/flintlock/sample_script.py", pythonScript)
	
	// Create an execution request
	request := ExecutionRequest{
		Command: "python3",
		Args:    []string{"/var/lib/flintlock/sample_script.py"},
		Env: map[string]string{
			"VVM_EXECUTION_ID": "test-123",
			"VVM_USER":         "user123",
		},
		Timeout: 60,
	}
	
	// Marshal the request to JSON
	requestJSON, err := json.Marshal(request)
	if err != nil {
		fmt.Printf("Error marshaling execution request: %v\n", err)
		return
	}
	
	// Write the request to a file
	writeToFile("/var/lib/flintlock/microvms/execute_request.txt", string(requestJSON))
	fmt.Println("Created sample code execution request")
}

func processExecutionRequests() {
	// Check if there's an execution request file
	if _, err := os.Stat("/var/lib/flintlock/microvms/execute_request.txt"); err == nil {
		fmt.Println("Found execution request, processing...")
		
		// Read the request file
		requestData, err := ioutil.ReadFile("/var/lib/flintlock/microvms/execute_request.txt")
		if err != nil {
			fmt.Printf("Error reading execution request: %v\n", err)
			return
		}
		
		// Parse the request
		var request ExecutionRequest
		if err := json.Unmarshal(requestData, &request); err != nil {
			fmt.Printf("Error parsing execution request: %v\n", err)
			return
		}
		
		// Forward the request to flintlock
		fmt.Printf("Forwarding execution request to flintlock: %+v\n", request)
		
		// In a real implementation, we would send the request to flintlock
		// and wait for the response. For now, we'll just simulate a response.
		
		// Simulate a response
		response := ExecutionResponse{
			Status:   "success",
			Output:   "Execution completed successfully",
			ExitCode: 0,
		}
		
		// Marshal the response to JSON
		responseJSON, err := json.Marshal(response)
		if err != nil {
			fmt.Printf("Error marshaling execution response: %v\n", err)
			return
		}
		
		// Write the response to a file
		writeToFile("/var/lib/flintlock/microvms/execute_response.txt", string(responseJSON))
		fmt.Println("Processed execution request")
		
		// Remove the request file
		os.Remove("/var/lib/flintlock/microvms/execute_request.txt")
	}
}

func checkStatusFiles() {
	// Check if there are any status files
	if _, err := os.Stat("/var/lib/flintlock/microvms/microvm-status.json"); err == nil {
		// Read the status file
		data, err := ioutil.ReadFile("/var/lib/flintlock/microvms/microvm-status.json")
		if err == nil {
			fmt.Printf("MicroVM status: %s\n", string(data))
		}
	}
	
	if _, err := os.Stat("/var/lib/flintlock/microvms/mcpsession-status.json"); err == nil {
		// Read the status file
		data, err := ioutil.ReadFile("/var/lib/flintlock/microvms/mcpsession-status.json")
		if err == nil {
			fmt.Printf("MCPSession status: %s\n", string(data))
		}
	}
	
	// Check for execution responses
	if _, err := os.Stat("/var/lib/flintlock/microvms/execute_response.txt"); err == nil {
		// Read the response file
		data, err := ioutil.ReadFile("/var/lib/flintlock/microvms/execute_response.txt")
		if err == nil {
			fmt.Printf("Execution response: %s\n", string(data))
		}
	}
}

func writeToFile(filename, content string) {
	// Create the directory if it doesn't exist
	dir := "/var/lib/flintlock/microvms"
	os.MkdirAll(dir, 0755)
	
	// Write the content to the file
	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("Error creating file %s: %v\n", filename, err)
		return
	}
	defer file.Close()
	
	_, err = file.WriteString(content)
	if err != nil {
		fmt.Printf("Error writing to file %s: %v\n", filename, err)
		return
	}
	
	fmt.Printf("Successfully wrote to file %s\n", filename)
}
