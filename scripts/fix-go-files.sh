#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing Go files ===${NC}"

# Initialize Go module if it doesn't exist
if [ ! -f "go.mod" ]; then
    echo -e "${YELLOW}Initializing Go module...${NC}"
    go mod init github.com/yourusername/tvm
else
    echo -e "${YELLOW}Go module already initialized${NC}"
fi

# Update Go module dependencies
echo -e "${YELLOW}Updating Go module dependencies...${NC}"
go mod tidy

# Format Go files
echo -e "${YELLOW}Formatting Go files...${NC}"
go fmt ./...

# Fix imports
echo -e "${YELLOW}Fixing imports...${NC}"
if command -v goimports &> /dev/null; then
    goimports -w ./cmd ./pkg
else
    echo -e "${YELLOW}goimports not found, skipping import fixes${NC}"
fi

# Verify Go files
echo -e "${YELLOW}Verifying Go files...${NC}"
go vet ./...

echo -e "${GREEN}Go files fixed successfully!${NC}"