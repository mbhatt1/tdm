package flintlock

// ExecutionRequest represents a request to execute code in a VM
type ExecutionRequest struct {
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
	Timeout int               `json:"timeout"`
}

// ExecutionResponse represents the response from executing code in a VM
type ExecutionResponse struct {
	Status   string `json:"status"`
	Output   string `json:"output"`
	ExitCode int    `json:"exitCode"`
	Error    string `json:"error,omitempty"`
}