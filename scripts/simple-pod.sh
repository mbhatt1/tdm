#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Creating simple pods in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Creating simple pods inside Lima VM ===${NC}"

# List the Docker images to get the exact image IDs
echo -e "${YELLOW}Listing Docker images...${NC}"
sudo docker images

# Create a simple pod that uses our lime-ctrl image
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
    image: localhost/lime-ctrl:latest
    imagePullPolicy: Never
EOL

# Create a simple pod that uses our kvm-device-plugin image
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
    image: localhost/kvm-device-plugin:latest
    imagePullPolicy: Never
EOL

# Wait for the pods to be created
echo -e "${YELLOW}Waiting for the pods to be created...${NC}"
sleep 10

# Check the status of the pods
echo -e "${YELLOW}Checking the status of the pods...${NC}"
kubectl get pods

echo -e "${GREEN}Simple pods created!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"