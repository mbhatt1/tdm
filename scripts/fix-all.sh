#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Fixing TVM System ===${NC}"

# Step 1: Fix the flintlock deployment
echo -e "${YELLOW}Step 1: Fixing flintlock deployment...${NC}"
./scripts/fix-flintlock.sh

# Step 2: Fix the lime-ctrl deployment
echo -e "${YELLOW}Step 2: Fixing lime-ctrl deployment...${NC}"
./scripts/fix-lime-ctrl.sh

# Step 3: Recreate the MicroVM
echo -e "${YELLOW}Step 3: Recreating MicroVM...${NC}"
./scripts/recreate-microvm.sh

echo -e "${GREEN}All fixes applied!${NC}"