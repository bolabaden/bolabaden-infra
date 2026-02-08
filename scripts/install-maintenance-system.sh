#!/bin/bash
#
# Complete Maintenance System Installation Script
# This script installs all maintenance components to prevent disk space issues
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================================"
echo "Installing Media Stack Maintenance System"
echo "============================================================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script requires sudo privileges for some operations."
    echo "   You may be prompted for your password."
    echo ""
fi

# Step 1: Install Docker daemon configuration
echo "📦 Step 1/5: Installing Docker daemon configuration..."
if [ -f "$SCRIPT_DIR/setup-docker-daemon.sh" ]; then
    bash "$SCRIPT_DIR/setup-docker-daemon.sh"
    echo "✅ Docker daemon configuration installed"
else
    echo "⚠️  setup-docker-daemon.sh not found, skipping..."
fi
echo ""

# Step 2: Install cron jobs
echo "📦 Step 2/5: Installing cron jobs..."
if [ -f "$SCRIPT_DIR/setup-crontabs.sh" ]; then
    bash "$SCRIPT_DIR/setup-crontabs.sh"
    echo "✅ Cron jobs installed"
else
    echo "⚠️  setup-crontabs.sh not found, skipping..."
fi
echo ""

# Step 3: Setup log directories and permissions
echo "📦 Step 3/5: Setting up log directories..."
sudo mkdir -p /var/log
sudo touch /var/log/docker-maintenance.log
sudo touch /var/log/disk-usage.log
sudo chmod 644 /var/log/docker-maintenance.log
sudo chmod 644 /var/log/disk-usage.log
echo "✅ Log directories configured"
echo ""

# Step 4: Setup logrotate for our custom logs
echo "📦 Step 4/5: Configuring logrotate..."
sudo tee /etc/logrotate.d/docker-maintenance > /dev/null << 'EOF'
/var/log/docker-maintenance.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 root root
}

/var/log/disk-usage.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Application logs under /opt/docker/data (e.g. homepage.log) - copytruncate so app can keep file open
sudo tee /etc/logrotate.d/docker-data-app-logs > /dev/null << 'EOF'
/opt/docker/data/*/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
echo "✅ Logrotate configured (maintenance + app logs under /opt/docker/data/*/logs/)"
echo ""

# Step 5: Merge maintenance environment variables
echo "📦 Step 5/5: Checking environment configuration..."
if [ -f "$PROJECT_ROOT/.env" ] && [ -f "$PROJECT_ROOT/.env.maintenance" ]; then
    echo "⚠️  Found .env.maintenance file with recommended settings"
    echo "   Please review and merge these settings into your .env file:"
    echo "   - Reduced retention periods for metrics"
    echo "   - Memory limits for services"
    echo "   - Cache size limits"
    echo ""
    echo "   To automatically append (BE CAREFUL - may create duplicates):"
    echo "   cat $PROJECT_ROOT/.env.maintenance >> $PROJECT_ROOT/.env"
    echo ""
else
    echo "ℹ️  No .env or .env.maintenance file found"
fi
echo ""

# Step 6: Create a one-time cleanup helper
echo "Creating one-time cleanup helper script..."
cat > "$SCRIPT_DIR/emergency-cleanup.sh" << 'EOF'
#!/bin/bash
#
# Emergency Cleanup Script
# Run this manually if disk space is critically low
#

set -euo pipefail

echo "⚠️  EMERGENCY CLEANUP MODE"
echo "This will aggressively clean up Docker resources and caches"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Stopping all containers..."
docker stop $(docker ps -q) 2>/dev/null || true

echo "Pruning system (aggressive)..."
docker system prune -af --volumes

echo "Cleaning application caches..."
sudo rm -rf /opt/docker/data/prometheus/data/wal/* || true
sudo find /opt/docker/data/stremio -type f -mtime +7 -delete || true
sudo rm -rf /opt/docker/data/open-webui/cache/*.tmp || true

echo "Cleaning system caches..."
sudo journalctl --vacuum-time=7d
sudo apt-get clean || true
npm cache clean --force || true
rm -rf ~/.cache/uv/archive-v0/* || true

echo "Cleaning temp files..."
sudo find /tmp -type f -mtime +1 -delete || true

echo ""
echo "✅ Emergency cleanup completed!"
echo "Current disk usage:"
df -h /
EOF

chmod +x "$SCRIPT_DIR/emergency-cleanup.sh"
echo "✅ Emergency cleanup script created at $SCRIPT_DIR/emergency-cleanup.sh"
echo ""

# Final summary
echo "============================================================"
echo "Installation Complete! 🎉"
echo "============================================================"
echo ""
echo "What was installed:"
echo "  ✅ Docker daemon with log rotation (max 10MB × 3 files)"
echo "  ✅ Weekly maintenance cron (Sundays at 2 AM)"
echo "  ✅ Daily container cleanup (Every day at 3 AM)"
echo "  ✅ Daily disk monitoring (Every day at 4 AM)"
echo "  ✅ System log rotation"
echo ""
echo "Next steps:"
echo "  1. Review and merge .env.maintenance settings into your .env file"
echo "  2. Restart Docker services to apply new logging: docker compose restart"
echo "  3. Monitor logs: tail -f /var/log/docker-maintenance.log"
echo ""
echo "Useful commands:"
echo "  - Manual cleanup: $SCRIPT_DIR/docker-maintenance.sh"
echo "  - Emergency cleanup: $SCRIPT_DIR/emergency-cleanup.sh"
echo "  - Check disk usage: docker system df"
echo "  - View cron jobs: crontab -l"
echo ""
echo "Your system is now protected against disk space issues! 🛡️"
echo "============================================================"

