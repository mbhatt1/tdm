#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setting up Firecracker ===${NC}"

# Step 1: Check for KVM support
echo -e "${YELLOW}Checking for KVM support...${NC}"
if [ ! -e /dev/kvm ]; then
  echo -e "${RED}ERROR: /dev/kvm does not exist${NC}"
  echo -e "${RED}Please ensure KVM is enabled in your system${NC}"
  exit 1
fi

# Set permissions for KVM (as shown in the article)
echo -e "${YELLOW}Setting permissions for /dev/kvm...${NC}"
sudo setfacl -m u:${USER}:rw /dev/kvm

# Step 2: Download Firecracker binary using the method from the article
echo -e "${YELLOW}Downloading Firecracker...${NC}"
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest=$(basename $(curl -fsSLI -o /dev/null -w %{url_effective} ${release_url}/latest))
arch=$(uname -m)

echo -e "${YELLOW}Latest Firecracker version: ${latest}, Architecture: ${arch}${NC}"
curl -L ${release_url}/download/${latest}/firecracker-${latest}-${arch}.tgz | tar -xz
mv release-${latest}-$(uname -m)/firecracker-${latest}-$(uname -m) firecracker
chmod +x firecracker
sudo mv firecracker /usr/local/bin/

# Verify installation
if command -v firecracker &> /dev/null; then
  echo -e "${GREEN}Firecracker installed successfully:${NC}"
  firecracker --version
else
  echo -e "${RED}Failed to install Firecracker${NC}"
  exit 1
fi

# Step 3: Set up directories for Firecracker
echo -e "${YELLOW}Setting up directories for Firecracker...${NC}"
mkdir -p /tmp/firecracker
FIRECRACKER_DIR="/tmp/firecracker"

# Step 4: Download kernel and rootfs
echo -e "${YELLOW}Downloading kernel and rootfs for Firecracker...${NC}"
if [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
  KERNEL_URL="https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/kernels/vmlinux.bin"
  ROOTFS_URL="https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/rootfs/bionic.rootfs.ext4"
else
  KERNEL_URL="https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin"
  ROOTFS_URL="https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4"
fi

echo -e "${YELLOW}Downloading kernel from ${KERNEL_URL}...${NC}"
curl -Lo "${FIRECRACKER_DIR}/vmlinux" "${KERNEL_URL}"

echo -e "${YELLOW}Downloading rootfs from ${ROOTFS_URL}...${NC}"
curl -Lo "${FIRECRACKER_DIR}/rootfs.ext4" "${ROOTFS_URL}"

# Step 5: Create a script to run Firecracker (using the API approach from the article)
echo -e "${YELLOW}Creating run script...${NC}"
cat > "${FIRECRACKER_DIR}/run-firecracker.sh" << EOL
#!/bin/bash
set -e

# Variables
KERNEL_PATH="${FIRECRACKER_DIR}/vmlinux"
ROOTFS_PATH="${FIRECRACKER_DIR}/rootfs.ext4"
API_SOCKET="/tmp/firecracker.socket"

# Remove socket if it exists
rm -f \${API_SOCKET}

# Start Firecracker
echo "Starting Firecracker..."
firecracker --api-sock \${API_SOCKET} &
FC_PID=\$!

# Wait for socket to be created
while [ ! -e \${API_SOCKET} ]; do
    echo "Waiting for Firecracker API socket..."
    sleep 0.1
done

# Configure boot source
echo "Configuring boot source..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PUT 'http://localhost/boot-source' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d "{
        \"kernel_image_path\": \"\${KERNEL_PATH}\",
        \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
    }"

# Configure rootfs
echo "Configuring rootfs..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PUT 'http://localhost/drives/rootfs' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d "{
        \"drive_id\": \"rootfs\",
        \"path_on_host\": \"\${ROOTFS_PATH}\",
        \"is_root_device\": true,
        \"is_read_only\": false
    }"

# Optional: Configure network (uncomment to enable)
# echo "Setting up network..."
# sudo ip tuntap add dev tap0 mode tap user \$(whoami)
# sudo ip addr add 172.16.0.1/24 dev tap0
# sudo ip link set tap0 up
# sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
# sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# sudo iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT
#
# curl --unix-socket \${API_SOCKET} -i \\
#     -X PUT 'http://localhost/network-interfaces/eth0' \\
#     -H 'Accept: application/json' \\
#     -H 'Content-Type: application/json' \\
#     -d '{
#         "iface_id": "eth0",
#         "guest_mac": "AA:FC:00:00:00:01",
#         "host_dev_name": "tap0"
#     }'

# Start the VM
echo "Starting the VM..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PUT 'http://localhost/actions' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d '{
        "action_type": "InstanceStart"
    }'

echo "MicroVM is running. Press Ctrl+C to stop."
wait \${FC_PID}
EOL

chmod +x "${FIRECRACKER_DIR}/run-firecracker.sh"

# Step 6: Create a script for taking snapshots
echo -e "${YELLOW}Creating snapshot script...${NC}"
cat > "${FIRECRACKER_DIR}/snapshot-firecracker.sh" << EOL
#!/bin/bash
set -e

# Variables
API_SOCKET="/tmp/firecracker.socket"
SNAPSHOT_PATH="${FIRECRACKER_DIR}/snapshot"
MEM_FILE_PATH="${FIRECRACKER_DIR}/memory"

# Pause the VM
echo "Pausing the VM..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PATCH 'http://localhost/vm' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d '{
        "state": "Paused"
    }'

# Create snapshot
echo "Creating snapshot..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PUT 'http://localhost/snapshot/create' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d "{
        \"snapshot_path\": \"\${SNAPSHOT_PATH}\",
        \"mem_file_path\": \"\${MEM_FILE_PATH}\",
        \"version\": \"2.0.0\"
    }"

# Resume the VM
echo "Resuming the VM..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PATCH 'http://localhost/vm' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d '{
        "state": "Resumed"
    }'

echo "Snapshot created at \${SNAPSHOT_PATH} and \${MEM_FILE_PATH}"
EOL

chmod +x "${FIRECRACKER_DIR}/snapshot-firecracker.sh"

# Step 7: Create a script for restoring from snapshots
echo -e "${YELLOW}Creating restore script...${NC}"
cat > "${FIRECRACKER_DIR}/restore-firecracker.sh" << EOL
#!/bin/bash
set -e

# Variables
API_SOCKET="/tmp/firecracker.socket"
SNAPSHOT_PATH="${FIRECRACKER_DIR}/snapshot"
MEM_FILE_PATH="${FIRECRACKER_DIR}/memory"

# Remove socket if it exists
rm -f \${API_SOCKET}

# Start Firecracker
echo "Starting Firecracker..."
firecracker --api-sock \${API_SOCKET} &
FC_PID=\$!

# Wait for socket to be created
while [ ! -e \${API_SOCKET} ]; do
    echo "Waiting for Firecracker API socket..."
    sleep 0.1
done

# Restore from snapshot
echo "Restoring from snapshot..."
curl --unix-socket \${API_SOCKET} -i \\
    -X PUT 'http://localhost/snapshot/load' \\
    -H 'Accept: application/json' \\
    -H 'Content-Type: application/json' \\
    -d "{
        \"snapshot_path\": \"\${SNAPSHOT_PATH}\",
        \"mem_file_path\": \"\${MEM_FILE_PATH}\",
        \"enable_diff_snapshots\": false,
        \"resume_vm\": true
    }"

echo "MicroVM restored and running. Press Ctrl+C to stop."
wait \${FC_PID}
EOL

chmod +x "${FIRECRACKER_DIR}/restore-firecracker.sh"

echo -e "${GREEN}Firecracker setup complete!${NC}"
echo -e "${GREEN}You can run a test VM with:${NC}"
echo -e "${YELLOW}${FIRECRACKER_DIR}/run-firecracker.sh${NC}"
echo -e "${GREEN}You can create a snapshot with:${NC}"
echo -e "${YELLOW}${FIRECRACKER_DIR}/snapshot-firecracker.sh${NC}"
echo -e "${GREEN}You can restore from a snapshot with:${NC}"
echo -e "${YELLOW}${FIRECRACKER_DIR}/restore-firecracker.sh${NC}"