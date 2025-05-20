#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Running test in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Running test inside Lima VM ===${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not available${NC}"
    echo -e "${YELLOW}Checking if k3s is available...${NC}"
    if command -v k3s &> /dev/null; then
        echo -e "${GREEN}k3s is available${NC}"
        echo -e "${YELLOW}Using k3s kubectl...${NC}"
        KUBECTL="k3s kubectl"
    else
        echo -e "${RED}k3s is not available${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}kubectl is available${NC}"
    KUBECTL="kubectl"
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not available${NC}"
    exit 1
else
    echo -e "${GREEN}Docker is available${NC}"
fi

# List Docker images
echo -e "${YELLOW}Listing Docker images...${NC}"
sudo docker images

# List running containers
echo -e "${YELLOW}Listing running containers...${NC}"
sudo docker ps

# Check Kubernetes nodes
echo -e "${YELLOW}Checking Kubernetes nodes...${NC}"
$KUBECTL get nodes

# Check Kubernetes pods
echo -e "${YELLOW}Checking Kubernetes pods...${NC}"
$KUBECTL get pods --all-namespaces

# Create a test pod
echo -e "${YELLOW}Creating a test pod...${NC}"
cat << EOL | $KUBECTL apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: ubuntu:20.04
    command: ["sleep", "3600"]
EOL

# Wait for the pod to be created
echo -e "${YELLOW}Waiting for the pod to be created...${NC}"
sleep 10

# Check the status of the pod
echo -e "${YELLOW}Checking the status of the pod...${NC}"
$KUBECTL get pods

echo -e "${GREEN}Test completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"