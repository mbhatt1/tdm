package flintlock

import (
	"fmt"
	"io/ioutil"
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
}

// NewServer creates a new flintlock server
func NewServer(baseDir string) (*Server, error) {
	// Create base directory if it doesn't exist
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create base directory: %v", err)
	}

	// Create directories for requests and responses
	microVMsDir := filepath.Join(baseDir, "microvms")
	if err := os.MkdirAll(microVMsDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create microvms directory: %v", err)
	}

	return &Server{
		BaseDir: baseDir,
		stopCh:  make(chan struct{}),
	}, nil
}

// Start starts the flintlock server
func (s *Server) Start() error {
	log.Info("Starting flintlock server...")

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
				_, err := ioutil.ReadFile(requestFile)
				if err != nil {
					log.Errorf("Failed to read request file: %v", err)
					continue
				}

				// Write response
				if err := ioutil.WriteFile(responseFile, []byte("Request processed"), 0644); err != nil {
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
				_, err := ioutil.ReadFile(executeRequestFile)
				if err != nil {
					log.Errorf("Failed to read execute request file: %v", err)
					continue
				}

				// Create response
				response := &ExecutionResponse{
					Status:   "success",
					Output:   "Mock execution output",
					ExitCode: 0,
				}

				// Write response
				responseText := fmt.Sprintf("=== Execution Output ===\n%s\n=== End of Execution ===\nExit code: %d", response.Output, response.ExitCode)
				if err := ioutil.WriteFile(executeResponseFile, []byte(responseText), 0644); err != nil {
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