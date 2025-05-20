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

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y make docker.io jq

# Enable Docker
echo -e "${YELLOW}Enabling Docker...${NC}"
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $(whoami)

# Fix Go dependencies
echo -e "${YELLOW}Fixing Go dependencies...${NC}"
cd "$PROJECT_DIR"
go mod tidy
go get google.golang.org/grpc/credentials/insecure
go get github.com/go-logr/zapr
go get go.uber.org/zap
go get go.uber.org/zap/buffer
go get go.uber.org/zap/zapcore

# Build the project
echo -e "${YELLOW}Building the project...${NC}"
cd "$PROJECT_DIR"
make build

# Build Docker images
echo -e "${YELLOW}Building Docker images...${NC}"
cd "$PROJECT_DIR"
sudo docker build -t lime-ctrl:latest -f build/lime-ctrl/Dockerfile .
sudo docker build -t kvm-device-plugin:latest -f build/kvm-device-plugin/Dockerfile .

# Create namespace
echo -e "${YELLOW}Creating Kubernetes namespace...${NC}"
kubectl create namespace vvm-system --dry-run=client -o yaml | kubectl apply -f -

# Install CRDs
echo -e "${YELLOW}Installing CRDs...${NC}"
cd "$PROJECT_DIR"
kubectl apply -f deploy/crds/ --validate=false

# Deploy components
echo -e "${YELLOW}Deploying components...${NC}"
cd "$PROJECT_DIR"
kubectl apply -f deploy/ --validate=false

# Wait for deployments to start
echo -e "${YELLOW}Waiting for deployments to start...${NC}"
sleep 30

# Run tests
echo -e "${YELLOW}Running tests...${NC}"
cd "$PROJECT_DIR"
chmod +x scripts/test-deployment.sh
./scripts/test-deployment.sh

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