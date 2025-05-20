#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing import paths in Go files ===${NC}"

# Get the module name from go.mod
MODULE_NAME=$(grep "^module" go.mod | awk '{print $2}')
echo -e "${YELLOW}Module name: ${MODULE_NAME}${NC}"

# Find all Go files
GO_FILES=$(find . -name "*.go" -type f)

# Replace import paths
echo -e "${YELLOW}Replacing import paths...${NC}"
for file in $GO_FILES; do
    echo -e "${YELLOW}Processing file: ${file}${NC}"
    # Replace github.com/mbhatt/tvm with the module name
    sed -i '' "s|github.com/mbhatt/tvm|${MODULE_NAME}|g" "$file"
done

echo -e "${GREEN}Import paths fixed successfully!${NC}"