#!/bin/bash
#
# Cloud-Init / Bootstrap Script for Media Stack VPS
# This script should be run on first boot or when setting up a new VPS
# It installs all necessary maintenance components to prevent disk space issues
#
# Usage:
#   - Add to cloud-init user-data
#   - Or run manually: bash cloud-init-maintenance.sh
#

set -euo pipefail

# Configuration
REPO_URL="${MEDIA_STACK_REPO:-https://github.com/YOUR_USERNAME/my-media-stack.git}"
INSTALL_DIR="${MEDIA_STACK_DIR:-/home/ubuntu/my-media-stack}"
BRANCH="${MEDIA_STACK_BRANCH:-main}"

# Logging
LOG_FILE="/var/log/cloud-init-media-stack.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "============================================================"
log "Media Stack VPS Bootstrap Starting"
log "============================================================"

# Update system
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    htop \
    ncdu \
    python3 \
    python3-pip \
    jq \
    vim \
    sudo

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker ubuntu || true
    systemctl enable docker
    systemctl start docker
else
    log "Docker already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log "Installing Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    log "Docker Compose already installed"
fi

# Clone or update repository
if [ ! -d "$INSTALL_DIR" ]; then
    log "Cloning repository from $REPO_URL..."
    sudo -u ubuntu git clone "$REPO_URL" "$INSTALL_DIR" || {
        log "WARNING: Could not clone repository. Creating directory..."
        mkdir -p "$INSTALL_DIR"
        chown ubuntu:ubuntu "$INSTALL_DIR"
    }
else
    log "Repository already exists at $INSTALL_DIR"
fi

# Navigate to install directory
cd "$INSTALL_DIR"

# If repository was cloned, pull latest changes
if [ -d "$INSTALL_DIR/.git" ]; then
    log "Pulling latest changes from $BRANCH branch..."
    sudo -u ubuntu git checkout "$BRANCH" || true
    sudo -u ubuntu git pull || true
fi

# Install maintenance system if scripts exist
if [ -f "$INSTALL_DIR/scripts/install-maintenance-system.sh" ]; then
    log "Installing maintenance system..."
    bash "$INSTALL_DIR/scripts/install-maintenance-system.sh"
else
    log "WARNING: Maintenance scripts not found. Installing minimal configuration..."
    
    # Create minimal maintenance cron if scripts don't exist
    log "Setting up minimal maintenance cron..."
    (crontab -l 2>/dev/null | grep -v "docker system prune" || true; \
     echo "0 3 * * 0 docker system prune -af --filter 'until=168h' >> /var/log/docker-maintenance.log 2>&1") | crontab -
    
    # Configure Docker daemon with log rotation
    log "Configuring Docker daemon..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF
    systemctl reload docker || systemctl restart docker
fi

# Setup disk monitoring
log "Setting up disk monitoring..."
cat > /usr/local/bin/check-disk-usage.sh <<'EOF'
#!/bin/bash
USAGE=$(df -h / | awk 'NR==2 {print int($5)}')
if [ "$USAGE" -gt 85 ]; then
    echo "WARNING: Disk usage at ${USAGE}%" | tee -a /var/log/disk-usage.log
    # Optionally send alert (email, webhook, etc.)
fi
EOF
chmod +x /usr/local/bin/check-disk-usage.sh

# Add to crontab if not exists
(crontab -l 2>/dev/null | grep -v "check-disk-usage" || true; \
 echo "0 */6 * * * /usr/local/bin/check-disk-usage.sh") | crontab -

# Setup systemd service for monitoring (optional)
log "Creating monitoring service..."
cat > /etc/systemd/system/media-stack-monitor.service <<'EOF'
[Unit]
Description=Media Stack Disk Monitor
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-disk-usage.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/media-stack-monitor.timer <<'EOF'
[Unit]
Description=Media Stack Disk Monitor Timer
Requires=media-stack-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable media-stack-monitor.timer
systemctl start media-stack-monitor.timer

# Create helpful aliases
log "Creating helpful aliases..."
cat >> /home/ubuntu/.bashrc <<'EOF'

# Media Stack aliases
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dclean='docker system prune -af --volumes'
alias diskusage='ncdu / --exclude /mnt --exclude /media'
alias checkdisk='df -h / && docker system df'
EOF

# Set proper permissions
chown -R ubuntu:ubuntu "$INSTALL_DIR" 2>/dev/null || true

# Final checks
log "Performing final checks..."
log "Docker version: $(docker --version)"
log "Docker Compose version: $(docker compose version || docker-compose --version)"
log "Current disk usage: $(df -h / | awk 'NR==2 {print $5}')"
log "Cron jobs installed: $(crontab -l | grep -c docker || echo 0)"

log "============================================================"
log "Media Stack VPS Bootstrap Complete!"
log "============================================================"
log ""
log "Next steps:"
log "1. Configure .env file in $INSTALL_DIR"
log "2. Review and merge settings from .env.maintenance"
log "3. Start services: cd $INSTALL_DIR && docker compose up -d"
log ""
log "Monitoring:"
log "- Maintenance logs: tail -f /var/log/docker-maintenance.log"
log "- Disk usage logs: tail -f /var/log/disk-usage.log"
log "- Check disk: df -h / && docker system df"
log ""
log "System is now protected against disk space issues! 🛡️"

