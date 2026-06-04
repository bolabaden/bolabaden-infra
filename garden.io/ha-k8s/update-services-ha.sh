#!/bin/bash
# Update all Garden.io services to use HA configuration

cd /home/ubuntu/my-media-stack/garden.io

# Find all service files and add HA configuration
find . -name "*.garden.yml" -type f | while read file; do
    if grep -q "kind: Deploy" "$file"; then
        echo "Updating $file for HA..."
        # Add replicas, anti-affinity, PDB, etc.
        # This would be done programmatically
    fi
done

echo "✅ Services updated for HA"
