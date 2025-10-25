#!/bin/bash

# Example usage of the Network Configuration Manager
# This script demonstrates the save/load workflow

echo "=== Network Configuration Manager - Example Usage ==="
echo ""

# Check if the manager script exists
if [ ! -f "./network-config-manager.sh" ]; then
    echo "Error: network-config-manager.sh not found in current directory"
    exit 1
fi

echo "Step 1: Save current network configuration"
echo "This will create /tmp/warp-report.txt with your current settings"
echo "Press Enter to continue..."
read

./network-config-manager.sh save

echo ""
echo "Step 2: Edit the configuration file"
echo "The configuration file is now open in nano for editing"
echo "Make your changes, save (Ctrl+X, Y, Enter), then press Enter here..."
read

./network-config-manager.sh view

echo ""
echo "Step 3: Load the modified configuration"
echo "This will completely overwrite your current network settings"
echo "Press Enter to continue..."
read

./network-config-manager.sh load

echo ""
echo "=== Workflow Complete ==="
echo "Your network configuration has been updated according to the saved file."
echo ""
echo "Available commands:"
echo "  ./network-config-manager.sh save    - Save current config"
echo "  ./network-config-manager.sh view    - Edit config file"
echo "  ./network-config-manager.sh load    - Apply config (overwrites existing)"
echo "  ./network-config-manager.sh backup  - Create backup"
echo "  ./network-config-manager.sh help    - Show help"
