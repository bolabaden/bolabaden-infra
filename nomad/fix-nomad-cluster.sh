#!/bin/bash
# Script to fix Nomad cluster leader issue
# Run this on each Nomad server node

set -e

echo "=== Fixing Nomad Cluster Leader Issue ==="
echo ""

# Check current status
echo "Current Nomad server status:"
nomad server members 2>&1 || echo "Error querying servers"

echo ""
echo "Restarting Nomad on this node..."
sudo systemctl restart nomad

echo "Waiting for Nomad to start..."
sleep 5

echo "Checking Nomad status:"
sudo systemctl status nomad --no-pager | head -15

echo ""
echo "Checking for cluster leader..."
sleep 3
nomad server members 2>&1

echo ""
echo "If still no leader, check:"
echo "1. All Nomad servers can reach each other on ports 4647, 4648"
echo "2. Firewall rules allow communication between nodes"
echo "3. Nomad server configuration has correct retry_join addresses"
echo "4. At least 2 servers are running for quorum"

