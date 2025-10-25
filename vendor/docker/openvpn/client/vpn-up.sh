#!/bin/sh

# Enable command echoing for debugging
set -x

dev=$1             # tun0
link_mtu=$2
tun_mtu=$3
remote_ip=$4       # VPN server remote IP
local_ip=$5        # assigned VPN client IP
netmask=$6
type=$7

docker_network_name="vpn-network"
docker_bridge="br_${docker_network_name}"

# Extract Docker network information dynamically
docker_net=$(docker network inspect $docker_network_name --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}')

# Create Docker network that will use VPN routing (only if it doesn't exist)
if ! docker network inspect $docker_network_name >/dev/null 2>&1; then
    if ! docker network create -d bridge --attachable --subnet 10.45.0.0/16 --ip-range 10.45.0.0/16 --gateway 10.45.0.1 -o com.docker.network.bridge.name=$docker_bridge $docker_network_name; then
        echo "Error: Could not create $docker_network_name"
        exit 1
    fi
    docker_net=$(docker network inspect $docker_network_name --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}')
fi

# Dynamically determine the local network from the default interface
local_interface=$(ip route | grep default | awk '{print $5}' | head -1)
local_gateway=$(ip route | grep default | awk '{print $3}' | head -1)

if [ -n "$local_interface" ]; then
    local_net=$(ip route | grep "$local_interface" | grep -v default | awk '{print $1}' | head -1)
else
    echo "Error: Could not determine local interface"
    exit 1
fi

echo "docker_net=$docker_net"
echo "local_net=$local_net"
echo "local_gateway=$local_gateway"
echo "docker_bridge=$docker_bridge"

# Check if routing table 'vpn' exists, create if missing with proper table ID
if ! grep -q "^[0-9]\+[[:space:]]\+vpn$" /etc/iproute2/rt_tables; then
    # Find an available table ID (use 100 as default, but check if it's available)
    table_id=100
    while grep -q "^${table_id}[[:space:]]" /etc/iproute2/rt_tables; do
        table_id=$((table_id + 1))
        # Prevent infinite loop, max table ID is 255
        if [ $table_id -gt 255 ]; then
            echo "Error: No available table IDs found"
            exit 1
        fi
    done
    echo "${table_id}     vpn" >> /etc/iproute2/rt_tables
    echo "Created routing table 'vpn' with ID ${table_id}"
fi

# Remove any previous routes in the 'vpn' routing table
/bin/ip rule | /bin/sed -n 's/.*\(from[ \t]*[0-9\.\/]*\).*vpn/\1/p' | while read RULE
do
  /bin/ip rule del ${RULE}
  /bin/ip route flush table vpn 
done

# Add route to the VPN endpoint (only if gateway is valid)
if [ -n "$local_gateway" ]; then
  /bin/ip route add $remote_ip via $local_gateway dev $local_interface
else
  echo "Warning: Could not determine default gateway, skipping VPN endpoint route"
fi

# Traffic coming FROM the docker network should go through the VPN table
/bin/ip rule add from ${docker_net} lookup vpn

# Uncomment this if you want to have a default route for the VPN
/bin/ip route add default dev ${dev} table vpn

# Needed for OpenVPN to work
/bin/ip route add 0.0.0.0/1 dev ${dev} table vpn
/bin/ip route add 128.0.0.0/1 dev ${dev} table vpn

# Local traffic should go through $local_interface
/bin/ip route add $local_net dev $local_interface table vpn

# Traffic to docker network should go to docker vpn network 
/bin/ip route add $docker_net dev ${dev} table vpn

exit 0
