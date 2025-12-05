#!/bin/bash
#
# Setup Docker daemon configuration for log rotation and resource management
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"
BACKUP_DIR="/etc/docker/backups"

echo "Setting up Docker daemon configuration..."

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# Backup existing config if it exists
if [ -f "$DOCKER_DAEMON_CONFIG" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "Backing up existing daemon.json to $BACKUP_DIR/daemon.json.$TIMESTAMP"
    sudo cp "$DOCKER_DAEMON_CONFIG" "$BACKUP_DIR/daemon.json.$TIMESTAMP"
fi

# Copy new config
echo "Installing new daemon.json..."
sudo cp "$SCRIPT_DIR/../configs/docker-daemon.json" "$DOCKER_DAEMON_CONFIG"

# Validate JSON
if ! sudo python3 -m json.tool "$DOCKER_DAEMON_CONFIG" > /dev/null 2>&1; then
    echo "ERROR: Invalid JSON in daemon.json"
    if [ -f "$BACKUP_DIR/daemon.json.$TIMESTAMP" ]; then
        echo "Restoring backup..."
        sudo cp "$BACKUP_DIR/daemon.json.$TIMESTAMP" "$DOCKER_DAEMON_CONFIG"
    fi
    exit 1
fi

# Reload Docker daemon
echo "Reloading Docker daemon..."
sudo systemctl daemon-reload
sudo systemctl reload docker || sudo systemctl restart docker

echo "Docker daemon configuration updated successfully!"
echo "Log rotation is now enabled: max-size=10m, max-file=3, compress=true"

