#!/bin/bash
set -e

echo "=== Testing Go Infrastructure Deployment ==="
echo ""

# Set environment variables
export DOMAIN=bolabaden.org
export STACK_NAME=my-media-stack
export CONFIG_PATH=/home/ubuntu/my-media-stack/volumes
export ROOT_PATH=/home/ubuntu/my-media-stack
export SECRETS_PATH=/home/ubuntu/my-media-stack/secrets
export TS_HOSTNAME=$(hostname -s)

echo "Environment:"
echo "  DOMAIN=$DOMAIN"
echo "  STACK_NAME=$STACK_NAME"
echo "  TS_HOSTNAME=$TS_HOSTNAME"
echo ""

# Check if binary exists
if [ ! -f "./deploy" ]; then
    echo "ERROR: deploy binary not found. Building..."
    go build -o deploy .
fi

echo "Running deployment..."
sudo -E ./deploy

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Checking deployed containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

echo ""
echo "Checking networks..."
docker network ls | grep -E "(warp-nat-net|publicnet|backend|nginx_net|default)"

echo ""
echo "Checking Traefik dynamic config..."
if [ -f "$CONFIG_PATH/traefik/dynamic/failover-fallbacks.yaml" ]; then
    echo "✓ Traefik config exists"
    head -20 "$CONFIG_PATH/traefik/dynamic/failover-fallbacks.yaml"
else
    echo "✗ Traefik config not found"
fi

echo ""
echo "Checking HAProxy config..."
if [ -f "$CONFIG_PATH/haproxy/haproxy.cfg" ]; then
    echo "✓ HAProxy config exists"
    head -20 "$CONFIG_PATH/haproxy/haproxy.cfg"
else
    echo "✗ HAProxy config not found"
fi


