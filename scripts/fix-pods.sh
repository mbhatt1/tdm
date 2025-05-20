#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing pods in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Fixing pods inside Lima VM ===${NC}"

# Delete existing pods
echo -e "${YELLOW}Deleting existing pods...${NC}"
kubectl delete pod lime-ctrl-pod kvm-device-plugin-pod --ignore-not-found

# Check what runtime Kubernetes is using
echo -e "${YELLOW}Checking container runtime...${NC}"
kubectl get nodes -o wide

# Check what images are available
echo -e "${YELLOW}Checking available images...${NC}"
sudo docker images

# Try using the image ID directly
echo -e "${YELLOW}Creating pods with image ID...${NC}"

# Get the image IDs
LIME_CTRL_ID=$(sudo docker images -q lime-ctrl:latest)
KVM_DEVICE_PLUGIN_ID=$(sudo docker images -q kvm-device-plugin:latest)

echo -e "${YELLOW}lime-ctrl image ID: ${LIME_CTRL_ID}${NC}"
echo -e "${YELLOW}kvm-device-plugin image ID: ${KVM_DEVICE_PLUGIN_ID}${NC}"

# Create a simple pod that uses our lime-ctrl image ID
echo -e "${YELLOW}Creating a simple pod with lime-ctrl image ID...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: lime-ctrl-pod
  namespace: default
spec:
  containers:
  - name: lime-ctrl
    image: ${LIME_CTRL_ID}
    imagePullPolicy: IfNotPresent
EOL

# Create a simple pod that uses our kvm-device-plugin image ID
echo -e "${YELLOW}Creating a simple pod with kvm-device-plugin image ID...${NC}"
cat << EOL | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: kvm-device-plugin-pod
  namespace: default
spec:
  containers:
  - name: kvm-device-plugin
    image: ${KVM_DEVICE_PLUGIN_ID}
    imagePullPolicy: IfNotPresent
EOL

# Wait for the pods to be created
echo -e "${YELLOW}Waiting for the pods to be created...${NC}"
sleep 10

# Check the status of the pods
echo -e "${YELLOW}Checking the status of the pods...${NC}"
kubectl get pods

echo -e "${GREEN}Pods created!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"