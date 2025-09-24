#!/bin/bash
set -euo pipefail
#set -x

# Set hostname and FQDN
hostnamectl set-hostname "$1"
DOMAIN="bolabaden.org"
echo "$1.${DOMAIN:-bolabaden.org}" > /etc/hostname
echo "127.0.1.1 $1.${DOMAIN:-bolabaden.org} $1" >> /etc/hosts

apt-get update
apt-get autoremove -y
apt-get upgrade -y

apt-get install -y curl wget git htop nano vim unzip jq bc yq \
    iptables-persistent python3 python3-pip \
    nodejs npm python3-venv pipx plocate whois sshpass ansible python3-pip -y

apt-get autoremove -y

OS_TYPE=$(grep -w "ID" /etc/os-release | cut -d "=" -f 2 | tr -d '"')
ARCH=$(uname -m)
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove -y $pkg; done
# Add Docker's official GPG key:
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
if ! [ -x "$(command -v docker)" ]; then
  DOCKER_VERSION="27.0"
  curl -s https://releases.rancher.com/install-docker/${DOCKER_VERSION}.sh | bash || true
  if ! [ -x "$(command -v docker)" ]; then
      curl -s https://get.docker.com | sh -s -- --version ${DOCKER_VERSION} 2>&1
      if ! [ -x "$(command -v docker)" ]; then
          echo "Automated Docker installation failed."
          exit 1
      fi
  fi
fi

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Enable password authentication
grep -qE '^\s*PasswordAuthentication\s+' /etc/ssh/sshd_config && \
  sed -i 's/^\s*PasswordAuthentication\s.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || \
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

# Enable pubkey authentication (should already be enabled by default)
grep -qE '^\s*PubkeyAuthentication\s+' /etc/ssh/sshd_config && \
  sed -i 's/^\s*PubkeyAuthentication\s.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || \
  echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# Allow root login (if needed)
grep -qE '^\s*PermitRootLogin\s+' /etc/ssh/sshd_config && \
  sed -i 's/^\s*PermitRootLogin\s.*/PermitRootLogin yes/' /etc/ssh/sshd_config || \
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

for USER in root ubuntu; do
    useradd -m -s /bin/bash -G sudo "$USER" || true
    usermod -aG docker "$USER" || true
    HOME_DIR=$(eval echo "~$USER")
    mkdir -p "$HOME_DIR/.docker"
    chown "$USER":"$USER" "$HOME_DIR/.docker" -R || true
    chmod g+rwx "$HOME_DIR/.docker" -R || true

    # Setup SSH keys for each user
    mkdir -p "$HOME_DIR/.ssh"
    chmod 700 "$HOME_DIR/.ssh"
    chown "$USER":"$USER" "$HOME_DIR/.ssh"

    # Download SSH keys from GitHub and append to authorized_keys (avoiding duplicates)
    GITHUB_KEYS=$(curl -s "https://github.com/th3w1zard1.keys" 2>/dev/null || true)
    if [ -n "$GITHUB_KEYS" ]; then
        echo "$GITHUB_KEYS" | while read -r key; do
            if [ -n "$key" ] && ! grep -Fxq "$key" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null; then
                echo "$key" >> "$HOME_DIR/.ssh/authorized_keys"
            fi
        done
    fi

    chmod 600 "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null || true
    chown "$USER":"$USER" "$HOME_DIR/.ssh/authorized_keys" 2>/dev/null || true

    # Set password for the user (same hash from your Ansible config)
    echo "$USER:\$6\$pWurw/L0tau67C7g\$kiM8cWIAg97/je2BQLKAm/FRuTz1Xu.g0UC59HuqK0d2jkLqw1FcDcB8YH.Iv0PEh3DhyMPosfmEWCi/AnmrX." | chpasswd -e

    # Run pipx ensurepath and try to enable pipx argcomplete for each user
    sudo -u "$USER" -H bash -c '
        set -x

        pipx ensurepath
        output=$(register-python-argcomplete pipx 2>&1)
        if ! eval "$output"; then
            echo "register-python-argcomplete failed:"
            echo "Output from register-python-argcomplete:"
            echo "$output"
            output2=$(register-python-argcomplete3 pipx 2>&1)
            if ! eval "$output2"; then
                echo "Both register-python-argcomplete and register-python-argcomplete3 failed:"
                echo "Output from register-python-argcomplete:"
                echo "$output"
                echo "Output from register-python-argcomplete3:"
                echo "$output2"
            fi
        fi
    '
    sudo -u "$USER" -H bash -c 'pipx install uv'
done

# Enable and start services
systemctl enable docker.service
systemctl enable containerd.service
systemctl start docker.service
systemctl start containerd.service

# One-command install, from https://tailscale.com/download/
curl -fsSL https://tailscale.com/install.sh | sh
# Set sysctl settings for IP forwarding (useful when configuring an exit node)
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf
# Generate an auth key from your Admin console
# tailscale: https://login.tailscale.com/admin/settings/keys
# headscale: https://headscale.${DOMAIN:-bolabaden.org}/web/settings.html
TAILSCALE_AUTH_KEY="b6ba9400930b4021eda1d50b6067615bdc3fbcc8a92429f9"
TAILSCALE_LOGIN_SERVER="https://headscale.${DOMAIN:-bolabaden.org}"  # default: https://controlplane.tailscale.com
tailscale down || true
TAILSCALE_UP_COMMAND="tailscale up --login-server https://headscale.${DOMAIN:-bolabaden.org} --hostname $(hostname) --operator $USER --auth-key=$TAILSCALE_AUTH_KEY --reset"
eval $TAILSCALE_UP_COMMAND
tailscale status

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

# Nomad
rm -rvf /usr/share/keyrings/hashicorp-archive-keyring.gpg
apt-get update && apt-get install -y wget gpg coreutils
wget -4 -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| tee /etc/apt/sources.list.d/hashicorp.list

apt-get update && apt-get install -y nomad


export ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.6.2
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}".tgz && \
  mkdir -p /opt/cni/bin && \
  tar -C /opt/cni/bin -xzf cni-plugins.tgz

apt-get install -y consul-cni consul

modprobe br_netfilter
ls /proc/sys/net/bridge -l
echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

mkdir -p /etc/sysctl.d
echo "net.bridge.bridge-nf-call-arptables = 1" >> /etc/sysctl.d/bridge.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/bridge.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/bridge.conf

sysctl --system

cat /sys/fs/cgroup/cgroup.controllers

rm -rvf /usr/local/bin/nomad

nomad -v

tee /etc/nomad.d/nomad.hcl > /dev/null <<'EOF'
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

systemctl restart nomad && systemctl enable nomad

nomad server members

nomad node status

nomad node status -self

fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Final message
echo "VPS Server '$1' is ready!" | tee /var/log/cloud-init-complete.log
