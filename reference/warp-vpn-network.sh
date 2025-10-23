#!/bin/bash

set -x

# Configuration
NETWORK_NAME="vpn-network"
NETWORK_SUBNET="10.45.0.0/16"
NETWORK_GATEWAY="10.45.0.1"
WARP_IP="10.45.0.2"

# Create the custom network without automatic gateway
# We'll manage routing ourselves
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    docker network create \
        --driver bridge \
        --subnet=$NETWORK_SUBNET \
        --gateway=$NETWORK_GATEWAY \
        --opt com.docker.network.bridge.name=br_vpn \
        $NETWORK_NAME
fi

# Start Warp container with a fixed IP on our custom network
docker run -d \
    --name warp \
    --cap-add NET_ADMIN \
    --cap-add MKNOD \
    --cap-add AUDIT_WRITE \
    --sysctl net.ipv6.conf.all.disable_ipv6=1 \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv4.ip_forward=1 \
    --device /dev/net/tun \
    --network $NETWORK_NAME \
    --ip $WARP_IP \
    -e WARP_SLEEP=2 \
    -e WARP_LICENSE_KEY=${WARP_LICENSE_KEY} \
    -e TUNNEL_TOKEN=${TUNNEL_TOKEN} \
    -v ${CONFIG_PATH:-./configs}/warp/data:/var/lib/cloudflare-warp \
    caomingjun/warp:latest

# Wait for Warp to initialize
sleep 10

# Set up iptables rules on the host to route traffic from the custom network through Warp
# Get the bridge interface name
BRIDGE_INTERFACE=$(docker network inspect $NETWORK_NAME -f '{{index .Options "com.docker.network.bridge.name"}}')

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Set up NAT for the custom network through the Warp container
# This requires the Warp container to also forward traffic
sudo iptables -t nat -A POSTROUTING -s $NETWORK_SUBNET ! -d $NETWORK_SUBNET -j MASQUERADE

# Add a route on containers to use Warp as gateway
# This would need to be done inside each container that joins the network
echo "Containers on $NETWORK_NAME should add: ip route add default via $WARP_IP" 