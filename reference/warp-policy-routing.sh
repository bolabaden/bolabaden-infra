#!/bin/bash

set -x

# Configuration
NETWORK_NAME="vpn-network"
NETWORK_SUBNET="10.45.0.0/16"
NETWORK_GATEWAY="10.45.0.1"
WARP_NETWORK="warp-bridge"
WARP_SUBNET="172.30.0.0/16"

# Create the Warp bridge network
if ! docker network inspect $WARP_NETWORK >/dev/null 2>&1; then
    docker network create \
        --driver bridge \
        --subnet=$WARP_SUBNET \
        --opt com.docker.network.bridge.name=br_warp \
        $WARP_NETWORK
fi

# Create the VPN network (for containers that should use Warp)
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    docker network create \
        --driver bridge \
        --subnet=$NETWORK_SUBNET \
        --gateway=$NETWORK_GATEWAY \
        --opt com.docker.network.bridge.name=br_vpn \
        $NETWORK_NAME
fi

# Start Warp container on its own network
docker run -d \
    --name warp \
    --cap-add NET_ADMIN \
    --cap-add MKNOD \
    --cap-add AUDIT_WRITE \
    --sysctl net.ipv6.conf.all.disable_ipv6=1 \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv4.ip_forward=1 \
    --device /dev/net/tun \
    --network $WARP_NETWORK \
    -e WARP_SLEEP=2 \
    -e WARP_LICENSE_KEY=${WARP_LICENSE_KEY} \
    -e TUNNEL_TOKEN=${TUNNEL_TOKEN} \
    -v ${CONFIG_PATH:-./configs}/warp/data:/var/lib/cloudflare-warp \
    --restart always \
    caomingjun/warp:latest

# Connect Warp to the VPN network as well
docker network connect $NETWORK_NAME warp

# Wait for Warp to initialize
sleep 10

# Get Warp's IP on the VPN network
WARP_VPN_IP=$(docker inspect warp --format "{{.NetworkSettings.Networks.${NETWORK_NAME}.IPAddress}}")
echo "Warp IP on VPN network: $WARP_VPN_IP"

# Set up routing table (similar to OpenVPN setup)
if ! grep -q "^[0-9]\+[[:space:]]\+warp$" /etc/iproute2/rt_tables; then
    echo "200     warp" >> /etc/iproute2/rt_tables
fi

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Clear any existing rules
ip rule | grep "lookup warp" | sed 's/^[0-9]*:[ \t]*//' | while read RULE; do
    ip rule del ${RULE}
done
ip route flush table warp

# Add policy routing rule: traffic from VPN network goes through warp table
ip rule add from ${NETWORK_SUBNET} lookup warp

# In the warp table, route all traffic to the Warp container
ip route add default via $WARP_VPN_IP table warp

# Add local network routes to warp table (adjust as needed)
LOCAL_NET=$(ip route | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+" | grep -v docker | head -1 | awk '{print $1}')
if [ -n "$LOCAL_NET" ]; then
    ip route add $LOCAL_NET dev $(ip route | grep "$LOCAL_NET" | awk '{print $3}') table warp
fi

# Set up NAT on the Warp container
docker exec warp sh -c "
    # Enable IP forwarding inside Warp container
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Set up NAT for incoming traffic from VPN network
    iptables -t nat -A POSTROUTING -s ${NETWORK_SUBNET} -j MASQUERADE
    iptables -A FORWARD -s ${NETWORK_SUBNET} -j ACCEPT
    iptables -A FORWARD -d ${NETWORK_SUBNET} -j ACCEPT
"

echo "Policy-based routing setup complete!"
echo "Containers on $NETWORK_NAME will route through Warp" 