#!/bin/bash

# Install NFS server
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

# Get the absolute path of my-media-stack
MEDIA_STACK_PATH="/home/brunner56/my-media-stack"

# Add the export to /etc/exports
echo "$MEDIA_STACK_PATH *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Export the filesystem
sudo exportfs -ra

echo "NFS server setup complete. The entire $MEDIA_STACK_PATH directory is now shared."
echo "On other nodes, mount using:"
echo "sudo mount \$(hostname -I | awk '{print \$1}'):$MEDIA_STACK_PATH $MEDIA_STACK_PATH"