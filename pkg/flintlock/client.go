package flintlock

import (
	"context"
	"fmt"
	"time"

	"github.com/mbhatt/tvm/pkg/apis/vvm/v1alpha1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/anypb"

	flintlockv1 "github.com/liquidmetal-dev/flintlock/api/services/microvm/v1alpha1"
	flintlocktypes "github.com/liquidmetal-dev/flintlock/api/types"
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
	vm.Status.VMID = resp.Microvm.Id
	vm.Status.State = v1alpha1.MicroVMStateRunning

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
	stream, err := c.client.ListMicroVMs(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to list microVMs: %v", err)
	}

	var microvms []*flintlocktypes.MicroVM
	for {
		resp, err := stream.Recv()
		if err != nil {
			break
		}
		microvms = append(microvms, resp.Microvm)
	}

	return microvms, nil
}

// convertToFlintlockSpec converts our MicroVM to a Flintlock MicroVMSpec
func convertToFlintlockSpec(vm *v1alpha1.MicroVM) (*flintlocktypes.MicroVMSpec, error) {
	// This is a simplified conversion and would need to be expanded
	// based on the full Flintlock API
	spec := &flintlocktypes.MicroVMSpec{
		Id: fmt.Sprintf("%s-%s", vm.Namespace, vm.Name),
		Vcpu: &flintlocktypes.VCPUConfig{
			Count: uint32(vm.Spec.CPU),
		},
		MemoryMb: uint32(vm.Spec.Memory),
		RootVolume: &flintlocktypes.Volume{
			Id:         "root",
			IsReadOnly: false,
			Source: &flintlocktypes.VolumeSource{
				Container: &flintlocktypes.ContainerSource{
					Image: vm.Spec.Image,
				},
			},
		},
	}

	return spec, nil
}

// UpdateMicroVMStatus updates the status of a MicroVM based on Flintlock's response
func (c *Client) UpdateMicroVMStatus(vm *v1alpha1.MicroVM) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	resp, err := c.GetMicroVM(ctx, vm.Status.VMID)
	if err != nil {
		return err
	}

	// Update status based on Flintlock's response
	vm.Status.VMID = resp.Microvm.Id

	// Map Flintlock state to our state
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
	}

	return nil
}
