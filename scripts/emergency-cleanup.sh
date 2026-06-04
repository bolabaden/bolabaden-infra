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
docker system prune -af --volumes || true

echo "Cleaning application caches..."
sudo rm -rf /opt/docker/data/prometheus/data/wal/* || true
sudo find /opt/docker/data/stremio -type f -mtime +7 -delete || true
sudo rm -rf /opt/docker/data/open-webui/cache/*.tmp || true

echo "Cleaning system caches..."
sudo journalctl --vacuum-time=7d || true
sudo apt-get clean || true
npm cache clean --force || true
rm -rf ~/.cache/uv/archive-v0/* || true

echo "Cleaning temp files..."
sudo find /tmp -type f -mtime +1 -delete || true

echo ""
echo "✅ Emergency cleanup completed!"
echo "Current disk usage:"
df -h /
