#!/bin/sh

# Enable command echoing for debugging
#set -x

dev=$1             # tun0
link_mtu=$2
tun_mtu=$3
remote_ip=$4       # VPN server remote IP
local_ip=$5        # assigned VPN client IP
netmask=$6
type=$7

echo "vpn-down.sh: dev=$1, link_mtu=$2, tun_mtu=$3, remote_ip=$4, local_ip=$5, netmask=$6, type=$7"

# Extract Docker network information dynamically
docker_net=$(docker network inspect vpn-network --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "172.18.0.0/16")

# Dynamically determine the local network from the default interface
local_interface=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$local_interface" ]; then
    local_net=$(ip route | grep "$local_interface" | grep -v default | awk '{print $1}' | head -1)
else
    echo "Error: Could not determine local interface"
    exit 1
fi

# Dynamically determine the default gateway
local_gateway=$(ip route | grep default | awk '{print $3}' | head -1)

echo "docker_net=$docker_net"
echo "local_gateway=$local_gateway"

# Remove all routes from the 'vpn' routing table
/bin/ip route flush table vpn

# Remove all ip rules that reference the 'vpn' table
# Extract just the rule specification without the rule number
/bin/ip rule | grep "lookup vpn" | sed 's/^[0-9]*:[ \t]*//' | while read RULE
do
    /bin/ip rule del ${RULE}
done

# Remove the specific route to the VPN endpoint (if it exists)
if [ -n "$local_gateway" ] && [ -n "$remote_ip" ]; then
    /bin/ip route del $remote_ip via $local_gateway dev $local_interface 2>/dev/null || true
fi

# Remove the routing table entry from /etc/iproute2/rt_tables (optional)
# Uncomment the following lines if you want to completely remove the vpn table
# sed -i '/^100[ \t]*vpn$/d' /etc/iproute2/rt_tables

echo "VPN routing cleanup completed"

exit 0
