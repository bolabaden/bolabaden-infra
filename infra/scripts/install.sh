#!/bin/bash
set -euo pipefail

# Install Constellation Agent systemd service
# This script installs the agent on a node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Installing Constellation Agent..."

# Build the agent binary
echo "Building agent binary..."
cd "$PROJECT_ROOT/infra"
go build -o /usr/local/bin/constellation-agent ./cmd/agent

# Create directories
mkdir -p /opt/constellation/{data,volumes,secrets}
mkdir -p /opt/constellation/data/raft/{logs,stable,snapshots}

# Install systemd service
echo "Installing systemd service..."
cp "$PROJECT_ROOT/infra/systemd/constellation-agent.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable constellation-agent.service

echo "Constellation Agent installed successfully!"
echo "Start with: systemctl start constellation-agent"
echo "Check status with: systemctl status constellation-agent"
echo "View logs with: journalctl -u constellation-agent -f"

