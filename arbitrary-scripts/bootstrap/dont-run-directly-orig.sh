#!/bin/bash
set -euo pipefail
#set -x

# Use $1 if provided, otherwise fall back to hostname command (not /etc/hostname which might be FQDN)
HOSTNAME_ARG="${1:-$(hostname -s 2>/dev/null || hostname | cut -d'.' -f1)}"

# Strip any existing domain suffixes to get just the short hostname
HOSTNAME_SHORT=$(echo "$HOSTNAME_ARG" | cut -d'.' -f1)

# Set hostname and FQDN
DOMAIN="bolabaden.org"
FQDN="${HOSTNAME_SHORT}.${DOMAIN}"

# Set the hostname properly
hostnamectl set-hostname "$HOSTNAME_SHORT"
echo "$HOSTNAME_SHORT" >/etc/hostname

# Update /etc/hosts - first remove any existing entries for this hostname to avoid duplicates
sed -i "/127.0.1.1.*${HOSTNAME_SHORT}/d" /etc/hosts
echo "127.0.1.1 ${FQDN} ${HOSTNAME_SHORT}" >>/etc/hosts

echo "[*] Hostname set to: $HOSTNAME_SHORT (FQDN: $FQDN)"

echo "[*] Updating package lists and upgrading system..."
apt-get update -qq
apt-get autoremove -y -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

echo "[*] Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl wget git htop nano vim unzip jq bc yq \
    iptables-persistent python3 python3-pip \
    nodejs npm python3-venv pipx plocate whois sshpass ansible \
    dnsutils host 2>&1 | grep -v "^Preconfiguring" || true

apt-get autoremove -y -qq
echo "  [OK] Essential packages installed"

OS_TYPE=$(grep -w "ID" /etc/os-release | cut -d "=" -f 2 | tr -d '"')
ARCH=$(uname -m)

echo "[*] Installing Docker..."

# Remove any existing conflicting/obsolete Docker packages
echo "  [*] Removing conflicting Docker packages..."
DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true

# Clean up any existing Docker apt sources before installation
echo "  [*] Cleaning existing Docker apt sources..."
rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources

# Add Docker's official GPG key:
echo "  [*] Adding Docker GPG key and repository..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
    tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "  [*] Installing Docker packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ensure only one Docker source file exists (prefer newer .sources format)
if [[ -f /etc/apt/sources.list.d/docker.sources && -f /etc/apt/sources.list.d/docker.list ]]; then
    echo "  [*] Removing duplicate docker.list (keeping docker.sources)..."
    rm -f /etc/apt/sources.list.d/docker.list
fi

# Verify Docker installation
if ! [ -x "$(command -v docker)" ]; then
    echo "  [WARN] Docker not found, trying fallback installation methods..."
    DOCKER_VERSION="27.0"
    curl -fsSL https://releases.rancher.com/install-docker/${DOCKER_VERSION}.sh | bash 2>&1 | grep -v "^$" || true

    if ! [ -x "$(command -v docker)" ]; then
        echo "  [WARN] First fallback failed, trying second method..."
        curl -fsSL https://get.docker.com | sh -s -- --version ${DOCKER_VERSION} 2>&1 | grep -v "^$"

        if ! [ -x "$(command -v docker)" ]; then
            echo "  [ERROR] All Docker installation methods failed"
            exit 1
        fi
    fi

    # Clean up duplicates after fallback installation methods
    if [[ -f /etc/apt/sources.list.d/docker.sources && -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "  [*] Removing duplicate docker.list after fallback installation..."
        rm -f /etc/apt/sources.list.d/docker.list
    fi
fi

echo "  [OK] Docker installed: $(docker --version)"

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

echo "[*] Configuring SSH settings..."
# Backup SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Enable password authentication
if grep -qE '^\s*PasswordAuthentication\s+' /etc/ssh/sshd_config; then
    sed -i 's/^\s*PasswordAuthentication\s.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    echo 'PasswordAuthentication yes' >>/etc/ssh/sshd_config
fi

# Enable pubkey authentication (should already be enabled by default)
if grep -qE '^\s*PubkeyAuthentication\s+' /etc/ssh/sshd_config; then
    sed -i 's/^\s*PubkeyAuthentication\s.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
    echo 'PubkeyAuthentication yes' >>/etc/ssh/sshd_config
fi

# Allow root login (if needed)
if grep -qE '^\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
    sed -i 's/^\s*PermitRootLogin\s.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
    echo 'PermitRootLogin yes' >>/etc/ssh/sshd_config
fi

# Test SSH config before applying
if sshd -t 2>/dev/null; then
    echo "  [OK] SSH configuration is valid"
    systemctl reload sshd || systemctl restart sshd
    echo "  [OK] SSH service reloaded"
else
    echo "  [ERROR] SSH configuration test failed, restoring backup"
    cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config 2>/dev/null || true
fi

echo "[*] Configuring users (root, ubuntu)..."
for USER in root ubuntu; do
    echo "  [*] Setting up user: $USER"

    # Create user if doesn't exist
    if ! id "$USER" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo "$USER"
        echo "    [OK] User $USER created"
    else
        # Ensure user is in sudo group
        usermod -aG sudo "$USER" 2>/dev/null || true
        echo "    [INFO] User $USER already exists"
    fi

    # Add to docker group
    usermod -aG docker "$USER" 2>/dev/null || echo "    [WARN] Could not add $USER to docker group"

    HOME_DIR=$(eval echo "~$USER")

    # Setup Docker directory
    mkdir -p "$HOME_DIR/.docker"
    chown "$USER":"$USER" "$HOME_DIR/.docker" -R 2>/dev/null || true
    chmod g+rwx "$HOME_DIR/.docker" -R 2>/dev/null || true

    # Setup SSH keys for each user
    mkdir -p "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"
    chown "$USER":"$USER" "$HOME_DIR/.ssh"

    # Download SSH keys from GitHub and append to authorized_keys (avoiding duplicates)
    echo "    [*] Fetching SSH keys from GitHub..."
    GITHUB_KEYS=$(curl -fsSL --max-time 10 "https://github.com/th3w1zard1.keys" 2>/dev/null || true)
    if [ -n "$GITHUB_KEYS" ]; then
        touch "$HOME_DIR/.ssh/authorized_keys"
        echo "$GITHUB_KEYS" | while read -r key; do
            if [ -n "$key" ] && ! grep -Fxq "$key" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null; then
                echo "$key" >>"$HOME_DIR/.ssh/authorized_keys"
            fi
        done
        echo "    [OK] SSH keys imported from GitHub"
    else
        echo "    [WARN] Could not fetch SSH keys from GitHub"
    fi

    chmod 600 "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null || true
    chown "$USER":"$USER" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null || true

    # Set password for the user (same hash from your Ansible config)
    echo "$USER:\$6\$pWurw/L0tau67C7g\$kiM8cWIAg97/je2BQLKAm/FRuTz1Xu.g0UC59HuqK0d2jkLqw1FcDcB8YH.Iv0PEh3DhyMPosfmEWCi/AnmrX." | chpasswd -e
    echo "    [OK] Password configured"

    # Run pipx ensurepath and try to enable pipx argcomplete for each user
    echo "    [*] Setting up pipx for $USER..."
    sudo -u "$USER" -H bash -c '
        pipx ensurepath 2>/dev/null || true
        
        # Try to register argcomplete
        if command -v register-python-argcomplete >/dev/null 2>&1; then
            eval "$(register-python-argcomplete pipx 2>/dev/null)" || true
        elif command -v register-python-argcomplete3 >/dev/null 2>&1; then
            eval "$(register-python-argcomplete3 pipx 2>/dev/null)" || true
        fi
    ' 2>/dev/null || echo "    [WARN] pipx argcomplete setup skipped"

    # Install uv via pipx
    sudo -u "$USER" -H bash -c 'pipx install uv 2>/dev/null' || echo "    [WARN] uv installation skipped"
    echo "    [OK] User $USER setup complete"
done
echo "  [OK] All users configured"

# Enable and start services
systemctl enable docker.service
systemctl enable containerd.service
systemctl start docker.service
systemctl start containerd.service
# --- Detect primary interface automatically ---
IFACE="$(ip route show default 0.0.0.0/0 | awk '{print $5}' | head -n1)"
echo "[*] Detected primary interface: $IFACE"

echo "[*] Optimizing NIC offload settings for Tailscale..."
# Try to enable each setting individually, some may not be supported by all NICs
ethtool -K "$IFACE" gro on 2>/dev/null || echo "  [WARN] GRO not supported on $IFACE"
ethtool -K "$IFACE" lro off 2>/dev/null || echo "  [WARN] LRO not supported on $IFACE"
ethtool -K "$IFACE" rx-udp-gro-forwarding on 2>/dev/null || echo "  [WARN] rx-udp-gro-forwarding not supported on $IFACE"
ethtool -K "$IFACE" tx-udp-segmentation on 2>/dev/null || echo "  [WARN] tx-udp-segmentation not supported on $IFACE"
echo "  [OK] NIC optimizations completed (warnings for unsupported features are normal)"

echo "[*] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "[*] Enabling IP forwarding..."
cat >/etc/sysctl.d/99-tailscale.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf || true

echo "[*] Updating apt..."
apt-get update -qq

# --- CONFIGURE TAILSCALE ---
TAILSCALE_AUTH_KEY="b6ba9400930b4021eda1d50b6067615bdc3fbcc8a92429f9"
TAILSCALE_LOGIN_SERVER="https://headscale.${DOMAIN:-bolabaden.org}"

# Configure DNS settings for Tailscale to prevent DNS warnings
echo "[*] Configuring DNS settings..."
mkdir -p /etc/systemd/resolved.conf.d
cat >/etc/systemd/resolved.conf.d/tailscale.conf <<EOF
[Resolve]
DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
FallbackDNS=1.1.1.1 1.0.0.1
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
EOF

# Restart systemd-resolved if it's running
if systemctl is-active --quiet systemd-resolved; then
    systemctl restart systemd-resolved
    echo "  [OK] DNS configured via systemd-resolved"
else
    # Fallback to /etc/resolv.conf if systemd-resolved is not running
    echo "  [INFO] systemd-resolved not active, configuring /etc/resolv.conf"
    cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi

echo "[*] Resetting any existing Tailscale session..."
tailscale down || true

echo "[*] Bringing up Tailscale with exit node advertisement..."

# Use the short hostname (not FQDN) to avoid nested domains
TAILSCALE_HOSTNAME="${HOSTNAME_SHORT:-$(hostname -s)}"

# Bring up tailscale with exit node advertisement
TAILSCALE_UP_COMMAND="tailscale up \
  --login-server=${TAILSCALE_LOGIN_SERVER} \
  --hostname=${TAILSCALE_HOSTNAME} \
  --operator=ubuntu \
  --auth-key=${TAILSCALE_AUTH_KEY} \
  --advertise-exit-node \
  --accept-dns=true \
  --reset"

echo "  [CMD] $TAILSCALE_UP_COMMAND"
eval "$TAILSCALE_UP_COMMAND"

echo "[*] Waiting for Tailscale to stabilize..."
sleep 3

# Show status
echo "[*] Tailscale status:"
tailscale status

# Verify DNS is working
echo "[*] Verifying DNS resolution..."
if host google.com >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1 || dig google.com >/dev/null 2>&1; then
    echo "  [OK] DNS resolution is working"
else
    echo "  [WARN] DNS resolution may have issues, but continuing..."
fi

# Node tools
# Install node globally with n
curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n
chmod +x /usr/local/bin/n

# Install LTS version of node globally
n lts

# Security updates
cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Set timezone dynamically: use $TZ if set, otherwise detect via GeoIP
if [ -n "${TZ:-}" ]; then
    echo "Setting timezone from \$TZ: $TZ"
    timedatectl set-timezone "$TZ"
else
    # Try to get timezone from ipapi.co (fallback: ipinfo.io)
    TZ_GEO=$(curl -fsSL --max-time 5 https://ipapi.co/timezone 2>/dev/null)
    if [ -z "$TZ_GEO" ]; then
        TZ_GEO=$(curl -fsSL --max-time 5 https://ipinfo.io/timezone 2>/dev/null)
    fi
    if [ -n "$TZ_GEO" ]; then
        echo "Setting timezone from GeoIP: $TZ_GEO"
        timedatectl set-timezone "$TZ_GEO"
    else
        echo "Could not determine timezone from \$TZ or GeoIP. Skipping timezone configuration."
    fi
fi

# Restart SSH service
#systemctl restart sshd

# Install Nomad and Consul
echo "[*] Installing HashiCorp Nomad and Consul..."
rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null || true
apt-get update -qq
apt-get install -y -qq wget gpg coreutils

echo "  [*] Adding HashiCorp GPG key..."
wget -4 -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
    tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

echo "  [*] Installing Nomad and Consul packages..."
apt-get update -qq
apt-get install -y -qq nomad consul consul-cni

echo "  [*] Installing CNI plugins..."
export ARCH_CNI=$([ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.6.2
curl -fsSL -o /tmp/cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}.tgz"
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz
rm -f /tmp/cni-plugins.tgz
echo "    [OK] CNI plugins installed to /opt/cni/bin"

echo "  [*] Configuring bridge networking for Nomad..."
modprobe br_netfilter
echo 1 >/proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 >/proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 >/proc/sys/net/bridge/bridge-nf-call-iptables

mkdir -p /etc/sysctl.d
cat >/etc/sysctl.d/bridge.conf <<EOF
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system >/dev/null 2>&1

echo "    [OK] Bridge networking configured"
echo "    [INFO] cgroup controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"

# Clean up any old nomad binary in /usr/local/bin
rm -f /usr/local/bin/nomad 2>/dev/null || true

echo "  [OK] Nomad version: $(nomad -v)"

echo "[*] Configuring Nomad..."
mkdir -p /nomad/{data,log} /etc/nomad.d
tee /etc/nomad.d/nomad.hcl >/dev/null <<'EOF'
datacenter = "dc1"  # "Nomad clusters can scale horizontally for increased capacity."
data_dir = "/nomad/data/"
bind_addr = "0.0.0.0"  # "Bind to all interfaces for multi-node communication."
log_level = "DEBUG"  # "Set the log level to DEBUG for more detailed logging."
log_json = true  # "Enable JSON logging for better machine readability."
log_file = "/nomad/log/nomad.log"  # "Set the log file path."
log_rotate_bytes = 10485760  # "Rotate the log file when it reaches 10MB."
log_rotate_max_files = 5  # "Keep up to 5 rotated log files."

server {
  enabled = true  # "Servers talk to each other and use a leader/follower load balancing method for HA."
  bootstrap_expect = 1  # "Create a multi-server (HA) setup. Prepare, for example, three nodes... but for five nodes, set bootstrap_expect to 5 for quorum." Adapted from  for odd-number quorum to avoid SPOF.
  server_join {
    retry_join = [
      "170.9.225.137:4647",
      "149.130.219.117:4647",
      "149.130.222.229:4647",
      "150.136.84.225:4647",
      "172.245.88.16:4647"
    ]
  }
}

client {
  enabled = true  # "A single client process can handle running many allocations on a single node."
  node_class = "balanced"  # Custom class for load spreading; "Nomad uses a bin packing algorithm, which means it tries to utilize all of a node's resources before placing tasks on a different node."
}

advertise {
  http = "{{ GetPrivateIP }}:4646"
  rpc  = "{{ GetPrivateIP }}:4647"
  serf = "{{ GetPrivateIP }}:4648"
}

consul {
  address = "consul:8500"  # "Nomad integrates with Consul to provide service discovery and monitoring."  Assuming Consul agent on localhost.
  auto_advertise = true  # "Nomad can register services with Consul."
  server_service_name = "nomad"  # "Consul allows services to easily register themselves in a central catalog."
  client_service_name = "nomad-client"  # "Nomad integrates with Consul to provide service discovery."
}

telemetry {
  collection_interval = "1s"  # For monitoring CPU/RAM balance; "Optimize the raft_multiplier."
  publish_allocation_metrics = true  # "Nomad does not seem to balance the allocations across the clients... but with telemetry, it can monitor usage."
}
EOF

echo "  [OK] Nomad configuration written to /etc/nomad.d/nomad.hcl"

echo "[*] Starting and enabling Nomad service..."
systemctl daemon-reload
systemctl restart nomad
systemctl enable nomad

echo "  [*] Waiting for Nomad to start..."
sleep 5

echo "  [*] Nomad server members:"
nomad server members 2>/dev/null || echo "    [INFO] Server members check skipped (may not be clustered yet)"

echo "  [*] Nomad node status:"
nomad node status 2>/dev/null || echo "    [INFO] No nodes found yet"

echo "  [OK] Nomad configured and running"

# Configure swap file (if not already present)
echo "[*] Configuring swap file..."
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # Add to fstab if not already present
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    fi
    echo "  [OK] 4GB swap file created and enabled"
else
    echo "  [INFO] Swap file already exists, skipping creation"
    swapon /swapfile 2>/dev/null || echo "  [INFO] Swap already active"
fi

# Final message with comprehensive status
echo ""
echo "============================================"
echo "  VPS Server Setup Complete!"
echo "============================================"
echo "  Hostname: ${HOSTNAME_SHORT}"
echo "  FQDN: ${FQDN}"
echo "  Tailscale: Connected as ${TAILSCALE_HOSTNAME}"
echo "  Docker: $(docker --version 2>/dev/null || echo 'Installed')"
echo "  Nomad: $(nomad -v 2>/dev/null || echo 'Installed')"
echo "============================================"
echo ""
echo "VPS Server '${HOSTNAME_SHORT}' is ready!" | tee /var/log/cloud-init-complete.log
