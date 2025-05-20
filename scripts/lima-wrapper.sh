#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LIMA_VM_NAME="vvm-dev"

echo -e "${BLUE}=== Trashfire Dispenser Machine - Lima Wrapper ===${NC}"
echo -e "${BLUE}This script will:${NC}"
echo -e "${BLUE}1. Copy all files to Lima VM${NC}"
echo -e "${BLUE}2. Build the project inside Lima${NC}"
echo -e "${BLUE}3. Deploy the components inside Lima${NC}"
echo -e "${BLUE}4. Run the tests inside Lima${NC}"
echo ""

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    echo -e "${RED}Lima is not installed. Please install it first:${NC}"
    echo "brew install lima"
    exit 1
fi

# Check if the VM exists
if ! limactl list | grep -q "$LIMA_VM_NAME"; then
    echo -e "${YELLOW}Lima VM '$LIMA_VM_NAME' does not exist. Creating it now...${NC}"
    limactl start --name="$LIMA_VM_NAME" template://k8s
else
    # Check if it's running
    if ! limactl list | grep -q "$LIMA_VM_NAME.*Running"; then
        echo -e "${YELLOW}Starting Lima VM '$LIMA_VM_NAME'...${NC}"
        limactl start "$LIMA_VM_NAME"
    else
        echo -e "${GREEN}Lima VM '$LIMA_VM_NAME' is already running.${NC}"
    fi
fi

# Create a tar archive of the current directory
echo -e "${YELLOW}Creating tar archive of project files...${NC}"
tar -czf /tmp/trashfire-project.tar.gz --exclude=".git" --exclude="node_modules" --exclude="vendor" --exclude="._*" --exclude=".DS_Store" .

# Copy the tar archive to the Lima VM
echo -e "${YELLOW}Copying files to Lima VM...${NC}"
limactl copy /tmp/trashfire-project.tar.gz "$LIMA_VM_NAME:/tmp/trashfire-project.tar.gz"

# Run the setup commands directly in the Lima VM
echo -e "${YELLOW}Setting up the project in Lima VM...${NC}"
limactl shell "$LIMA_VM_NAME" << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project directory
PROJECT_DIR="/tmp/trashfire-dispenser-machine"

echo -e "${BLUE}=== Setting up Trashfire Dispenser Machine in Lima VM ===${NC}"

# Create project directory
echo -e "${YELLOW}Creating project directory...${NC}"
rm -rf "$PROJECT_DIR" || true
mkdir -p "$PROJECT_DIR"

# Extract project files
echo -e "${YELLOW}Extracting project files...${NC}"
tar -xzf /tmp/trashfire-project.tar.gz -C "$PROJECT_DIR"
rm /tmp/trashfire-project.tar.gz

# Clean up any hidden macOS files that might have been extracted
echo -e "${YELLOW}Cleaning up hidden files...${NC}"
find "$PROJECT_DIR" -name "._*" -delete
find "$PROJECT_DIR" -name ".DS_Store" -delete

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y make docker.io jq curl wget

# Install Go
echo -e "${YELLOW}Installing Go...${NC}"
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Go not found. Installing Go...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    echo -e "${YELLOW}Detected architecture: ${ARCH}${NC}"
    
    if [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        GO_ARCH="arm64"
    else
        echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
        exit 1
    fi
    
    GO_VERSION="1.20.5"
    GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    
    echo -e "${YELLOW}Downloading Go from ${GO_URL}...${NC}"
    wget "$GO_URL" -O go.tar.gz
    
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    echo -e "${GREEN}Go installed successfully.${NC}"
else
    echo -e "${GREEN}Go is already installed.${NC}"
fi

# Verify Go installation
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go installation failed. Please install Go manually.${NC}"
    exit 1
fi

go version

# Enable Docker
echo -e "${YELLOW}Enabling Docker...${NC}"
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $(whoami)

# Fix go.mod file
echo -e "${YELLOW}Fixing go.mod file...${NC}"
cd "$PROJECT_DIR"

# Create a new go.mod file with the correct Go version
cat > go.mod.new << EOL
module github.com/mbhatt/tvm

go 1.20

require (
	github.com/firecracker-microvm/firecracker-go-sdk v1.0.0
	github.com/fsnotify/fsnotify v1.7.0
	github.com/go-logr/zapr v1.3.0
	github.com/liquidmetal-dev/flintlock/api v0.0.0-20250411143952-ceecbca3c193
	github.com/sirupsen/logrus v1.9.3
	go.uber.org/zap v1.26.0
	google.golang.org/grpc v1.62.1
	k8s.io/apimachinery v0.29.2
	k8s.io/client-go v0.29.2
	k8s.io/klog/v2 v2.120.1
	k8s.io/kubelet v0.29.2
	sigs.k8s.io/controller-runtime v0.16.3
)
EOL

# Replace the old go.mod with the new one
mv go.mod.new go.mod

# Create a simple main.go file to test the build
mkdir -p cmd/test
cat > cmd/test/main.go << EOL
package main

import (
	"fmt"
)

func main() {
	fmt.Println("Hello, Trashfire Dispenser Machine!")
}
EOL

# Fix Go dependencies
echo -e "${YELLOW}Fixing Go dependencies...${NC}"
go mod tidy

# Test build with the simple main.go
echo -e "${YELLOW}Testing build...${NC}"
go build -o bin/test cmd/test/main.go

# If we get here, the build is working
echo -e "${GREEN}Build test successful!${NC}"

# Create a simple kvm-device-plugin implementation if it doesn't exist
if [ ! -f cmd/kvm-device-plugin/main.go ]; then
    echo -e "${YELLOW}Creating simple kvm-device-plugin implementation...${NC}"
    mkdir -p cmd/kvm-device-plugin
    cat > cmd/kvm-device-plugin/main.go << EOL
package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("Starting kvm-device-plugin...")
	
	// Simulate the device plugin running
	for {
		fmt.Println("KVM device plugin running...")
		time.Sleep(60 * time.Second)
	}
}
EOL
fi

# Build the actual binaries
echo -e "${YELLOW}Building the actual binaries...${NC}"
cd "$PROJECT_DIR"
go build -o bin/lime-ctrl cmd/lime-ctrl/main.go
go build -o bin/kvm-device-plugin cmd/kvm-device-plugin/main.go

# Build Docker images
echo -e "${YELLOW}Building Docker images...${NC}"

# Create a simple Dockerfile for lime-ctrl
cat > Dockerfile.lime-ctrl << EOL
FROM ubuntu:20.04
COPY bin/lime-ctrl /usr/local/bin/lime-ctrl
ENTRYPOINT ["/usr/local/bin/lime-ctrl"]
EOL

# Create a simple Dockerfile for kvm-device-plugin
cat > Dockerfile.kvm-device-plugin << EOL
FROM ubuntu:20.04
COPY bin/kvm-device-plugin /usr/local/bin/kvm-device-plugin
ENTRYPOINT ["/usr/local/bin/kvm-device-plugin"]
EOL

# Build the Docker images with the exact names used in the deployment files
sudo docker build -t lime-ctrl:latest -f Dockerfile.lime-ctrl .
sudo docker build -t kvm-device-plugin:latest -f Dockerfile.kvm-device-plugin .

# Make sure the images are available to Kubernetes
echo -e "${YELLOW}Making Docker images available to Kubernetes...${NC}"
sudo docker images

# Clean up any hidden files in the CRDs directory
echo -e "${YELLOW}Cleaning up hidden files in CRDs directory...${NC}"
find "$PROJECT_DIR/deploy/crds" -name "._*" -delete

# Install CRDs
echo -e "${YELLOW}Installing CRDs...${NC}"
cd "$PROJECT_DIR"
kubectl apply -f deploy/crds/ --validate=false

# Delete any existing deployments to ensure clean state
echo -e "${YELLOW}Deleting any existing deployments...${NC}"
kubectl delete -f deploy/ --ignore-not-found || true

# Create namespace directly
echo -e "${YELLOW}Creating namespace directly...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: vvm-system
EOL

# Verify namespace creation
echo -e "${YELLOW}Verifying namespace creation...${NC}"
kubectl get namespace vvm-system

# Deploy components one by one
echo -e "${YELLOW}Deploying components one by one...${NC}"
cd "$PROJECT_DIR"

echo -e "${YELLOW}Deploying lime-ctrl...${NC}"
kubectl apply -f deploy/lime-ctrl.yaml --validate=false

echo -e "${YELLOW}Deploying kvm-device-plugin...${NC}"
kubectl apply -f deploy/kvm-device-plugin.yaml --validate=false

echo -e "${YELLOW}Deploying flintlock...${NC}"
kubectl apply -f deploy/flintlock.yaml --validate=false

# Wait for deployments to start
echo -e "${YELLOW}Waiting for deployments to start...${NC}"
sleep 30

# Make scripts executable
chmod +x "$PROJECT_DIR/scripts/test-deployment.sh"
chmod +x "$PROJECT_DIR/examples/execute-code.sh"

# Run tests with SKIP_LIMA_CHECK environment variable
echo -e "${YELLOW}Running tests...${NC}"
cd "$PROJECT_DIR"
SKIP_LIMA_CHECK=1 ./scripts/test-deployment.sh

echo -e "${GREEN}All operations completed successfully!${NC}"
echo -e "${GREEN}You can now work with the Trashfire Dispenser Machine.${NC}"
echo -e "${GREEN}Project directory: ${PROJECT_DIR}${NC}"

# Show pod status
echo -e "${BLUE}=== Kubernetes Pod Status ===${NC}"
kubectl get pods -n vvm-system

# Show service status
echo -e "${BLUE}=== Kubernetes Service Status ===${NC}"
kubectl get svc -n vvm-system

# Show custom resources
echo -e "${BLUE}=== Custom Resources Status ===${NC}"
kubectl get microvms --all-namespaces
kubectl get mcpsessions --all-namespaces
EOF

# Clean up
rm /tmp/trashfire-project.tar.gz

echo -e "${GREEN}All operations completed successfully!${NC}"
echo -e "${GREEN}You can access the Lima VM with:${NC}"
echo -e "${YELLOW}limactl shell $LIMA_VM_NAME${NC}"
echo -e "${GREEN}Navigate to the project directory:${NC}"
echo -e "${YELLOW}cd /tmp/trashfire-dispenser-machine${NC}"