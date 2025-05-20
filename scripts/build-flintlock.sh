#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building flintlock component ===${NC}"

# Create build directory
mkdir -p build/bin

# Build flintlock binary
echo -e "${YELLOW}Building flintlock binary...${NC}"
go build -o build/bin/flintlock ./cmd/flintlock

# Build Docker image
echo -e "${YELLOW}Building flintlock Docker image...${NC}"
docker build -t flintlock:latest -f build/flintlock/Dockerfile .

echo -e "${GREEN}Build completed!${NC}"