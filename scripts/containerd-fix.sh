#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing containerd images in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Fixing containerd images inside Lima VM ===${NC}"

# Delete existing pods
echo -e "${YELLOW}Deleting existing pods...${NC}"
kubectl delete pod lime-ctrl-pod kvm-device-plugin-pod --ignore-not-found

# Create a temporary directory for the images
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Save the Docker images to tar files
echo -e "${YELLOW}Saving Docker images to tar files...${NC}"
sudo docker save lime-ctrl:latest -o "${TEMP_DIR}/lime-ctrl.tar"
sudo docker save kvm-device-plugin:latest -o "${TEMP_DIR}/kvm-device-plugin.tar"

# Find the containerd socket
echo -e "${YELLOW}Finding containerd socket...${NC}"
CONTAINERD_SOCK=$(find /run -name containerd.sock 2>/dev/null | head -n 1)
if [ -z "$CONTAINERD_SOCK" ]; then
    echo -e "${RED}containerd socket not found${NC}"
    # Try the default location
    CONTAINERD_SOCK="/run/containerd/containerd.sock"
    echo -e "${YELLOW}Using default containerd socket: ${CONTAINERD_SOCK}${NC}"
fi

# Check if the socket exists
if [ ! -e "$CONTAINERD_SOCK" ]; then
    echo -e "${RED}containerd socket does not exist at ${CONTAINERD_SOCK}${NC}"
    echo -e "${YELLOW}Searching for containerd socket...${NC}"
    sudo find / -name containerd.sock 2>/dev/null
    exit 1
fi

echo -e "${GREEN}containerd socket found at ${CONTAINERD_SOCK}${NC}"

# Import the images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images import "${TEMP_DIR}/lime-ctrl.tar"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images import "${TEMP_DIR}/kvm-device-plugin.tar"

# List the imported images
echo -e "${YELLOW}Listing imported images in containerd...${NC}"
sudo ctr -a "$CONTAINERD_SOCK" -n k8s.io images ls | grep -E 'lime-ctrl|kvm-device-plugin'

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

# Create a simple pod that uses our lime-ctrl image with a command that will keep it running
echo -e "${YELLOW}Creating a simple pod with lime-ctrl image...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: lime-ctrl-pod
  namespace: default
spec:
  containers:
  - name: lime-ctrl
    image: docker.io/library/lime-ctrl:latest
    imagePullPolicy: Never
    command: ["/bin/sh", "-c", "sleep 3600"]
EOL

# Create a simple pod that uses our kvm-device-plugin image with a command that will keep it running
echo -e "${YELLOW}Creating a simple pod with kvm-device-plugin image...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: kvm-device-plugin-pod
  namespace: default
spec:
  containers:
  - name: kvm-device-plugin
    image: docker.io/library/kvm-device-plugin:latest
    imagePullPolicy: Never
    command: ["/bin/sh", "-c", "sleep 3600"]
EOL

# Wait for the pods to be created
echo -e "${YELLOW}Waiting for the pods to be created...${NC}"
sleep 10

# Check the status of the pods
echo -e "${YELLOW}Checking the status of the pods...${NC}"
kubectl get pods

# Check the logs of the pods if they're not running
if kubectl get pod lime-ctrl-pod | grep -q -v "Running"; then
    echo -e "${YELLOW}Checking logs of lime-ctrl-pod...${NC}"
    kubectl describe pod lime-ctrl-pod
fi

if kubectl get pod kvm-device-plugin-pod | grep -q -v "Running"; then
    echo -e "${YELLOW}Checking logs of kvm-device-plugin-pod...${NC}"
    kubectl describe pod kvm-device-plugin-pod
fi

echo -e "${GREEN}Containerd images fixed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"