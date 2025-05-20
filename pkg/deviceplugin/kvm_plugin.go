package deviceplugin

import (
	"context"
	"fmt"
	"net"
	"os"
	"path"
	"time"

	"github.com/fsnotify/fsnotify"
	"google.golang.org/grpc"
	"k8s.io/klog/v2"
	pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

const (
	// KVMDevicePath is the path to the KVM device
	KVMDevicePath = "/dev/kvm"

	// SocketPath is the path to the device plugin socket
	SocketPath = pluginapi.DevicePluginPath + "kvm.sock"

	// ResourceName is the name of the resource
	ResourceName = "kvm.tvm.github.com/kvm"
)

// KVMDevicePlugin implements the Kubernetes device plugin API
type KVMDevicePlugin struct {
	socket string
	server *grpc.Server
	stop   chan struct{}
}

// NewKVMDevicePlugin creates a new KVM device plugin
func NewKVMDevicePlugin() *KVMDevicePlugin {
	return &KVMDevicePlugin{
		socket: SocketPath,
		stop:   make(chan struct{}),
	}
}

// Start starts the device plugin
func (p *KVMDevicePlugin) Start() error {
	// Check if the KVM device exists
	if _, err := os.Stat(KVMDevicePath); err != nil {
		return fmt.Errorf("KVM device not found: %v", err)
	}

	// Remove the socket if it already exists
	if err := os.Remove(p.socket); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove socket: %v", err)
	}

	// Create the socket
	sock, err := net.Listen("unix", p.socket)
	if err != nil {
		return fmt.Errorf("failed to listen on socket: %v", err)
	}

	// Create the gRPC server
	p.server = grpc.NewServer()
	pluginapi.RegisterDevicePluginServer(p.server, p)

	// Start the gRPC server
	go func() {
		if err := p.server.Serve(sock); err != nil {
			klog.Errorf("Failed to serve: %v", err)
		}
	}()

	// Wait for the server to start
	conn, err := grpc.Dial(p.socket, grpc.WithInsecure(), grpc.WithBlock(),
		grpc.WithTimeout(5*time.Second),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", addr, timeout)
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to socket: %v", err)
	}
	conn.Close()

	// Register with kubelet
	err = p.register()
	if err != nil {
		return fmt.Errorf("failed to register with kubelet: %v", err)
	}

	// Watch for kubelet restarts
	go p.watchKubelet()

	return nil
}

// Stop stops the device plugin
func (p *KVMDevicePlugin) Stop() {
	close(p.stop)
	if p.server != nil {
		p.server.Stop()
	}
}

// register registers the device plugin with kubelet
func (p *KVMDevicePlugin) register() error {
	conn, err := grpc.Dial(pluginapi.KubeletSocket, grpc.WithInsecure(), grpc.WithBlock(),
		grpc.WithTimeout(5*time.Second),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", addr, timeout)
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to kubelet: %v", err)
	}
	defer conn.Close()

	client := pluginapi.NewRegistrationClient(conn)
	req := &pluginapi.RegisterRequest{
		Version:      pluginapi.Version,
		Endpoint:     path.Base(p.socket),
		ResourceName: ResourceName,
	}

	_, err = client.Register(context.Background(), req)
	if err != nil {
		return fmt.Errorf("failed to register with kubelet: %v", err)
	}

	return nil
}

// watchKubelet watches for kubelet restarts and re-registers
func (p *KVMDevicePlugin) watchKubelet() {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		klog.Errorf("Failed to create watcher: %v", err)
		return
	}
	defer watcher.Close()

	err = watcher.Add(pluginapi.KubeletSocket)
	if err != nil {
		klog.Errorf("Failed to watch kubelet socket: %v", err)
		return
	}

	for {
		select {
		case <-p.stop:
			return
		case event := <-watcher.Events:
			if event.Op&fsnotify.Create == fsnotify.Create {
				// Kubelet restarted, re-register
				time.Sleep(5 * time.Second)
				if err := p.register(); err != nil {
					klog.Errorf("Failed to re-register with kubelet: %v", err)
				}
			}
		case err := <-watcher.Errors:
			klog.Errorf("Watcher error: %v", err)
		}
	}
}

// GetDevicePluginOptions returns the device plugin options
func (p *KVMDevicePlugin) GetDevicePluginOptions(ctx context.Context, empty *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
	return &pluginapi.DevicePluginOptions{}, nil
}

// ListAndWatch lists devices and watches for changes
func (p *KVMDevicePlugin) ListAndWatch(empty *pluginapi.Empty, stream pluginapi.DevicePlugin_ListAndWatchServer) error {
	// Check if the KVM device exists
	if _, err := os.Stat(KVMDevicePath); err != nil {
		return fmt.Errorf("KVM device not found: %v", err)
	}

	// Create a device
	device := &pluginapi.Device{
		ID:     "kvm",
		Health: pluginapi.Healthy,
	}

	// Send the device
	if err := stream.Send(&pluginapi.ListAndWatchResponse{Devices: []*pluginapi.Device{device}}); err != nil {
		return fmt.Errorf("failed to send device: %v", err)
	}

	// Watch for changes
	for {
		select {
		case <-p.stop:
			return nil
		case <-time.After(30 * time.Second):
			// Check if the KVM device still exists
			if _, err := os.Stat(KVMDevicePath); err != nil {
				device.Health = pluginapi.Unhealthy
			} else {
				device.Health = pluginapi.Healthy
			}

			// Send the updated device
			if err := stream.Send(&pluginapi.ListAndWatchResponse{Devices: []*pluginapi.Device{device}}); err != nil {
				return fmt.Errorf("failed to send device: %v", err)
			}
		}
	}
}

// Allocate allocates a device
func (p *KVMDevicePlugin) Allocate(ctx context.Context, req *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
	response := &pluginapi.AllocateResponse{
		ContainerResponses: make([]*pluginapi.ContainerAllocateResponse, len(req.ContainerRequests)),
	}

	for i := range req.ContainerRequests {
		// Check if the KVM device exists
		if _, err := os.Stat(KVMDevicePath); err != nil {
			return nil, fmt.Errorf("KVM device not found: %v", err)
		}

		// Create a container response
		response.ContainerResponses[i] = &pluginapi.ContainerAllocateResponse{
			Devices: []*pluginapi.DeviceSpec{
				{
					HostPath:      KVMDevicePath,
					ContainerPath: KVMDevicePath,
					Permissions:   "rw",
				},
			},
		}
	}

	return response, nil
}

// PreStartContainer is called before starting a container
func (p *KVMDevicePlugin) PreStartContainer(ctx context.Context, req *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
	return &pluginapi.PreStartContainerResponse{}, nil
}

// GetPreferredAllocation returns the preferred allocation
func (p *KVMDevicePlugin) GetPreferredAllocation(ctx context.Context, req *pluginapi.PreferredAllocationRequest) (*pluginapi.PreferredAllocationResponse, error) {
	return &pluginapi.PreferredAllocationResponse{}, nil
}
