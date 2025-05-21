package flintlock

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
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
	
	// Check if Firecracker is available
	_, err := exec.LookPath("firecracker")
	if err != nil {
		return nil, fmt.Errorf("firecracker command not found: %v", err)
	}
	
	return &FirecrackerManager{
		BaseDir:         baseDir,
		KernelImagePath: kernelImagePath,
		RootfsImagePath: rootfsImagePath,
		vms:             make(map[string]interface{}),
	}, nil
}

// CreateVM creates a new Firecracker VM
func (m *FirecrackerManager) CreateVM(ctx context.Context, config VMConfig) (string, error) {
	// Create a real VM using Firecracker
	vmID := fmt.Sprintf("vm-%d", time.Now().Unix())
	
	// Create VM directory
	vmDir := filepath.Join(m.BaseDir, "vms", vmID)
	if err := os.MkdirAll(vmDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create VM directory: %v", err)
	}
	
	// Create VM configuration file
	configFile := filepath.Join(vmDir, "config.json")
	configData := fmt.Sprintf(`{
		"boot-source": {
			"kernel_image_path": "%s",
			"boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
		},
		"drives": [
			{
				"drive_id": "rootfs",
				"path_on_host": "%s",
				"is_root_device": true,
				"is_read_only": false
			}
		],
		"machine-config": {
			"vcpu_count": %d,
			"mem_size_mib": %d,
			"ht_enabled": false
		}
	}`, m.KernelImagePath, m.RootfsImagePath, config.VCPU, config.Memory)
	
	if err := os.WriteFile(configFile, []byte(configData), 0644); err != nil {
		return "", fmt.Errorf("failed to write VM config: %v", err)
	}
	
	// Store VM in map
	m.vms[vmID] = struct{}{}
	
	return vmID, nil
}

// StopVM stops a Firecracker VM
func (m *FirecrackerManager) StopVM(ctx context.Context, vmID string) error {
	// Check if VM exists
	if _, ok := m.vms[vmID]; !ok {
		return fmt.Errorf("VM %s does not exist", vmID)
	}
	
	// Get VM directory
	vmDir := filepath.Join(m.BaseDir, "vms", vmID)
	
	// Check if VM is running
	pidFile := filepath.Join(vmDir, "firecracker.pid")
	if _, err := os.Stat(pidFile); err == nil {
		// Read PID
		pidData, err := os.ReadFile(pidFile)
		if err != nil {
			return fmt.Errorf("failed to read PID file: %v", err)
		}
		
		// Parse PID
		pid, err := strconv.Atoi(string(pidData))
		if err != nil {
			return fmt.Errorf("failed to parse PID: %v", err)
		}
		
		// Kill process
		process, err := os.FindProcess(pid)
		if err != nil {
			return fmt.Errorf("failed to find process: %v", err)
		}
		
		if err := process.Kill(); err != nil {
			return fmt.Errorf("failed to kill process: %v", err)
		}
		
		// Remove PID file
		if err := os.Remove(pidFile); err != nil {
			return fmt.Errorf("failed to remove PID file: %v", err)
		}
	}
	
	// Remove VM from map
	delete(m.vms, vmID)
	
	return nil
}

// DeleteVM deletes a Firecracker VM
func (m *FirecrackerManager) DeleteVM(ctx context.Context, vmID string) error {
	// Stop VM if it's running
	if err := m.StopVM(ctx, vmID); err != nil {
		return fmt.Errorf("failed to stop VM: %v", err)
	}
	
	// Delete VM directory
	vmDir := filepath.Join(m.BaseDir, "vms", vmID)
	if err := os.RemoveAll(vmDir); err != nil {
		return fmt.Errorf("failed to delete VM directory: %v", err)
	}
	
	// Remove VM from map
	delete(m.vms, vmID)
	
	return nil
}

// ExecuteCode executes code in a Firecracker VM
func (m *FirecrackerManager) ExecuteCode(ctx context.Context, vmID string, req *ExecutionRequest) (*ExecutionResponse, error) {
	fmt.Printf("ExecuteCode called with vmID=%s, req=%+v\n", vmID, req)
	
	// Check if VM exists, create it if it doesn't
	if _, ok := m.vms[vmID]; !ok {
		fmt.Printf("VM %s does not exist, creating it\n", vmID)
		
		// Create VM directory
		vmDir := filepath.Join(m.BaseDir, "vms", vmID)
		if err := os.MkdirAll(vmDir, 0755); err != nil {
			fmt.Printf("Failed to create VM directory: %v\n", err)
			return nil, fmt.Errorf("failed to create VM directory: %v", err)
		}
		
		// Create VM configuration file
		configFile := filepath.Join(vmDir, "config.json")
		configData := fmt.Sprintf(`{
			"boot-source": {
				"kernel_image_path": "%s",
				"boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
			},
			"drives": [
				{
					"drive_id": "rootfs",
					"path_on_host": "%s",
					"is_root_device": true,
					"is_read_only": false
				}
			],
			"machine-config": {
				"vcpu_count": %d,
				"mem_size_mib": %d,
				"ht_enabled": false
			}
		}`, m.KernelImagePath, m.RootfsImagePath, 1, 512)
		
		if err := os.WriteFile(configFile, []byte(configData), 0644); err != nil {
			fmt.Printf("Failed to write VM config: %v\n", err)
			return nil, fmt.Errorf("failed to write VM config: %v", err)
		}
		
		// Store VM in map
		m.vms[vmID] = struct{}{}
		fmt.Printf("VM %s created successfully\n", vmID)
	}
	
	// Get VM directory
	vmDir := filepath.Join(m.BaseDir, "vms", vmID)
	
	// Create a temporary script file
	scriptFile, err := createTempScript(req)
	if err != nil {
		return nil, fmt.Errorf("failed to create temporary script: %v", err)
	}
	defer os.Remove(scriptFile)
	
	// Copy script to VM directory
	vmScriptFile := filepath.Join(vmDir, "script.sh")
	scriptData, err := os.ReadFile(scriptFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read script file: %v", err)
	}
	
	if err := os.WriteFile(vmScriptFile, scriptData, 0755); err != nil {
		return nil, fmt.Errorf("failed to write VM script file: %v", err)
	}
	
	// Start VM if it's not running
	socketFile := filepath.Join(vmDir, "firecracker.socket")
	pidFile := filepath.Join(vmDir, "firecracker.pid")
	configFile := filepath.Join(vmDir, "config.json")
	logFile := filepath.Join(vmDir, "firecracker.log")
	
	if _, err := os.Stat(socketFile); os.IsNotExist(err) {
		// Start Firecracker
		cmd := exec.Command("firecracker", "--api-sock", socketFile, "--config-file", configFile)
		cmd.Stdout, _ = os.Create(logFile)
		cmd.Stderr = cmd.Stdout
		
		if err := cmd.Start(); err != nil {
			return nil, fmt.Errorf("failed to start Firecracker: %v", err)
		}
		
		// Save PID
		if err := os.WriteFile(pidFile, []byte(fmt.Sprintf("%d", cmd.Process.Pid)), 0644); err != nil {
			return nil, fmt.Errorf("failed to write PID file: %v", err)
		}
		
		// Wait for socket to be created
		for i := 0; i < 10; i++ {
			if _, err := os.Stat(socketFile); err == nil {
				break
			}
			time.Sleep(time.Second)
		}
		
		if _, err := os.Stat(socketFile); os.IsNotExist(err) {
			return nil, fmt.Errorf("failed to start VM: socket file not created")
		}
	}
	
	// Execute script in VM using Firecracker
	fmt.Printf("Executing command in Firecracker VM: %s %v\n", req.Command, req.Args)
	
	// Create a temporary file for the script
	scriptPath, err := createTempScript(req)
	if err != nil {
		fmt.Printf("Failed to create temporary script: %v\n", err)
		return nil, fmt.Errorf("failed to create temporary script: %v", err)
	}
	defer os.Remove(scriptPath)
	
	// Ensure VM is running
	vmSocketPath := filepath.Join(vmDir, "firecracker.socket")
	if _, err := os.Stat(vmSocketPath); os.IsNotExist(err) {
		// VM is not running, start it
		fmt.Printf("Starting Firecracker VM...\n")
		if err := startFirecrackerVM(vmDir, m.KernelImagePath, m.RootfsImagePath); err != nil {
			return nil, fmt.Errorf("failed to start Firecracker VM: %v", err)
		}
	}
	
	// Copy script to VM
	vmScriptPath := filepath.Join(vmDir, "script.sh")
	if err := copyFileToVM(scriptPath, vmScriptPath); err != nil {
		return nil, fmt.Errorf("failed to copy script to VM: %v", err)
	}
	
	// Execute script in VM using SSH
	sshCmd := fmt.Sprintf("ssh -i %s/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 '%s %s'",
		vmDir, req.Command, "/tmp/script.sh")
	
	cmd := exec.Command("sh", "-c", sshCmd)
	
	// Set environment variables
	if req.Env != nil {
		envVars := ""
		for k, v := range req.Env {
			envVars += fmt.Sprintf("export %s=%s; ", k, v)
		}
		sshCmd = fmt.Sprintf("ssh -i %s/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 '%s %s %s'",
			vmDir, envVars, req.Command, "/tmp/script.sh")
		cmd = exec.Command("sh", "-c", sshCmd)
	}
	
	// Capture output
	fmt.Printf("Executing command in VM: %s\n", sshCmd)
	
	// Execute the command
	output, err := cmd.CombinedOutput()
	fmt.Printf("VM execution output: %s\n", string(output))
	
	// Format output for the response file
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = 1
		}
	}
	
	formattedOutput := fmt.Sprintf("=== Firecracker VM Execution Output ===\n%s\n=== End of Firecracker VM Execution ===\nExit code: %d",
		string(output),
		exitCode)
	
	// Save output to file
	if err := os.WriteFile(filepath.Join(m.BaseDir, "microvms", "execute_response.txt"), []byte(formattedOutput), 0644); err != nil {
		return nil, fmt.Errorf("failed to write output file: %v", err)
	}
	
	// Create response
	response := &ExecutionResponse{
		Status:   "success",
		Output:   string(output),
		ExitCode: exitCode,
	}
	
	if err != nil {
		response.Status = "error"
		response.Error = err.Error()
	}
	
	return response, nil
	
	// Execute the command
	output, err := cmd.CombinedOutput()
	fmt.Printf("VM execution output: %s\n", string(output))
	
	// Format output for the response file
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = 1
		}
	}
	
	formattedOutput := fmt.Sprintf("=== Firecracker VM Execution Output ===\n%s\n=== End of Firecracker VM Execution ===\nExit code: %d",
		string(output),
		exitCode)
	
	// Save output to file
	if err := os.WriteFile(filepath.Join(m.BaseDir, "microvms", "execute_response.txt"), []byte(formattedOutput), 0644); err != nil {
		return nil, fmt.Errorf("failed to write output file: %v", err)
	}
	
	// Create response
	response := &ExecutionResponse{
		Status:   "success",
		Output:   string(output),
		ExitCode: exitCode,
	}
	
	if err != nil {
		response.Status = "error"
		response.Error = err.Error()
	}
	
	return response, nil
}

// createTempScript creates a temporary script file from the execution request
func createTempScript(req *ExecutionRequest) (string, error) {
	// Create a temporary file
	tmpfile, err := os.CreateTemp("", "script-*.sh")
	if err != nil {
		return "", fmt.Errorf("failed to create temporary file: %v", err)
	}
	defer tmpfile.Close()

	// Check if we need to read the script from a file
	var scriptContent string
	if len(req.Args) > 0 && req.Args[0] != "" {
		// Try to read the script from the file
		scriptPath := req.Args[0]
		// If the path starts with /var/lib/flintlock, replace it with the base directory
		if len(scriptPath) > 16 && scriptPath[:16] == "/var/lib/flintlock" {
			scriptPath = filepath.Join("/tmp/flintlock-data", scriptPath[16:])
		}
		
		// Read the script file
		scriptBytes, err := os.ReadFile(scriptPath)
		if err != nil {
			return "", fmt.Errorf("failed to read script file %s: %v", scriptPath, err)
		}
		
		// Use the script content
		scriptContent = string(scriptBytes)
	} else {
		// Create a default script with proper shebang
		scriptContent = "#!/bin/sh\n\n"
		
		// Add environment variables
		if req.Env != nil {
			scriptContent += "# Environment variables\n"
			for k, v := range req.Env {
				scriptContent += fmt.Sprintf("export %s=\"%s\"\n", k, v)
			}
			scriptContent += "\n"
		}
		
		// Add the main script content
		scriptContent += "# Main script\n"
		scriptContent += "echo \"=== Firecracker VM Execution ===\"\n"
		scriptContent += "echo \"Running in Firecracker VM\"\n"
		scriptContent += fmt.Sprintf("echo \"Command: %s\"\n", req.Command)
		scriptContent += fmt.Sprintf("echo \"Args: %v\"\n", req.Args)
		scriptContent += "echo \"Hostname: $(hostname)\"\n"
		scriptContent += "echo \"Kernel: $(uname -r)\"\n"
		scriptContent += "echo \"Date: $(date)\"\n"
		
		// Add command execution if provided
		if req.Command != "" {
			scriptContent += fmt.Sprintf("\n# Execute command\n%s", req.Command)
			if len(req.Args) > 0 {
				for _, arg := range req.Args {
					scriptContent += fmt.Sprintf(" \"%s\"", arg)
				}
			}
			scriptContent += "\n"
		}
	}
	
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

// startFirecrackerVM starts a Firecracker VM
func startFirecrackerVM(vmDir, kernelImagePath, rootfsImagePath string) error {
	// Create VM configuration file
	configFile := filepath.Join(vmDir, "config.json")
	configData := fmt.Sprintf(`{
		"boot-source": {
			"kernel_image_path": "%s",
			"boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
		},
		"drives": [
			{
				"drive_id": "rootfs",
				"path_on_host": "%s",
				"is_root_device": true,
				"is_read_only": false
			}
		],
		"machine-config": {
			"vcpu_count": 1,
			"mem_size_mib": 512,
			"ht_enabled": false
		},
		"network-interfaces": [
			{
				"iface_id": "eth0",
				"guest_mac": "AA:FC:00:00:00:01",
				"host_dev_name": "tap0"
			}
		]
	}`, kernelImagePath, rootfsImagePath)
	
	if err := os.WriteFile(configFile, []byte(configData), 0644); err != nil {
		return fmt.Errorf("failed to write VM config: %v", err)
	}
	
	// Create socket file path
	socketFile := filepath.Join(vmDir, "firecracker.socket")
	pidFile := filepath.Join(vmDir, "firecracker.pid")
	logFile := filepath.Join(vmDir, "firecracker.log")
	
	// Start Firecracker
	cmd := exec.Command("firecracker", "--api-sock", socketFile, "--config-file", configFile)
	cmd.Stdout, _ = os.Create(logFile)
	cmd.Stderr = cmd.Stdout
	
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start Firecracker: %v", err)
	}
	
	// Save PID
	if err := os.WriteFile(pidFile, []byte(fmt.Sprintf("%d", cmd.Process.Pid)), 0644); err != nil {
		return fmt.Errorf("failed to write PID file: %v", err)
	}
	
	// Wait for socket to be created
	for i := 0; i < 10; i++ {
		if _, err := os.Stat(socketFile); err == nil {
			break
		}
		time.Sleep(time.Second)
	}
	
	if _, err := os.Stat(socketFile); os.IsNotExist(err) {
		return fmt.Errorf("failed to start VM: socket file not created")
	}
	
	// Wait for VM to boot
	time.Sleep(5 * time.Second)
	
	return nil
}

// copyFileToVM copies a file to the VM
func copyFileToVM(srcPath, dstPath string) error {
	// Read source file
	data, err := os.ReadFile(srcPath)
	if err != nil {
		return fmt.Errorf("failed to read source file: %v", err)
	}
	
	// Write to destination file
	if err := os.WriteFile(dstPath, data, 0755); err != nil {
		return fmt.Errorf("failed to write destination file: %v", err)
	}
	
	// Use SCP to copy the file to the VM
	scpCmd := exec.Command("scp", "-i", filepath.Join(filepath.Dir(dstPath), "id_rsa"),
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-P", "2222",
		dstPath,
		fmt.Sprintf("root@localhost:/tmp/script.sh"))
	
	if err := scpCmd.Run(); err != nil {
		return fmt.Errorf("failed to copy file to VM using SCP: %v", err)
	}
	
	return nil
}