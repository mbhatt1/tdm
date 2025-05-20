package flintlock

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	log "github.com/sirupsen/logrus"
)

// Server represents the flintlock server
type Server struct {
	// Base directory for flintlock data
	BaseDir string
	// Stop channel
	stopCh chan struct{}
	// Firecracker manager
	fcManager *FirecrackerManager
}

// NewServer creates a new flintlock server
func NewServer(baseDir string) (*Server, error) {
	log.Infof("Creating new flintlock server with base directory: %s", baseDir)
	
	// Check if base directory exists
	if _, err := os.Stat(baseDir); os.IsNotExist(err) {
		log.Warnf("Base directory %s does not exist, attempting to create it", baseDir)
	}
	
	// Create base directory if it doesn't exist
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		log.Errorf("Failed to create base directory %s: %v", baseDir, err)
		return nil, fmt.Errorf("failed to create base directory: %v", err)
	}
	log.Infof("Base directory %s created or already exists", baseDir)

	// Create directories for requests and responses
	microVMsDir := filepath.Join(baseDir, "microvms")
	if err := os.MkdirAll(microVMsDir, 0755); err != nil {
		log.Errorf("Failed to create microvms directory %s: %v", microVMsDir, err)
		return nil, fmt.Errorf("failed to create microvms directory: %v", err)
	}
	log.Infof("MicroVMs directory %s created or already exists", microVMsDir)
	
	// List the contents of the base directory to verify
	files, err := os.ReadDir(baseDir)
	if err != nil {
		log.Warnf("Failed to read base directory contents: %v", err)
	} else {
		log.Infof("Base directory contents: %v", getFileNames(files))
	}

	// Create a Firecracker manager
	fcManager, err := NewFirecrackerManager(
		baseDir,
		filepath.Join(baseDir, "kernel", "vmlinux"),
		filepath.Join(baseDir, "volumes", "rootfs.img"),
	)
	if err != nil {
		log.Errorf("Failed to create Firecracker manager: %v", err)
		return nil, fmt.Errorf("failed to create Firecracker manager: %v", err)
	}
	log.Infof("Firecracker manager created")

	return &Server{
		BaseDir:    baseDir,
		stopCh:     make(chan struct{}),
		fcManager:  fcManager,
	}, nil
}

// getFileNames extracts file names from a slice of DirEntry
func getFileNames(files []os.DirEntry) []string {
	var names []string
	for _, file := range files {
		names = append(names, file.Name())
	}
	return names
}

// Start starts the flintlock server
func (s *Server) Start() error {
	log.Info("Starting flintlock server...")
	
	// Check if the base directory exists and is accessible
	if _, err := os.Stat(s.BaseDir); err != nil {
		log.Errorf("Base directory %s is not accessible: %v", s.BaseDir, err)
		return fmt.Errorf("base directory is not accessible: %v", err)
	}
	
	// Check if the microvms directory exists and is accessible
	microVMsDir := filepath.Join(s.BaseDir, "microvms")
	if _, err := os.Stat(microVMsDir); err != nil {
		log.Errorf("MicroVMs directory %s is not accessible: %v", microVMsDir, err)
		return fmt.Errorf("microvms directory is not accessible: %v", err)
	}
	
	// Try to create a test file to verify write permissions
	testFile := filepath.Join(s.BaseDir, "test_write_permission.txt")
	if err := os.WriteFile(testFile, []byte("test"), 0644); err != nil {
		log.Errorf("Failed to write test file to base directory: %v", err)
		return fmt.Errorf("failed to write to base directory: %v", err)
	}
	// Clean up test file
	os.Remove(testFile)
	
	log.Info("Directory permissions verified, starting request handler...")

	// Start request handlers
	go s.handleRequests()

	return nil
}

// Stop stops the flintlock server
func (s *Server) Stop() error {
	log.Info("Stopping flintlock server...")
	close(s.stopCh)
	return nil
}

// handleRequests handles all requests
func (s *Server) handleRequests() {
	requestFile := filepath.Join(s.BaseDir, "microvms", "requests.txt")
	responseFile := filepath.Join(s.BaseDir, "microvms", "response.txt")
	executeRequestFile := filepath.Join(s.BaseDir, "microvms", "execute_request.txt")
	executeResponseFile := filepath.Join(s.BaseDir, "microvms", "execute_response.txt")

	for {
		select {
		case <-s.stopCh:
			return
		default:
			// Check if there's a request file
			if _, err := os.Stat(requestFile); err == nil {
				log.Info("Processing request...")

				// Read request
				_, err := os.ReadFile(requestFile)
				if err != nil {
					log.Errorf("Failed to read request file: %v", err)
					continue
				}

				// Write response
				if err := os.WriteFile(responseFile, []byte("Request processed"), 0644); err != nil {
					log.Errorf("Failed to write response file: %v", err)
					continue
				}

				// Remove request file
				if err := os.Remove(requestFile); err != nil {
					log.Errorf("Failed to remove request file: %v", err)
				}
			}

			// Check if there's an execute request file
			if _, err := os.Stat(executeRequestFile); err == nil {
				log.Info("Processing execute request...")

				// Read request
				requestContent, err := os.ReadFile(executeRequestFile)
				if err != nil {
					log.Errorf("Failed to read execute request file: %v", err)
					continue
				}

				// Parse the request
				var request ExecutionRequest
				if err := json.Unmarshal(requestContent, &request); err != nil {
					log.Errorf("Failed to parse execute request: %v", err)
					
					// Create error response
					response := &ExecutionResponse{
						Status:   "error",
						Output:   fmt.Sprintf("Failed to parse request: %v", err),
						ExitCode: 1,
						Error:    err.Error(),
					}
					
					// Write response
					responseText := fmt.Sprintf("=== Execution Output ===\n%s\n=== End of Execution ===\nExit code: %d", response.Output, response.ExitCode)
					if err := os.WriteFile(executeResponseFile, []byte(responseText), 0644); err != nil {
						log.Errorf("Failed to write execute response file: %v", err)
					}
					continue
				}

				log.Infof("Executing command in Firecracker VM: %s %v", request.Command, request.Args)
				
				// Create a VM if it doesn't exist
				vmID := "default-vm"
				
				// Execute the command in the VM
				ctx := context.Background()
				response, err := s.fcManager.ExecuteCode(ctx, vmID, &request)
				if err != nil {
					log.Errorf("Failed to execute code in VM: %v", err)
					
					// Create error response
					response = &ExecutionResponse{
						Status:   "error",
						Output:   fmt.Sprintf("Failed to execute code in VM: %v", err),
						ExitCode: 1,
						Error:    err.Error(),
					}
				}

				// Write response
				responseText := fmt.Sprintf("=== Execution Output ===\n%s\n=== End of Execution ===\nExit code: %d", response.Output, response.ExitCode)
				if err := os.WriteFile(executeResponseFile, []byte(responseText), 0644); err != nil {
					log.Errorf("Failed to write execute response file: %v", err)
					continue
				}

				// Remove request file
				if err := os.Remove(executeRequestFile); err != nil {
					log.Errorf("Failed to remove execute request file: %v", err)
				}
			}

			// Sleep for a bit
			time.Sleep(1 * time.Second)
		}
	}
}