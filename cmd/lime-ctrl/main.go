package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"

	"github.com/mbhatt/tvm/pkg/flintlock"
)

// ExecutionRequest represents a request to execute code in a MicroVM
type ExecutionRequest struct {
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
	Timeout int               `json:"timeout"`
	VMID    string            `json:"vmId"`
}

// ExecutionResponse represents the response from executing code in a MicroVM
type ExecutionResponse struct {
	Status   string `json:"status"`
	Output   string `json:"output"`
	ExitCode int    `json:"exitCode"`
	Error    string `json:"error,omitempty"`
}

// Configuration for the controller
var (
	flintlockEndpoint = "localhost:9090" // Default endpoint for Flintlock gRPC server
)

func main() {
	fmt.Println("Starting lime-ctrl...")
	
	// Check if FLINTLOCK_ENDPOINT environment variable is set
	if endpoint := os.Getenv("FLINTLOCK_ENDPOINT"); endpoint != "" {
		flintlockEndpoint = endpoint
		fmt.Printf("Using Flintlock endpoint from environment: %s\n", flintlockEndpoint)
	} else {
		fmt.Printf("Using default Flintlock endpoint: %s\n", flintlockEndpoint)
	}
	
	// Start HTTP server for API requests
	go startHTTPServer()
	
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

func startHTTPServer() {
	http.HandleFunc("/api/execute", handleExecuteRequest)
	
	fmt.Println("Starting HTTP server on :8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Failed to start HTTP server: %v\n", err)
	}
}

func handleExecuteRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	// Parse the request body
	var request ExecutionRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, fmt.Sprintf("Failed to parse request: %v", err), http.StatusBadRequest)
		return
	}
	
	// Validate the request
	if request.VMID == "" {
		http.Error(w, "VM ID is required", http.StatusBadRequest)
		return
	}
	
	// Create a flintlock client
	flintlockClient, err := flintlock.NewClient(flintlockEndpoint)
	if err != nil {
		fmt.Printf("Error creating flintlock client: %v\n", err)
		http.Error(w, fmt.Sprintf("Error creating flintlock client: %v", err), http.StatusInternalServerError)
		return
	}
	defer flintlockClient.Close()
	
	// Convert the request to a flintlock execution request
	execReq := &flintlock.ExecutionRequest{
		Command: request.Command,
		Args:    request.Args,
		Env:     request.Env,
	}
	
	// Execute the code in the VM
	execResp, err := flintlockClient.ExecuteCode(r.Context(), request.VMID, execReq)
	if err != nil {
		fmt.Printf("Error executing code in VM: %v\n", err)
		http.Error(w, fmt.Sprintf("Error executing code in VM: %v", err), http.StatusInternalServerError)
		return
	}
	
	// Convert the response
	response := ExecutionResponse{
		Status:   execResp.Status,
		Output:   execResp.Output,
		ExitCode: execResp.ExitCode,
		Error:    execResp.Error,
	}
	
	// Return the response as JSON
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, fmt.Sprintf("Failed to encode response: %v", err), http.StatusInternalServerError)
		return
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
		VMID:    "test-microvm-123",
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
		
		// Create a flintlock client
		flintlockClient, err := flintlock.NewClient(flintlockEndpoint)
		if err != nil {
			fmt.Printf("Error creating flintlock client: %v\n", err)
			return
		}
		defer flintlockClient.Close()
		
		// Convert the request to a flintlock execution request
		execReq := &flintlock.ExecutionRequest{
			Command: request.Command,
			Args:    request.Args,
			Env:     request.Env,
		}
		
		// Execute the code in the VM
		execResp, err := flintlockClient.ExecuteCode(context.Background(), request.VMID, execReq)
		if err != nil {
			fmt.Printf("Error executing code in VM: %v\n", err)
			return
		}
		
		// Convert the response
		response := ExecutionResponse{
			Status:   execResp.Status,
			Output:   execResp.Output,
			ExitCode: execResp.ExitCode,
			Error:    execResp.Error,
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
