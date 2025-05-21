package flintlock

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/mbhatt/tvm/pkg/apis/vvm/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
}

// NewClient creates a new Flintlock client
func NewClient(endpoint string) (*Client, error) {

	conn, err := grpc.Dial(endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to flintlock: %v", err)
	}

	client := flintlockv1.NewMicroVMClient(conn)

	return &Client{
		endpoint: endpoint,
		client:   client,
		conn:     conn,
	}, nil
}

// Close closes the client connection
func (c *Client) Close() error {

	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// CreateMicroVM creates a new microVM
func (c *Client) CreateMicroVM(ctx context.Context, vm *v1alpha1.MicroVM) error {
	// Convert our MicroVM to a Flintlock MicroVMSpec
	spec, err := convertToFlintlockSpec(vm)
	if err != nil {
		return fmt.Errorf("failed to convert MicroVM to Flintlock spec: %v", err)
	}
	
	// Create the request
	req := &flintlockv1.CreateMicroVMRequest{
		Microvm: spec,
	}
	
	// Call the Flintlock API
	resp, err := c.client.CreateMicroVM(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create microVM: %v", err)
	}
	
	// Update the VM status with the response
	vm.Status.VMID = resp.Microvm.Id
	vm.Status.State = v1alpha1.MicroVMStateRunning
	
	// Set the last activity time
	now := metav1.Now()
	vm.Status.LastActivity = &now
	
	// Log the creation
	log.Infof("Created MicroVM %s in namespace %s with ID %s",
		vm.Name, vm.Namespace, vm.Status.VMID)
	
	return nil
}

// DeleteMicroVM deletes a microVM
func (c *Client) DeleteMicroVM(ctx context.Context, vmID string) error {

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
	// Create a container source string
	containerSource := vm.Spec.Image
	
	// Set default values if not specified
	vcpu := int32(1)
	if vm.Spec.CPU > 0 {
		vcpu = int32(vm.Spec.CPU)
	}
	
	memory := int32(512)
	if vm.Spec.Memory > 0 {
		memory = int32(vm.Spec.Memory)
	}
	
	// Create the spec
	spec := &flintlocktypes.MicroVMSpec{
		Id:         fmt.Sprintf("%s-%s", vm.Namespace, vm.Name),
		Vcpu:       vcpu,
		MemoryInMb: memory,
		RootVolume: &flintlocktypes.Volume{
			Id:         "root",
			IsReadOnly: false,
			Source: &flintlocktypes.VolumeSource{
				ContainerSource: &containerSource,
			},
		},
		Metadata: map[string]string{
			"namespace": vm.Namespace,
			"name":      vm.Name,
		},
	}
	
	// Add command if specified
	if len(vm.Spec.Command) > 0 {
		spec.Metadata["command"] = strings.Join(vm.Spec.Command, " ")
	}
	
	// Add snapshot if specified
	if vm.Spec.Snapshot != "" {
		spec.Metadata["snapshot"] = vm.Spec.Snapshot
	}
	
	return spec, nil
}

// UpdateMicroVMStatus updates the status of a MicroVM based on Flintlock's response
func (c *Client) UpdateMicroVMStatus(vm *v1alpha1.MicroVM) error {
	// If VMID is not set, we can't update the status
	if vm.Status.VMID == "" {
		return fmt.Errorf("VM ID is not set")
	}
	
	// Get the VM from Flintlock
	resp, err := c.GetMicroVM(context.Background(), vm.Status.VMID)
	if err != nil {
		return fmt.Errorf("failed to get microVM status: %v", err)
	}
	
	// Update the VM status based on the response
	switch resp.Microvm.Status.State {
	case flintlocktypes.MicroVMStatus_PENDING:
		vm.Status.State = v1alpha1.MicroVMStateCreating
	case flintlocktypes.MicroVMStatus_RUNNING:
		vm.Status.State = v1alpha1.MicroVMStateRunning
	case flintlocktypes.MicroVMStatus_FAILED:
		vm.Status.State = v1alpha1.MicroVMStateError
		vm.Status.Error = resp.Microvm.Status.FailureReason
	case flintlocktypes.MicroVMStatus_DELETED:
		vm.Status.State = v1alpha1.MicroVMStateDeleted
	default:
		vm.Status.State = v1alpha1.MicroVMStateError
		vm.Status.Error = fmt.Sprintf("Unknown state: %s", resp.Microvm.Status.State)
	}
	
	// Set the node name if available
	if resp.Microvm.Status.Host != "" {
		vm.Status.Node = resp.Microvm.Status.Host
	}
	
	// Set the last activity time
	now := metav1.Now()
	vm.Status.LastActivity = &now
	
	return nil
}

// ExecutionRequest represents a request to execute code in a MicroVM
type ExecutionRequest struct {
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
}

// ExecutionResponse represents the response from executing code in a MicroVM
type ExecutionResponse struct {
	Status   string `json:"status"`
	Output   string `json:"output"`
	ExitCode int    `json:"exitCode"`
	Error    string `json:"error,omitempty"`
}

// ExecuteCode executes code in a microVM
func (c *Client) ExecuteCode(ctx context.Context, vmID string, req *ExecutionRequest) (*ExecutionResponse, error) {
	log.Infof("Executing code in VM: %s", vmID)
	
	// Create a temporary file for the script if it's a Python script
	var scriptPath string
	if req.Command == "python3" && len(req.Args) > 0 && !strings.HasPrefix(req.Args[0], "/") {
		scriptPath = fmt.Sprintf("/tmp/%s-script.py", vmID)
		if err := os.WriteFile(scriptPath, []byte(req.Args[0]), 0755); err != nil {
			return nil, fmt.Errorf("failed to write script file: %v", err)
		}
		defer os.Remove(scriptPath)
		
		// Replace the script content with the path
		req.Args[0] = scriptPath
	}
	
	// Create the execution request for Flintlock
	execReq := &flintlockv1.ExecMicroVMRequest{
		MicroVMID: vmID,
		Command:   req.Command,
		Args:      req.Args,
		Env:       req.Env,
	}
	
	// Call the Flintlock API
	execResp, err := c.client.ExecMicroVM(ctx, execReq)
	if err != nil {
		return nil, fmt.Errorf("failed to execute code in microVM: %v", err)
	}
	
	// Create response
	resp := &ExecutionResponse{
		Status:   "success",
		Output:   execResp.Output,
		ExitCode: int(execResp.ExitCode),
	}
	
	if execResp.ExitCode != 0 {
		resp.Status = "error"
		resp.Error = fmt.Sprintf("command failed with exit code %d", execResp.ExitCode)
	}
	
	return resp, nil
}
