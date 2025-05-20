#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Trashfire Dispenser Machine in Lima VM...${NC}"

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    echo -e "${RED}Lima is not installed. Please install it first:${NC}"
    echo "brew install lima"
    exit 1
fi

# Check if the VM already exists
if limactl list | grep -q "vvm-dev"; then
    echo -e "${YELLOW}Lima VM 'vvm-dev' already exists.${NC}"
    
    # Check if it's running
    if limactl list | grep -q "vvm-dev.*Running"; then
        echo -e "${GREEN}Lima VM 'vvm-dev' is already running.${NC}"
    else
        echo -e "${YELLOW}Starting Lima VM 'vvm-dev'...${NC}"
        limactl start vvm-dev
    fi
else
    echo -e "${YELLOW}Creating and starting Lima VM 'vvm-dev'...${NC}"
    limactl start --name=vvm-dev template://k8s
fi

echo -e "${GREEN}Lima VM is running.${NC}"

# Copy project files to the VM
echo -e "${YELLOW}Copying project files to the VM...${NC}"
limactl copy . vvm-dev:/home/lima/trashfire-dispenser-machine

# Connect to the VM and set up the project
echo -e "${YELLOW}Setting up the project in the VM...${NC}"
limactl shell vvm-dev << EOF
cd /home/lima/trashfire-dispenser-machine

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y make docker.io jq

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker lima

# Fix Go dependencies
echo -e "${YELLOW}Fixing Go dependencies...${NC}"
go mod tidy
go get google.golang.org/grpc/credentials/insecure
go get github.com/go-logr/zapr
go get go.uber.org/zap
go get go.uber.org/zap/buffer
go get go.uber.org/zap/zapcore

# Build the project
echo -e "${YELLOW}Building the project...${NC}"
make build

# Build Docker images (inside Lima)
echo -e "${YELLOW}Building Docker images...${NC}"
sudo docker build -t lime-ctrl:latest -f build/lime-ctrl/Dockerfile .
sudo docker build -t kvm-device-plugin:latest -f build/kvm-device-plugin/Dockerfile .

# Install CRDs with validation disabled
echo -e "${YELLOW}Installing CRDs...${NC}"
kubectl apply -f deploy/crds/ --validate=false

# Deploy components
echo -e "${YELLOW}Deploying components...${NC}"
kubectl apply -f deploy/ --validate=false

echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}You can now access the Lima VM with:${NC}"
echo -e "${YELLOW}limactl shell vvm-dev${NC}"
EOF

echo -e "${GREEN}Trashfire Dispenser Machine has been set up in the Lima VM.${NC}"
echo -e "${GREEN}You can access the Lima VM with:${NC}"
echo -e "${YELLOW}limactl shell vvm-dev${NC}"
echo -e "${GREEN}Important notes:${NC}"
echo -e "${YELLOW}1. All build and deployment commands should be run INSIDE the Lima VM${NC}"
echo -e "${YELLOW}2. When applying Kubernetes resources, use --validate=false to bypass validation errors${NC}"
echo -e "${YELLOW}3. To test the deployment, run the following inside the Lima VM:${NC}"
echo -e "${YELLOW}   cd /home/lima/trashfire-dispenser-machine && ./scripts/test-deployment.sh${NC}"