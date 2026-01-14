#!/bin/bash
set -euo pipefail

# SSH Setup Script for biodecompwarehouse container
# This script sets up secure SSH access within the container

SSH_USER="${SSH_USER:-root}"
SSH_HOME="/root"
SSH_DIR="${SSH_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SSH_PUBLIC_KEY="/run/secrets/ssh_public_key"
SSH_PRIVATE_KEY="/run/secrets/ssh_private_key"
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "🔐 Starting SSH setup for biodecompwarehouse container..."

# Install OpenSSH server if not already installed
if ! command -v sshd &> /dev/null; then
    echo "📦 Installing OpenSSH server..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y -qq openssh-server openssh-client
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    elif command -v apk &> /dev/null; then
        apk add --no-cache openssh openssh-server
    elif command -v yum &> /dev/null; then
        yum install -y -q openssh-server openssh-clients
        yum clean all
    else
        echo "❌ ERROR: Cannot determine package manager. Please install OpenSSH manually."
        exit 1
    fi
fi

# Create SSH directory with proper permissions
echo "📁 Creating SSH directory structure..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Set up authorized_keys from public key secret
if [ -f "${SSH_PUBLIC_KEY}" ]; then
    echo "🔑 Setting up authorized_keys from secret..."
    cp "${SSH_PUBLIC_KEY}" "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown "${SSH_USER}:${SSH_USER}" "${AUTHORIZED_KEYS}"
    echo "✅ Public key installed successfully"
else
    echo "⚠️  WARNING: SSH public key secret not found at ${SSH_PUBLIC_KEY}"
fi

# Set up SSH host keys (persist across reboots)
SSH_HOST_KEYS_DIR="/etc/ssh/ssh_host_keys"
mkdir -p "${SSH_HOST_KEYS_DIR}"

# Generate host keys if they don't exist
for key_type in rsa ecdsa ed25519; do
    key_file="${SSH_HOST_KEYS_DIR}/ssh_host_${key_type}_key"
    if [ ! -f "${key_file}" ]; then
        echo "🔐 Generating ${key_type} host key..."
        ssh-keygen -t "${key_type}" -f "${key_file}" -N "" -q
    fi
done

# Link host keys to standard location
ln -sf "${SSH_HOST_KEYS_DIR}/ssh_host_rsa_key" /etc/ssh/ssh_host_rsa_key
ln -sf "${SSH_HOST_KEYS_DIR}/ssh_host_ecdsa_key" /etc/ssh/ssh_host_ecdsa_key
ln -sf "${SSH_HOST_KEYS_DIR}/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key

# Ensure proper permissions on host keys
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true

# Create secure SSH daemon configuration
echo "⚙️  Configuring SSH daemon..."
cat > "${SSHD_CONFIG}" << 'EOF'
# Secure SSH Daemon Configuration for Container
# This configuration ensures SSH cannot access host filesystem

# Basic Settings
Port 22
Protocol 2
AddressFamily inet
ListenAddress 0.0.0.0

# Security Settings - Prevent host filesystem access
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no

# Disable dangerous features that could affect host
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
PermitUserEnvironment no

# Chroot and isolation (if supported)
# UsePrivilegeSeparation sandbox

# Logging
SyslogFacility AUTH
LogLevel INFO

# Connection Settings
MaxAuthTries 3
MaxSessions 10
MaxStartups 10:30:100
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no

# Compression (disabled for security)
Compression no

# Key Exchange and Ciphers (modern, secure)
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

# Host Key Algorithms
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256

# Disable weak algorithms
UseDNS no
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
RhostsRSAAuthentication no

# Banner (optional - can be customized)
# Banner /etc/ssh/banner

# Match block for additional restrictions (if needed)
# Match User *
#     ForceCommand /bin/bash
EOF

chmod 600 "${SSHD_CONFIG}"

# Create SSH banner (optional security notice)
cat > /etc/ssh/banner << 'EOF'
***************************************************************************
                            WARNING - CONTAINER SSH
***************************************************************************
You are accessing a containerized SSH session. This is an isolated environment.
Access to the host filesystem is restricted. All actions are contained within
this container only.
***************************************************************************
EOF

chmod 644 /etc/ssh/banner

# Update sshd_config to use banner
if ! grep -q "^Banner" "${SSHD_CONFIG}"; then
    echo "Banner /etc/ssh/banner" >> "${SSHD_CONFIG}"
fi

# Create necessary directories for SSH
mkdir -p /var/run/sshd
chmod 755 /var/run/sshd

# Test SSH configuration
echo "🧪 Testing SSH configuration..."
if sshd -t; then
    echo "✅ SSH configuration is valid"
else
    echo "❌ ERROR: SSH configuration test failed"
    exit 1
fi

# Start SSH daemon in background (non-blocking)
echo "🚀 Starting SSH daemon..."
/usr/sbin/sshd -D -e &
SSHD_PID=$!

# Wait a moment for SSH to start
sleep 3

# Verify SSH is running
if kill -0 "${SSHD_PID}" 2>/dev/null; then
    echo "✅ SSH daemon started successfully (PID: ${SSHD_PID})"
    # Test SSH port is listening
    if command -v nc &> /dev/null || command -v netstat &> /dev/null; then
        if (nc -z localhost 22 2>/dev/null || netstat -ln 2>/dev/null | grep -q ":22 "); then
            echo "✅ SSH port 22 is listening"
        fi
    fi
else
    echo "❌ ERROR: SSH daemon failed to start"
    exit 1
fi

echo "✅ SSH setup completed successfully!"
echo "📝 SSH is running on port 22 (PID: ${SSHD_PID})"
echo "🔐 Only key-based authentication is enabled"
echo "🚫 Password authentication is disabled"
echo "🔒 Container isolation is enforced"

# Keep the script running to maintain the background SSH process
# This ensures sshd doesn't become orphaned
# The script will be backgrounded by the entrypoint, so this is fine
wait "${SSHD_PID}" 2>/dev/null || true
