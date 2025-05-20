package main

import (
	"flag"
	"os"
	"os/signal"
	"syscall"

	"github.com/yourusername/tvm/pkg/flintlock"
	log "github.com/sirupsen/logrus"
)

func main() {
	// Parse command line flags
	baseDir := flag.String("base-dir", "/var/lib/flintlock", "Base directory for flintlock data")
	flag.Parse()

	// Configure logging
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp: true,
	})
	log.SetOutput(os.Stdout)
	log.SetLevel(log.InfoLevel)

	// Create flintlock server
	server, err := flintlock.NewServer(*baseDir)
	if err != nil {
		log.Fatalf("Failed to create flintlock server: %v", err)
	}

	// Start server
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start flintlock server: %v", err)
	}

	// Wait for signal to exit
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	// Stop server
	if err := server.Stop(); err != nil {
		log.Fatalf("Failed to stop flintlock server: %v", err)
	}
}