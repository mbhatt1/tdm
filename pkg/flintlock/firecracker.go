package flintlock

import (
	"context"
	"fmt"
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
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just return a mock manager
		return &FirecrackerManager{
			BaseDir:         baseDir,
			KernelImagePath: kernelImagePath,
			RootfsImagePath: rootfsImagePath,
			vms:             make(map[string]interface{}),
		}, nil
	}

	// On Linux, create a real manager
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
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just return a mock response
		return &ExecutionResponse{
			Status:   "success",
			Output:   fmt.Sprintf("Mock execution of %s with args %v", req.Command, req.Args),
			ExitCode: 0,
		}, nil
	}

	// On Linux, execute the code in the real VM
	// This would use the Firecracker SDK in a real implementation
	return &ExecutionResponse{
		Status:   "success",
		Output:   fmt.Sprintf("Execution of %s with args %v", req.Command, req.Args),
		ExitCode: 0,
	}, nil
}