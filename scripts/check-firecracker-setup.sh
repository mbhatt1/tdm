#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking Firecracker Setup in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Checking Firecracker Setup inside Lima VM ===${NC}"

# Check if Firecracker is installed
echo -e "${YELLOW}Checking if Firecracker is installed...${NC}"
if command -v firecracker &> /dev/null; then
    echo -e "${GREEN}Firecracker is installed!${NC}"
    firecracker --version
else
    echo -e "${RED}Firecracker is not installed. Installing...${NC}"
    
    # Install required packages
    sudo apt-get update
    sudo apt-get install -y curl wget unzip qemu-utils

    # Download Firecracker binary
    ARCH=$(uname -m)
    FIRECRACKER_VERSION="v1.4.0"
    DOWNLOAD_URL="https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-${ARCH}.tgz"

    # Create directory for Firecracker
    sudo mkdir -p /opt/firecracker/bin
    cd /tmp
    wget $DOWNLOAD_URL
    tar -xvf firecracker-${FIRECRACKER_VERSION}-${ARCH}.tgz
    sudo mv release-${FIRECRACKER_VERSION}-$(uname -m)/firecracker-${FIRECRACKER_VERSION}-$(uname -m) /opt/firecracker/bin/firecracker
    sudo mv release-${FIRECRACKER_VERSION}-$(uname -m)/jailer-${FIRECRACKER_VERSION}-$(uname -m) /opt/firecracker/bin/jailer
    sudo chmod +x /opt/firecracker/bin/firecracker
    sudo chmod +x /opt/firecracker/bin/jailer
    rm -rf release-${FIRECRACKER_VERSION}-$(uname -m) firecracker-${FIRECRACKER_VERSION}-${ARCH}.tgz

    # Create symbolic links
    sudo ln -sf /opt/firecracker/bin/firecracker /usr/local/bin/firecracker
    sudo ln -sf /opt/firecracker/bin/jailer /usr/local/bin/jailer
    
    echo -e "${GREEN}Firecracker installed successfully!${NC}"
    firecracker --version
fi

# Check if the flintlock data directory exists and has the right permissions
echo -e "${YELLOW}Checking flintlock data directory...${NC}"
if [ -d "/tmp/flintlock-data" ]; then
    echo -e "${GREEN}Flintlock data directory exists!${NC}"
    ls -la /tmp/flintlock-data
else
    echo -e "${RED}Flintlock data directory does not exist. Creating...${NC}"
    sudo mkdir -p /tmp/flintlock-data/microvms
    sudo chmod -R 777 /tmp/flintlock-data
    echo -e "${GREEN}Flintlock data directory created!${NC}"
    ls -la /tmp/flintlock-data
fi

# Check if the flintlock pod is running
echo -e "${YELLOW}Checking flintlock pod...${NC}"
FLINTLOCK_POD=$(kubectl get pods -n vvm-system -l app=flintlock -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FLINTLOCK_POD" ]; then
    echo -e "${GREEN}Flintlock pod exists: $FLINTLOCK_POD${NC}"
    kubectl describe pod -n vvm-system $FLINTLOCK_POD | grep -A 20 "Volumes:"
    
    # Check if the flintlock pod has the correct volume mounts
    if kubectl describe pod -n vvm-system $FLINTLOCK_POD | grep -q "containerd-socket"; then
        echo -e "${GREEN}Flintlock pod has containerd-socket volume mount!${NC}"
    else
        echo -e "${RED}Flintlock pod does not have containerd-socket volume mount!${NC}"
    fi
    
    if kubectl describe pod -n vvm-system $FLINTLOCK_POD | grep -q "dev"; then
        echo -e "${GREEN}Flintlock pod has dev volume mount!${NC}"
    else
        echo -e "${RED}Flintlock pod does not have dev volume mount!${NC}"
    fi
    
    if kubectl describe pod -n vvm-system $FLINTLOCK_POD | grep -q "modules"; then
        echo -e "${GREEN}Flintlock pod has modules volume mount!${NC}"
    else
        echo -e "${RED}Flintlock pod does not have modules volume mount!${NC}"
    fi
    
    # Check if the flintlock pod is running
    if kubectl get pods -n vvm-system $FLINTLOCK_POD | grep -q "Running"; then
        echo -e "${GREEN}Flintlock pod is running!${NC}"
    else
        echo -e "${RED}Flintlock pod is not running!${NC}"
        kubectl describe pod -n vvm-system $FLINTLOCK_POD
    fi
    
    # Check the logs of the flintlock pod
    echo -e "${YELLOW}Checking flintlock pod logs...${NC}"
    kubectl logs -n vvm-system $FLINTLOCK_POD
else
    echo -e "${RED}Flintlock pod does not exist!${NC}"
fi

# Check if the lime-ctrl pod is running
echo -e "${YELLOW}Checking lime-ctrl pod...${NC}"
LIME_CTRL_POD=$(kubectl get pods -n vvm-system -l app=lime-ctrl -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$LIME_CTRL_POD" ]; then
    echo -e "${GREEN}Lime-ctrl pod exists: $LIME_CTRL_POD${NC}"
    
    # Check if the lime-ctrl pod is running
    if kubectl get pods -n vvm-system $LIME_CTRL_POD | grep -q "Running"; then
        echo -e "${GREEN}Lime-ctrl pod is running!${NC}"
    else
        echo -e "${RED}Lime-ctrl pod is not running!${NC}"
        kubectl describe pod -n vvm-system $LIME_CTRL_POD
    fi
    
    # Check the logs of the lime-ctrl pod
    echo -e "${YELLOW}Checking lime-ctrl pod logs...${NC}"
    kubectl logs -n vvm-system $LIME_CTRL_POD | tail -n 20
else
    echo -e "${RED}Lime-ctrl pod does not exist!${NC}"
fi

# Check if the MicroVM CRD is installed
echo -e "${YELLOW}Checking MicroVM CRD...${NC}"
if kubectl get crd microvms.vvm.tvm.github.com &> /dev/null; then
    echo -e "${GREEN}MicroVM CRD is installed!${NC}"
else
    echo -e "${RED}MicroVM CRD is not installed!${NC}"
fi

# Check if there are any MicroVMs
echo -e "${YELLOW}Checking MicroVMs...${NC}"
if kubectl get microvms -A &> /dev/null; then
    echo -e "${GREEN}MicroVMs exist!${NC}"
    kubectl get microvms -A
else
    echo -e "${RED}No MicroVMs exist!${NC}"
fi

# Check if the containerd socket exists
echo -e "${YELLOW}Checking containerd socket...${NC}"
if [ -S "/run/containerd/containerd.sock" ]; then
    echo -e "${GREEN}Containerd socket exists!${NC}"
else
    echo -e "${RED}Containerd socket does not exist!${NC}"
fi

# Check if the /dev directory exists
echo -e "${YELLOW}Checking /dev directory...${NC}"
if [ -d "/dev" ]; then
    echo -e "${GREEN}/dev directory exists!${NC}"
else
    echo -e "${RED}/dev directory does not exist!${NC}"
fi

# Check if the /lib/modules directory exists
echo -e "${YELLOW}Checking /lib/modules directory...${NC}"
if [ -d "/lib/modules" ]; then
    echo -e "${GREEN}/lib/modules directory exists!${NC}"
else
    echo -e "${RED}/lib/modules directory does not exist!${NC}"
fi

# Check if the kernel has KVM support
echo -e "${YELLOW}Checking KVM support...${NC}"
if [ -c "/dev/kvm" ]; then
    echo -e "${GREEN}KVM device exists!${NC}"
else
    echo -e "${RED}KVM device does not exist!${NC}"
fi

# Check if the user has permission to access KVM
echo -e "${YELLOW}Checking KVM permissions...${NC}"
if [ -r "/dev/kvm" ] && [ -w "/dev/kvm" ]; then
    echo -e "${GREEN}User has permission to access KVM!${NC}"
else
    echo -e "${RED}User does not have permission to access KVM!${NC}"
    ls -la /dev/kvm
fi

echo -e "${GREEN}Firecracker setup check completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"