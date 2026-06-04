#!/bin/bash
# Script to fix all Nomad nodes and get them to join the cluster
# Run this on each node that needs to join

set -e

NODE_NAME=$(hostname -f)
echo "=== Fixing Nomad on $NODE_NAME ==="

# Check if Nomad is running
if ! systemctl is-active --quiet nomad; then
    echo "Starting Nomad service..."
    sudo systemctl start nomad
    sleep 5
fi

# Check Nomad status
echo "Nomad service status:"
sudo systemctl status nomad --no-pager | head -10

# Check if node is in cluster
echo ""
echo "Checking cluster membership..."
nomad node status 2>&1 || echo "Node not in cluster yet"

# Check server status if this is a server node
if grep -q "server.*enabled.*true" /etc/nomad.d/nomad.hcl 2>/dev/null; then
    echo ""
    echo "Server status:"
    nomad server members 2>&1 || echo "Cannot query servers"
fi

echo ""
echo "If node is not in cluster, check:"
echo "1. Nomad config has correct retry_join addresses"
echo "2. Firewall allows ports 4647, 4648"
echo "3. Network connectivity to other nodes"

