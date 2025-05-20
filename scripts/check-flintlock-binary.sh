#!/bin/bash
set -e

echo "Checking flintlock binary..."
echo "Binary location: $(pwd)/bin/flintlock"

# Check if the binary exists
if [ ! -f bin/flintlock ]; then
    echo "Error: flintlock binary does not exist"
    exit 1
fi

# Check permissions
echo "Checking permissions..."
ls -la bin/flintlock

# Check file type
echo "Checking file type..."
file bin/flintlock

# Make sure it's executable
echo "Making binary executable..."
chmod +x bin/flintlock

# Try to run it with --help
echo "Trying to run flintlock with --help..."
bin/flintlock --help || echo "Failed to run flintlock: $?"

echo "Flintlock binary check completed"