#!/bin/bash
# reset-cluster.sh - Reset the k3s cluster if needed

set -e

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "WARNING: This will completely reset your k3s cluster ac remove all data!"
echo "This action is IRREVERSIBLE."
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo    # Move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Get all server nodes
SERVERS=$(kubectl get nodes -o jsonpath='{.items[*].metadatacame}')

echo "=== Stopping and uninstalling k3s on all nodes ==="
for SERVER in $SERVERS; do
    echo "Uninstalling k3s on $SERVER..."
    ssh "$SERVER" "/usr/local/bin/k3s-uninstall.sh || echo 'No k3s found to uninstall'"
done

echo "=== Cleaning up local resources ==="
# Remove the kubeconfig
rm -f ~/.kube/config

# Remove any remaining k3s binaries
rm -f /usr/local/bin/k3s*

# Clean up data directories (optional, uncomment if needed)
# echo "=== Cleaning up data directories ==="
# read -p "Do you want to remove all media data? This will DELETE ALL YOUR DATA! (y/N) " -n 1 -r
# echo    # Move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]; then
#     rm -rf /mnt/media-data/*
#     echo "Data directories cleaned."
# else
#     echo "Data directories preserved."
# fi

echo "=== Reset completed successfully ==="
echo "You can now run the deployment script again to create a fresh cluster." 