package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	fmt.Println("Starting kvm-device-plugin...")
	
	// Create a channel to handle device discovery
	go discoverDevices()
	
	// Keep the main goroutine alive
	for {
		fmt.Println("KVM device plugin running...")
		time.Sleep(60 * time.Second)
	}
}

func discoverDevices() {
	fmt.Println("Starting device discovery...")
	
	// Simulate device discovery
	for {
		// Check for KVM devices
		fmt.Println("Checking for KVM devices...")
		
		// Check if /dev/kvm exists
		if _, err := os.Stat("/dev/kvm"); os.IsNotExist(err) {
			fmt.Println("KVM device not found")
		} else {
			fmt.Println("KVM device found")
			
			// Write to a status file
			writeToFile("/var/lib/flintlock/kvm_status.txt", "KVM device available")
		}
		
		// Sleep for a while
		time.Sleep(30 * time.Second)
	}
}

func writeToFile(filename, content string) {
	// Create the directory if it doesn't exist
	dir := "/var/lib/flintlock"
	os.MkdirAll(dir, 0755)
	
	// Write the content to the file
	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("Error creating file %s: %v\n", filename, err)
		return
	}
	defer file.Close()
	
	_, err = file.WriteString(content)
	if err != nil {
		fmt.Printf("Error writing to file %s: %v\n", filename, err)
		return
	}
	
	fmt.Printf("Successfully wrote to file %s\n", filename)
}
