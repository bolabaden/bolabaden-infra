#!/bin/sh
# Containerized VIP Router for Anycast Routing
# This script runs inside a container with NET_ADMIN capabilities

set -e

# Configuration
SERVICE_VIP=${SERVICE_VIP:-"100.100.10.10/32"}
LOCAL_PORT=${LOCAL_PORT:-"8443"}
HOSTNAME=${HOSTNAME:-$(hostname)}

echo "Starting VIP Router on $HOSTNAME"
echo "Service VIP: $SERVICE_VIP"
echo "Local Port: $LOCAL_PORT"

# Install required packages
apk add --no-cache iptables iproute2 tailscale

# Start Tailscale
echo "Starting Tailscale..."
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
TAILSCALED_PID=$!

# Wait for tailscaled to start
sleep 5

# Connect to Headscale
echo "Connecting to Headscale..."
tailscale up \
  --hostname="$HOSTNAME" \
  --advertise-routes="$SERVICE_VIP" \
  --advertise-exit-node=false \
  --login-server="http://headscale:50443" \
  --authkey="$HEADSCALE_AUTHKEY"

# Wait for connection
sleep 10

# Setup VIP routing
echo "Setting up VIP routing..."

# Add VIP to loopback interface
ip addr add $SERVICE_VIP dev lo

# Setup iptables for VIP NAT hairpinning
iptables -t nat -A PREROUTING -d ${SERVICE_VIP%/*} -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:$LOCAL_PORT
iptables -t nat -A PREROUTING -d ${SERVICE_VIP%/*} -p tcp --dport 80 -j DNAT --to-destination 127.0.0.1:80

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Setup routing table for VIP
ip route add ${SERVICE_VIP%/*} dev lo table 100
ip rule add to ${SERVICE_VIP%/*} table 100

echo "VIP Router setup complete on $HOSTNAME"

# Health check function
health_check() {
    while true; do
        # Check if we can reach the local service
        if ! nc -z 127.0.0.1 $LOCAL_PORT 2>/dev/null; then
            echo "WARNING: Local service on port $LOCAL_PORT is not responding"
            # Optionally withdraw route advertisement
            # tailscale set --advertise-routes=""
        else
            echo "Health check passed: service on port $LOCAL_PORT is responding"
        fi
        sleep 30
    done
}

# Start health check in background
health_check &

# Keep container running
wait $TAILSCALED_PID 