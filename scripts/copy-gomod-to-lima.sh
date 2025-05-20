#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Copying go.mod to Lima VM ===${NC}"

# Copy the go.mod file to Lima VM
echo -e "${YELLOW}Copying go.mod to Lima VM...${NC}"
limactl copy go.mod vvm-dev:/home/mbhatt.linux/tvm/go.mod

echo -e "${GREEN}go.mod copied successfully!${NC}"