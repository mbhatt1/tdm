#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display help message
function show_help {
    echo -e "${BLUE}Virtual VM (VVM) Management Script${NC}"
    echo -e "Usage: $0 [command] [options]"
    echo
    echo -e "Commands:"
    echo -e "  ${GREEN}setup${NC}                  Setup the VVM system in Lima VM"
    echo -e "  ${GREEN}status${NC}                 Check the status of the VVM system"
    echo -e "  ${GREEN}create-vm${NC}              Create a new MicroVM"
    echo -e "  ${GREEN}create-session${NC}         Create a new MCPSession"
    echo -e "  ${GREEN}execute${NC} [script]       Execute a Python script in a MicroVM"
    echo -e "  ${GREEN}logs${NC}                   Check the logs of the VVM components"
    echo -e "  ${GREEN}update${NC}                 Update the VVM components"
    echo -e "  ${GREEN}help${NC}                   Show this help message"
    echo
    echo -e "Examples:"
    echo -e "  $0 setup                  # Setup the VVM system"
    echo -e "  $0 status                 # Check the status of the VVM system"
    echo -e "  $0 create-vm              # Create a new MicroVM"
    echo -e "  $0 create-session         # Create a new MCPSession"
    echo -e "  $0 execute \"print('Hello')\" # Execute a Python script in a MicroVM"
    echo -e "  $0 logs                   # Check the logs of the VVM components"
    echo -e "  $0 update                 # Update the VVM components"
    echo
}

# Setup the VVM system
function setup {
    echo -e "${BLUE}=== Setting up VVM system in Lima VM ===${NC}"
    
    # Check if Lima VM exists
    if ! limactl list | grep -q vvm-dev; then
        echo -e "${YELLOW}Creating Lima VM...${NC}"
        ./scripts/setup-lima.sh
    else
        echo -e "${YELLOW}Lima VM already exists${NC}"
    fi
    
    # Deploy the VVM components
    echo -e "${YELLOW}Deploying VVM components...${NC}"
    ./scripts/deploy-hostpath.sh
    
    echo -e "${GREEN}VVM system setup completed!${NC}"
}

# Check the status of the VVM system
function check_status {
    echo -e "${BLUE}=== Checking VVM system status in Lima VM ===${NC}"
    
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

echo -e "${BLUE}=== Checking VVM system status inside Lima VM ===${NC}"

# Check the status of the pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vvm-system

# Check the status of the MicroVMs
echo -e "${YELLOW}Checking MicroVM status...${NC}"
kubectl get microvms

# Check the status of the MCPSessions
echo -e "${YELLOW}Checking MCPSession status...${NC}"
kubectl get mcpsessions

echo -e "${GREEN}Status check completed!${NC}"
EOF

    echo -e "${GREEN}Commands executed in Lima VM!${NC}"
}

# Create a new MicroVM
function create_vm {
    echo -e "${BLUE}=== Creating MicroVM in Lima VM ===${NC}"
    
    # Run the create-microvm.sh script
    ./scripts/create-microvm.sh
}

# Create a new MCPSession
function create_session {
    echo -e "${BLUE}=== Creating MCPSession in Lima VM ===${NC}"
    
    # Run the create-mcpsession.sh script
    ./scripts/create-mcpsession.sh
}

# Execute a Python script in a MicroVM
function execute_script {
    if [ -z "$1" ]; then
        echo -e "${RED}Please provide a Python script as an argument${NC}"
        echo -e "Usage: $0 execute \"print('Hello, World!')\""
        exit 1
    fi
    
    echo -e "${BLUE}=== Executing script in Firecracker microVM ===${NC}"
    
    # Run the execute-custom-script.sh script
    ./scripts/execute-custom-script.sh "$1"
}

# Check the logs of the VVM components
function check_logs {
    echo -e "${BLUE}=== Checking VVM component logs in Lima VM ===${NC}"
    
    # Run the check-logs.sh script
    ./scripts/check-logs.sh
}

# Update the VVM components
function update_components {
    echo -e "${BLUE}=== Updating VVM components in Lima VM ===${NC}"
    
    # Run the update-components.sh script
    ./scripts/update-components.sh
}

# Main function
function main {
    # Check if a command was provided
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # Parse the command
    case "$1" in
        setup)
            setup
            ;;
        status)
            check_status
            ;;
        create-vm)
            create_vm
            ;;
        create-session)
            create_session
            ;;
        execute)
            execute_script "$2"
            ;;
        logs)
            check_logs
            ;;
        update)
            update_components
            ;;
        help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"