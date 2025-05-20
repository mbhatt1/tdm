#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building flintlock component in Lima VM ===${NC}"

# Copy the code to Lima VM
echo -e "${YELLOW}Copying code to Lima VM...${NC}"
limactl copy --recursive . vvm-dev:/home/mbhatt/tvm/

# Connect to the Lima VM and run commands
limactl shell vvm-dev << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building flintlock component inside Lima VM ===${NC}"

# Change to the tvm directory
cd ~/tvm

# Update Go module dependencies
echo -e "${YELLOW}Updating Go module dependencies...${NC}"
go mod tidy

# Build flintlock binary
echo -e "${YELLOW}Building flintlock binary...${NC}"
mkdir -p build/bin
go build -o build/bin/flintlock ./cmd/flintlock

# Build Docker image
echo -e "${YELLOW}Building flintlock Docker image...${NC}"
docker build -t flintlock:latest -f build/flintlock/Dockerfile .

# Import flintlock image into containerd
echo -e "${YELLOW}Importing flintlock image into containerd...${NC}"
docker save flintlock:latest | sudo ctr -n=k8s.io images import -

echo -e "${GREEN}Build completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"