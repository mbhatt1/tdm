#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Deploying Trashfire Vending Machine to Kubernetes in Lima VM ===${NC}"

# Create the directory in Lima VM
echo -e "${YELLOW}Creating directory in Lima VM...${NC}"
limactl shell vvm-dev mkdir -p /home/mbhatt.linux/tvm/

# Copy the code to Lima VM
echo -e "${YELLOW}Copying code to Lima VM...${NC}"
limactl copy --recursive . vvm-dev:/home/mbhatt.linux/tvm/

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

echo -e "${BLUE}=== Building and deploying inside Lima VM ===${NC}"

# Change to the tvm directory
cd ~/tvm

# Build the components
echo -e "${YELLOW}Building components...${NC}"
mkdir -p bin
go build -o bin/lime-ctrl ./cmd/lime-ctrl
go build -o bin/flintlock ./cmd/flintlock
go build -o bin/kvm-device-plugin ./cmd/kvm-device-plugin

# Build Docker images
echo -e "${YELLOW}Building Docker images...${NC}"
docker build -t lime-ctrl:latest -f build/lime-ctrl/Dockerfile .
docker build -t flintlock:latest -f build/flintlock/Dockerfile .
docker build -t kvm-device-plugin:latest -f build/kvm-device-plugin/Dockerfile .

# Import images into containerd
echo -e "${YELLOW}Importing images into containerd...${NC}"
docker save lime-ctrl:latest | sudo ctr -n=k8s.io images import -
docker save flintlock:latest | sudo ctr -n=k8s.io images import -
docker save kvm-device-plugin:latest | sudo ctr -n=k8s.io images import -

# Delete existing deployments
echo -e "${YELLOW}Deleting existing deployments...${NC}"
kubectl delete namespace vvm-system || true
kubectl delete clusterrole lime-ctrl || true
kubectl delete clusterrolebinding lime-ctrl || true
kubectl delete clusterrole flintlock || true
kubectl delete clusterrolebinding flintlock || true

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace vvm-system

# Apply CRDs
echo -e "${YELLOW}Applying CRDs...${NC}"
kubectl apply -f deploy/crds/

# Apply shared volume
echo -e "${YELLOW}Applying shared volume...${NC}"
kubectl apply -f deploy/shared-volume.yaml

# Apply deployments
echo -e "${YELLOW}Applying deployments...${NC}"
kubectl apply -f deploy/kvm-device-plugin.yaml
kubectl apply -f deploy/flintlock.yaml
kubectl apply -f deploy/lime-ctrl.yaml

# Wait for pods to start
echo -e "${YELLOW}Waiting for pods to start...${NC}"
sleep 30

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Create a MicroVM
echo -e "${YELLOW}Creating a MicroVM...${NC}"
cat > test-microvm.yaml << EOL
apiVersion: vvm.tvm.github.com/v1alpha1
kind: MicroVM
metadata:
  name: test-microvm
  namespace: vvm-system
spec:
  image: ubuntu:20.04
  cpu: 1
  memory: 512
  mcpMode: true
EOL

kubectl apply -f test-microvm.yaml

# Wait for MicroVM to be ready
echo -e "${YELLOW}Waiting for MicroVM to be ready...${NC}"
sleep 30

# Check MicroVM status
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms -n vvm-system

# Execute a Python script
echo -e "${YELLOW}Executing a Python script in the MicroVM...${NC}"
cat > test-script.py << EOL
import os
import sys
import datetime
import platform

print('=== Trashfire Vending Machine Test ===')
print('Current time:', datetime.datetime.now())
print('Python version:', sys.version)
print('Process ID:', os.getpid())
print('Platform:', platform.platform())
print('Hostname:', platform.node())

# Create a file
print('\\nCreating a file...')
with open('/tmp/tvm_test.txt', 'w') as f:
    f.write('This file was created inside a Firecracker microVM\\n')
    f.write(f'Current time: {datetime.datetime.now()}\\n')

# Read the file
print('Reading the file:')
with open('/tmp/tvm_test.txt', 'r') as f:
    print(f.read())

print('\\nExecution completed successfully!')
EOL

# Create directory for flintlock data if it doesn't exist
sudo mkdir -p /tmp/flintlock-data/microvms

# Copy the script to the shared volume
sudo cp test-script.py /tmp/flintlock-data/custom_script.py

# Create execution request
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/custom_script.py"],
  "env": {
    "VVM_EXECUTION_ID": "test-123",
    "VVM_USER": "user123"
  },
  "timeout": 60
}
EOL'

# Wait for execution to complete
echo -e "${YELLOW}Waiting for execution to complete...${NC}"
sleep 5

# Check execution response
echo -e "${YELLOW}Checking execution response...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    echo -e "${GREEN}=== Execution Output ===${NC}"
    sudo cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo -e "${RED}No execution response found${NC}"
fi

echo -e "${GREEN}Deployment and test completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"# Check MicroVM status
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms -n vvm-system

# Execute a Python script
echo -e "${YELLOW}Executing a Python script in the MicroVM...${NC}"
cat > test-script.py << EOL
import os
import sys
import datetime
import platform

print('=== Trashfire Vending Machine Test ===')
print('Current time:', datetime.datetime.now())
print('Python version:', sys.version)
print('Process ID:', os.getpid())
print('Platform:', platform.platform())
print('Hostname:', platform.node())

# Create a file
print('\\nCreating a file...')
with open('/tmp/tvm_test.txt', 'w') as f:
    f.write('This file was created inside a Firecracker microVM\\n')
    f.write(f'Current time: {datetime.datetime.now()}\\n')

# Read the file
print('Reading the file:')
with open('/tmp/tvm_test.txt', 'r') as f:
    print(f.read())

print('\\nExecution completed successfully!')
EOL

# Create directory for flintlock data if it doesn't exist
sudo mkdir -p /tmp/flintlock-data/microvms

# Copy the script to the shared volume
sudo cp test-script.py /tmp/flintlock-data/custom_script.py

# Create execution request
sudo bash -c 'cat > /tmp/flintlock-data/microvms/execute_request.txt << EOL
{
  "command": "python3",
  "args": ["/var/lib/flintlock/custom_script.py"],
  "env": {
    "VVM_EXECUTION_ID": "test-123",
    "VVM_USER": "user123"
  },
  "timeout": 60
}
EOL'

# Wait for execution to complete
echo -e "${YELLOW}Waiting for execution to complete...${NC}"
sleep 5

# Check execution response
echo -e "${YELLOW}Checking execution response...${NC}"
if [ -f /tmp/flintlock-data/microvms/execute_response.txt ]; then
    echo -e "${GREEN}=== Execution Output ===${NC}"
    sudo cat /tmp/flintlock-data/microvms/execute_response.txt
else
    echo -e "${RED}No execution response found${NC}"
fi

echo -e "${GREEN}Deployment and test completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"