package main

import (
	"flag"
	"os"
	"os/signal"
	"syscall"

	"github.com/mbhatt/tvm/pkg/deviceplugin"
	log "github.com/sirupsen/logrus"
)

func main() {
	// Parse flags
	flag.Parse()

	// Set up logging
	log.SetFormatter(&log.TextFormatter{
		FullTimestamp: true,
	})
	log.SetOutput(os.Stdout)
	log.SetLevel(log.InfoLevel)

	log.Info("Starting KVM device plugin")

	// Create the device plugin
	plugin := deviceplugin.NewKVMDevicePlugin()

	// Start the device plugin
	if err := plugin.Start(); err != nil {
		log.Fatalf("Failed to start device plugin: %v", err)
	}
	log.Info("KVM device plugin started")

	// Set up signal handling
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	// Stop the device plugin
	plugin.Stop()
	log.Info("KVM device plugin stopped")
}
