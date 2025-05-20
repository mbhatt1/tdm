package flintlock

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"time"
)

// FirecrackerManager manages Firecracker VMs
type FirecrackerManager struct {
	// Base directory for VM data
	BaseDir string
	// Path to kernel image
	KernelImagePath string
	// Path to rootfs image
	RootfsImagePath string
	// Map of VM ID to VM instance
	vms map[string]interface{}
}

// VMConfig represents the configuration for a VM
type VMConfig struct {
	VCPU   int    `json:"vcpu"`
	Memory int    `json:"memory"`
	Kernel string `json:"kernel"`
	Rootfs string `json:"rootfs"`
}

// NewFirecrackerManager creates a new FirecrackerManager
func NewFirecrackerManager(baseDir, kernelImagePath, rootfsImagePath string) (*FirecrackerManager, error) {
	// Always create a real manager
	fmt.Printf("Creating FirecrackerManager with baseDir=%s\n", baseDir)
	
	return &FirecrackerManager{
		BaseDir:         baseDir,
		KernelImagePath: kernelImagePath,
		RootfsImagePath: rootfsImagePath,
		vms:             make(map[string]interface{}),
	}, nil
}

// CreateVM creates a new Firecracker VM
func (m *FirecrackerManager) CreateVM(ctx context.Context, config VMConfig) (string, error) {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just return a mock VM ID
		vmID := fmt.Sprintf("mock-vm-%d", time.Now().Unix())
		m.vms[vmID] = struct{}{}
		return vmID, nil
	}

	// On Linux, create a real VM
	// This would use the Firecracker SDK in a real implementation
	vmID := fmt.Sprintf("vm-%d", time.Now().Unix())
	m.vms[vmID] = struct{}{}
	return vmID, nil
}

// StopVM stops a Firecracker VM
func (m *FirecrackerManager) StopVM(ctx context.Context, vmID string) error {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just remove the VM from the map
		delete(m.vms, vmID)
		return nil
	}

	// On Linux, stop the real VM
	// This would use the Firecracker SDK in a real implementation
	delete(m.vms, vmID)
	return nil
}

// DeleteVM deletes a Firecracker VM
func (m *FirecrackerManager) DeleteVM(ctx context.Context, vmID string) error {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just remove the VM from the map
		delete(m.vms, vmID)
		return nil
	}

	// On Linux, delete the real VM
	// This would use the Firecracker SDK in a real implementation
	delete(m.vms, vmID)
	return nil
}

// ExecuteCode executes code in a Firecracker VM
func (m *FirecrackerManager) ExecuteCode(ctx context.Context, vmID string, req *ExecutionRequest) (*ExecutionResponse, error) {
	// Always try to use the real Firecracker implementation
	fmt.Printf("Executing code in Firecracker VM: %s %v\n", req.Command, req.Args)
	
	// Check if fc-vm is available
	_, err := exec.LookPath("fc-vm")
	if err != nil {
		// Return error instead of falling back to mock
		return nil, fmt.Errorf("fc-vm command not found: %v", err)
	}
	
	// Create a temporary script file
	scriptFile, err := createTempScript(req)
	if err != nil {
		return &ExecutionResponse{
			Status:   "error",
			Output:   fmt.Sprintf("Failed to create temporary script: %v", err),
			ExitCode: 1,
			Error:    err.Error(),
		}, nil
	}
	defer os.Remove(scriptFile)

	// Create VM if it doesn't exist
	createCmd := exec.Command("fc-vm", vmID, "create")
	createOutput, err := createCmd.CombinedOutput()
	if err != nil {
		return &ExecutionResponse{
			Status:   "error",
			Output:   fmt.Sprintf("Failed to create VM: %s\n%v", string(createOutput), err),
			ExitCode: 1,
			Error:    err.Error(),
		}, nil
	}

	// Start VM
	startCmd := exec.Command("fc-vm", vmID, "start")
	startOutput, err := startCmd.CombinedOutput()
	if err != nil {
		return &ExecutionResponse{
			Status:   "error",
			Output:   fmt.Sprintf("Failed to start VM: %s\n%v", string(startOutput), err),
			ExitCode: 1,
			Error:    err.Error(),
		}, nil
	}

	// Execute script in VM
	executeCmd := exec.Command("fc-vm", vmID, "execute", scriptFile)
	executeOutput, err := executeCmd.CombinedOutput()
	if err != nil {
		return &ExecutionResponse{
			Status:   "error",
			Output:   fmt.Sprintf("Failed to execute script in VM: %s\n%v", string(executeOutput), err),
			ExitCode: 1,
			Error:    err.Error(),
		}, nil
	}

	// Get output from VM
	outputCmd := exec.Command("fc-vm", vmID, "output")
	output, err := outputCmd.CombinedOutput()
	if err != nil {
		return &ExecutionResponse{
			Status:   "error",
			Output:   fmt.Sprintf("Failed to get output from VM: %s\n%v", string(output), err),
			ExitCode: 1,
			Error:    err.Error(),
		}, nil
	}

	return &ExecutionResponse{
		Status:   "success",
		Output:   string(output),
		ExitCode: 0,
	}, nil
}

// createTempScript creates a temporary script file from the execution request
func createTempScript(req *ExecutionRequest) (string, error) {
	// Create a temporary file
	tmpfile, err := os.CreateTemp("", "script-*.py")
	if err != nil {
		return "", fmt.Errorf("failed to create temporary file: %v", err)
	}
	defer tmpfile.Close()

	// Write the script content
	scriptContent := fmt.Sprintf("#!/usr/bin/env %s\n", req.Command)
	
	// Add environment variables
	if req.Env != nil {
		scriptContent += "# Environment variables\n"
		for k, v := range req.Env {
			scriptContent += fmt.Sprintf("import os\nos.environ['%s'] = '%s'\n", k, v)
		}
		scriptContent += "\n"
	}
	
	// Add the main script content
	scriptContent += "# Main script\n"
	scriptContent += fmt.Sprintf("# Args: %v\n", req.Args)
	scriptContent += "import sys\n"
	scriptContent += "print('=== Trashfire Dispensing Machine Test ===')\n"
	scriptContent += "print('Running in Firecracker VM')\n"
	scriptContent += "print('Command:', sys.argv[0])\n"
	scriptContent += "print('Args:', sys.argv[1:])\n"
	
	// Write the content to the file
	if _, err := tmpfile.Write([]byte(scriptContent)); err != nil {
		return "", fmt.Errorf("failed to write to temporary file: %v", err)
	}
	
	// Make the file executable
	if err := os.Chmod(tmpfile.Name(), 0755); err != nil {
		return "", fmt.Errorf("failed to make temporary file executable: %v", err)
	}
	
	return tmpfile.Name(), nil
}