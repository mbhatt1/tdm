package flintlock

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"runtime"
	"time"

	"github.com/yourusername/tvm/pkg/apis/vvm/v1alpha1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/anypb"

	flintlockv1 "github.com/liquidmetal-dev/flintlock/api/services/microvm/v1alpha1"
	flintlocktypes "github.com/liquidmetal-dev/flintlock/api/types"
	log "github.com/sirupsen/logrus"
)

// Client is a client for interacting with Flintlock
type Client struct {
	endpoint string
	client   flintlockv1.MicroVMClient
	conn     *grpc.ClientConn
	// For non-Linux platforms
	mockVMs map[string]*v1alpha1.MicroVM
}

// NewClient creates a new Flintlock client
func NewClient(endpoint string) (*Client, error) {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		log.Warn("Flintlock is only fully supported on Linux. Using mock implementation.")
		return &Client{
			endpoint: endpoint,
			mockVMs:  make(map[string]*v1alpha1.MicroVM),
		}, nil
	}

	conn, err := grpc.Dial(endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to flintlock: %v", err)
	}

	client := flintlockv1.NewMicroVMClient(conn)

	return &Client{
		endpoint: endpoint,
		client:   client,
		conn:     conn,
		mockVMs:  make(map[string]*v1alpha1.MicroVM),
	}, nil
}

// Close closes the client connection
func (c *Client) Close() error {
	if runtime.GOOS != "linux" {
		return nil
	}

	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// CreateMicroVM creates a new microVM
func (c *Client) CreateMicroVM(ctx context.Context, vm *v1alpha1.MicroVM) error {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just store the VM in memory
		vmID := fmt.Sprintf("%s-%s-%d", vm.Namespace, vm.Name, time.Now().Unix())
		vm.Status.VMID = vmID
		vm.Status.State = v1alpha1.MicroVMStateRunning
		vm.Status.Node = "mock-node"
		c.mockVMs[vmID] = vm
		log.Infof("Created mock VM with ID: %s", vmID)
		return nil
	}

	// Convert our MicroVM to Flintlock MicroVMSpec
	spec, err := convertToFlintlockSpec(vm)
	if err != nil {
		return fmt.Errorf("failed to convert to flintlock spec: %v", err)
	}

	// Create metadata map
	metadata := map[string]*anypb.Any{
		"namespace": {}, // This would need to be properly populated
		"name":      {}, // This would need to be properly populated
	}

	// Create the request
	req := &flintlockv1.CreateMicroVMRequest{
		Microvm:  spec,
		Metadata: metadata,
	}

	// Call the Flintlock API
	resp, err := c.client.CreateMicroVM(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create microVM: %v", err)
	}

	// Update our MicroVM with the response
	vm.Status.VMID = resp.Microvm.Spec.Id
	vm.Status.State = v1alpha1.MicroVMStateRunning

	return nil
}

// DeleteMicroVM deletes a microVM
func (c *Client) DeleteMicroVM(ctx context.Context, vmID string) error {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just remove the VM from memory
		delete(c.mockVMs, vmID)
		log.Infof("Deleted mock VM with ID: %s", vmID)
		return nil
	}

	// Create the request
	req := &flintlockv1.DeleteMicroVMRequest{
		Uid: vmID,
	}

	// Call the Flintlock API
	_, err := c.client.DeleteMicroVM(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete microVM: %v", err)
	}

	return nil
}

// GetMicroVM gets a microVM
func (c *Client) GetMicroVM(ctx context.Context, vmID string) (*flintlockv1.GetMicroVMResponse, error) {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, check if the VM exists in memory
		vm, ok := c.mockVMs[vmID]
		if !ok {
			return nil, fmt.Errorf("microVM not found: %s", vmID)
		}

		// Create a mock response
		spec, _ := convertToFlintlockSpec(vm)
		mockVM := &flintlocktypes.MicroVM{
			Spec:   spec,
			Status: &flintlocktypes.MicroVMStatus{State: flintlocktypes.MicroVMStatus_CREATED},
		}

		return &flintlockv1.GetMicroVMResponse{
			Microvm: mockVM,
		}, nil
	}

	// Create the request
	req := &flintlockv1.GetMicroVMRequest{
		Uid: vmID,
	}

	// Call the Flintlock API
	resp, err := c.client.GetMicroVM(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to get microVM: %v", err)
	}

	return resp, nil
}

// ListMicroVMs lists microVMs
func (c *Client) ListMicroVMs(ctx context.Context) ([]*flintlocktypes.MicroVM, error) {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, convert the in-memory VMs to Flintlock VMs
		var microvms []*flintlocktypes.MicroVM
		for _, vm := range c.mockVMs {
			spec, _ := convertToFlintlockSpec(vm)
			mockVM := &flintlocktypes.MicroVM{
				Spec:   spec,
				Status: &flintlocktypes.MicroVMStatus{State: flintlocktypes.MicroVMStatus_CREATED},
			}
			microvms = append(microvms, mockVM)
		}
		return microvms, nil
	}

	// Create the request
	req := &flintlockv1.ListMicroVMsRequest{}

	// Call the Flintlock API
	resp, err := c.client.ListMicroVMs(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to list microVMs: %v", err)
	}

	return resp.GetMicrovm(), nil
}

// convertToFlintlockSpec converts our MicroVM to a Flintlock MicroVMSpec
func convertToFlintlockSpec(vm *v1alpha1.MicroVM) (*flintlocktypes.MicroVMSpec, error) {
	// This is a simplified conversion and would need to be expanded
	// based on the full Flintlock API
	
	// Create a container source string
	containerSource := vm.Spec.Image
	
	spec := &flintlocktypes.MicroVMSpec{
		Id:         fmt.Sprintf("%s-%s", vm.Namespace, vm.Name),
		Vcpu:       int32(vm.Spec.CPU),
		MemoryInMb: int32(vm.Spec.Memory),
		RootVolume: &flintlocktypes.Volume{
			Id:         "root",
			IsReadOnly: false,
			Source: &flintlocktypes.VolumeSource{
				ContainerSource: &containerSource,
			},
		},
	}

	return spec, nil
}

// UpdateMicroVMStatus updates the status of a MicroVM based on Flintlock's response
func (c *Client) UpdateMicroVMStatus(vm *v1alpha1.MicroVM) error {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, check if the VM exists in memory
		mockVM, ok := c.mockVMs[vm.Status.VMID]
		if !ok {
			return fmt.Errorf("microVM not found: %s", vm.Status.VMID)
		}

		// Update the status from the mock VM
		vm.Status = mockVM.Status
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	resp, err := c.GetMicroVM(ctx, vm.Status.VMID)
	if err != nil {
		return err
	}

	// Update status based on Flintlock's response
	vm.Status.VMID = resp.Microvm.Spec.Id

	// Map Flintlock state to our state
	switch resp.Microvm.Status.State {
	case flintlocktypes.MicroVMStatus_PENDING:
		vm.Status.State = v1alpha1.MicroVMStateCreating
	case flintlocktypes.MicroVMStatus_CREATED:
		vm.Status.State = v1alpha1.MicroVMStateRunning
	case flintlocktypes.MicroVMStatus_FAILED:
		vm.Status.State = v1alpha1.MicroVMStateError
	case flintlocktypes.MicroVMStatus_DELETING:
		vm.Status.State = v1alpha1.MicroVMStateDeleted
	}

	return nil
}

// ExecuteCode executes code in a microVM
func (c *Client) ExecuteCode(ctx context.Context, vmID string, req *ExecutionRequest) (*ExecutionResponse, error) {
	// Check if we're on Linux
	if runtime.GOOS != "linux" {
		// On non-Linux platforms, just return a mock response
		log.Infof("Executing code in mock VM: %s", vmID)
		return &ExecutionResponse{
			Status:   "success",
			Output:   fmt.Sprintf("Mock execution of %s with args %v", req.Command, req.Args),
			ExitCode: 0,
		}, nil
	}

	// In a real implementation, we would use the Firecracker SDK to execute the code
	// For now, we'll use a simple approach to demonstrate the concept
	log.Infof("Executing code in VM: %s", vmID)
	
	// Create a temporary file for the script
	scriptPath := fmt.Sprintf("/tmp/%s-script.py", vmID)
	if err := ioutil.WriteFile(scriptPath, []byte(req.Args[0]), 0755); err != nil {
		return nil, fmt.Errorf("failed to write script file: %v", err)
	}
	
	// Execute the command
	cmd := exec.CommandContext(ctx, req.Command, scriptPath)
	cmd.Env = os.Environ()
	for k, v := range req.Env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}
	
	// Capture the output
	output, err := cmd.CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			return nil, fmt.Errorf("failed to execute command: %v", err)
		}
	}
	
	// Create response
	resp := &ExecutionResponse{
		Status:   "success",
		Output:   string(output),
		ExitCode: exitCode,
	}
	if exitCode != 0 {
		resp.Status = "error"
		resp.Error = fmt.Sprintf("command failed with exit code %d", exitCode)
	}
	
	return resp, nil
}
