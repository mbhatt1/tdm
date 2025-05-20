package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// MicroVM is a specification for a MicroVM resource
type MicroVM struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MicroVMSpec   `json:"spec"`
	Status MicroVMStatus `json:"status,omitempty"`
}

// MicroVMSpec is the spec for a MicroVM resource
type MicroVMSpec struct {
	// Image is the container image for the VM
	Image string `json:"image"`

	// Command is the command to run in the VM
	Command []string `json:"command,omitempty"`

	// CPU is the number of vCPUs
	CPU int32 `json:"cpu,omitempty"`

	// Memory is the amount of memory in MB
	Memory int32 `json:"memory,omitempty"`

	// Snapshot is the name of the snapshot to restore from
	Snapshot string `json:"snapshot,omitempty"`

	// MCPMode enables MCP mode for the VM
	MCPMode bool `json:"mcpMode,omitempty"`

	// PersistentStorage enables persistent storage for the VM
	PersistentStorage bool `json:"persistentStorage,omitempty"`
}

// MicroVMState represents the state of a MicroVM
type MicroVMState string

const (
	// MicroVMStateCreating means the VM is being created
	MicroVMStateCreating MicroVMState = "Creating"

	// MicroVMStateRunning means the VM is running
	MicroVMStateRunning MicroVMState = "Running"

	// MicroVMStateError means the VM is in an error state
	MicroVMStateError MicroVMState = "Error"

	// MicroVMStateDeleted means the VM has been deleted
	MicroVMStateDeleted MicroVMState = "Deleted"
)

// MicroVMStatus is the status for a MicroVM resource
type MicroVMStatus struct {
	// State is the current state of the VM
	State MicroVMState `json:"state,omitempty"`

	// VMID is the unique identifier for the VM
	VMID string `json:"vmId,omitempty"`

	// HostPod is the pod hosting the VM
	HostPod string `json:"hostPod,omitempty"`

	// Node is the node running the VM
	Node string `json:"node,omitempty"`

	// LastActivity is the timestamp of last activity
	LastActivity *metav1.Time `json:"lastActivity,omitempty"`

	// Error message if the VM is in an error state
	Error string `json:"error,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// MicroVMList is a list of MicroVM resources
type MicroVMList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata"`

	Items []MicroVM `json:"items"`
}

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// MCPSession is a specification for a MCPSession resource
type MCPSession struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MCPSessionSpec   `json:"spec"`
	Status MCPSessionStatus `json:"status,omitempty"`
}

// MCPSessionSpec is the spec for a MCPSession resource
type MCPSessionSpec struct {
	// UserID is the user identifier
	UserID string `json:"userId"`

	// GroupID is the group identifier
	GroupID string `json:"groupId,omitempty"`

	// VMID is the associated VM identifier
	VMID string `json:"vmId,omitempty"`

	// SessionType is the type of session
	SessionType string `json:"sessionType,omitempty"`
}

// MCPSessionState represents the state of an MCPSession
type MCPSessionState string

const (
	// MCPSessionStateCreating means the session is being created
	MCPSessionStateCreating MCPSessionState = "Creating"

	// MCPSessionStateRunning means the session is running
	MCPSessionStateRunning MCPSessionState = "Running"

	// MCPSessionStateError means the session is in an error state
	MCPSessionStateError MCPSessionState = "Error"

	// MCPSessionStateDeleted means the session has been deleted
	MCPSessionStateDeleted MCPSessionState = "Deleted"
)

// MCPSessionStatus is the status for a MCPSession resource
type MCPSessionStatus struct {
	// State is the current state of the session
	State MCPSessionState `json:"state,omitempty"`

	// ConnectionInfo is the information for connecting to the session
	ConnectionInfo *ConnectionInfo `json:"connectionInfo,omitempty"`

	// LastActivity is the timestamp of last activity
	LastActivity *metav1.Time `json:"lastActivity,omitempty"`

	// Error message if the session is in an error state
	Error string `json:"error,omitempty"`
}

// ConnectionInfo contains information for connecting to a session
type ConnectionInfo struct {
	// URL is the URL for connecting to the session
	URL string `json:"url,omitempty"`

	// Token is the token for authenticating to the session
	Token string `json:"token,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// MCPSessionList is a list of MCPSession resources
type MCPSessionList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata"`

	Items []MCPSession `json:"items"`
}
