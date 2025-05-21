package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/mbhatt/tvm/pkg/flintlock"
	log "github.com/sirupsen/logrus"
)

func main() {
	// Parse command line flags
	baseDir := flag.String("base-dir", "/var/lib/flintlock", "Base directory for flintlock data")
	port := flag.Int("port", 9090, "Port for the gRPC server")
	flag.Parse()

	// Configure logging
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp: true,
	})
	log.SetOutput(os.Stdout)
	log.SetLevel(log.InfoLevel)

	// Log startup information
	log.Info("Starting Flintlock server...")
	log.Infof("Base directory: %s", *baseDir)
	log.Infof("gRPC port: %d", *port)

	// Create flintlock server
	server, err := flintlock.NewServer(*baseDir)
	if err != nil {
		log.Fatalf("Failed to create flintlock server: %v", err)
	}

	// Start server
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start flintlock server: %v", err)
	}

	log.Info("Flintlock server started successfully")
	fmt.Printf("Flintlock gRPC server is running on port %d\n", *port)
	fmt.Println("Press Ctrl+C to stop the server")

	// Wait for signal to exit
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	log.Info("Received shutdown signal, stopping server...")

	// Stop server
	if err := server.Stop(); err != nil {
		log.Fatalf("Failed to stop flintlock server: %v", err)
	}

	log.Info("Flintlock server stopped successfully")
}