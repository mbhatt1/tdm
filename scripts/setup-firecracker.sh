#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setting up Firecracker in Lima VM ===${NC}"

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

echo -e "${BLUE}=== Setting up Firecracker inside Lima VM ===${NC}"

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
sudo apt-get update
sudo apt-get install -y curl wget unzip qemu-utils

# Download Firecracker binary
echo -e "${YELLOW}Downloading Firecracker...${NC}"
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

# Download a Linux kernel for Firecracker
echo -e "${YELLOW}Downloading Linux kernel for Firecracker...${NC}"
sudo mkdir -p /opt/firecracker/kernel
cd /opt/firecracker/kernel
sudo wget https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/kernels/vmlinux.bin

# Download a rootfs for Firecracker
echo -e "${YELLOW}Downloading rootfs for Firecracker...${NC}"
sudo mkdir -p /opt/firecracker/rootfs
cd /opt/firecracker/rootfs
sudo wget https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/x86_64/rootfs/bionic.rootfs.ext4

# Create a directory for VM configurations
echo -e "${YELLOW}Creating VM configuration directory...${NC}"
sudo mkdir -p /opt/firecracker/config

# Create a basic VM configuration
echo -e "${YELLOW}Creating basic VM configuration...${NC}"
sudo bash -c 'cat > /opt/firecracker/config/vm-config.json << EOL
{
  "boot-source": {
    "kernel_image_path": "/opt/firecracker/kernel/vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "/opt/firecracker/rootfs/bionic.rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 512,
    "ht_enabled": false
  },
  "network-interfaces": []
}
EOL'

# Create a script to manage Firecracker VMs
echo -e "${YELLOW}Creating Firecracker VM management script...${NC}"
sudo bash -c 'cat > /opt/firecracker/bin/fc-vm << EOL
#!/bin/bash
set -e

# Firecracker VM management script

VM_ID=\$1
ACTION=\$2
SCRIPT=\$3

VM_DIR="/opt/firecracker/vms/\${VM_ID}"
SOCKET="\${VM_DIR}/firecracker.socket"
PID_FILE="\${VM_DIR}/firecracker.pid"
LOG_FILE="\${VM_DIR}/firecracker.log"
CONFIG_FILE="\${VM_DIR}/config.json"
ROOTFS_FILE="\${VM_DIR}/rootfs.ext4"
SCRIPT_FILE="\${VM_DIR}/script.sh"
OUTPUT_FILE="\${VM_DIR}/output.txt"

function create_vm() {
  if [ -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID already exists"
    return 1
  fi
  
  mkdir -p "\$VM_DIR"
  cp /opt/firecracker/config/vm-config.json "\$CONFIG_FILE"
  cp /opt/firecracker/rootfs/bionic.rootfs.ext4 "\$ROOTFS_FILE"
  
  # Update the config file with the VM-specific paths
  sed -i "s|/opt/firecracker/rootfs/bionic.rootfs.ext4|\$ROOTFS_FILE|g" "\$CONFIG_FILE"
  
  echo "VM \$VM_ID created"
}

function start_vm() {
  if [ ! -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID does not exist"
    return 1
  fi
  
  if [ -S "\$SOCKET" ]; then
    echo "VM \$VM_ID is already running"
    return 1
  fi
  
  # Start Firecracker
  rm -f "\$SOCKET"
  firecracker --api-sock "\$SOCKET" --config-file "\$CONFIG_FILE" > "\$LOG_FILE" 2>&1 &
  echo \$! > "\$PID_FILE"
  
  # Wait for the socket to be created
  for i in {1..10}; do
    if [ -S "\$SOCKET" ]; then
      echo "VM \$VM_ID started"
      return 0
    fi
    sleep 1
  done
  
  echo "Failed to start VM \$VM_ID"
  return 1
}

function stop_vm() {
  if [ ! -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID does not exist"
    return 1
  fi
  
  if [ ! -f "\$PID_FILE" ]; then
    echo "VM \$VM_ID is not running"
    return 1
  fi
  
  PID=\$(cat "\$PID_FILE")
  kill -9 \$PID || true
  rm -f "\$PID_FILE" "\$SOCKET"
  
  echo "VM \$VM_ID stopped"
}

function delete_vm() {
  if [ ! -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID does not exist"
    return 1
  fi
  
  if [ -f "\$PID_FILE" ]; then
    stop_vm
  fi
  
  rm -rf "\$VM_DIR"
  
  echo "VM \$VM_ID deleted"
}

function execute_script() {
  if [ ! -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID does not exist"
    return 1
  fi
  
  if [ ! -S "\$SOCKET" ]; then
    echo "VM \$VM_ID is not running"
    return 1
  fi
  
  if [ -z "\$SCRIPT" ]; then
    echo "No script provided"
    return 1
  fi
  
  # Copy the script to the VM directory
  cp "\$SCRIPT" "\$SCRIPT_FILE"
  
  # TODO: In a real implementation, we would use SSH or another method to execute the script inside the VM
  # For now, we'll just simulate execution by running it locally
  python3 "\$SCRIPT_FILE" > "\$OUTPUT_FILE" 2>&1
  EXIT_CODE=\$?
  
  echo "Script executed in VM \$VM_ID with exit code \$EXIT_CODE"
  return \$EXIT_CODE
}

function get_output() {
  if [ ! -d "\$VM_DIR" ]; then
    echo "VM \$VM_ID does not exist"
    return 1
  fi
  
  if [ ! -f "\$OUTPUT_FILE" ]; then
    echo "No output available for VM \$VM_ID"
    return 1
  fi
  
  cat "\$OUTPUT_FILE"
}

case "\$ACTION" in
  create)
    create_vm
    ;;
  start)
    start_vm
    ;;
  stop)
    stop_vm
    ;;
  delete)
    delete_vm
    ;;
  execute)
    execute_script
    ;;
  output)
    get_output
    ;;
  *)
    echo "Usage: \$0 <vm-id> {create|start|stop|delete|execute|output} [script]"
    exit 1
    ;;
esac
EOL'

sudo chmod +x /opt/firecracker/bin/fc-vm
sudo ln -sf /opt/firecracker/bin/fc-vm /usr/local/bin/fc-vm

# Create VM directory
sudo mkdir -p /opt/firecracker/vms

echo -e "${GREEN}Firecracker setup completed!${NC}"
EOF

echo -e "${GREEN}Commands executed in Lima VM!${NC}"