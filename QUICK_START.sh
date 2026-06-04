#!/bin/bash
#
# Quick Start: Activate the maintenance system in one command
#

set -e

echo "============================================================"
echo "🚀 Activating Media Stack Maintenance System"
echo "============================================================"
echo ""

cd /home/ubuntu/my-media-stack

# Step 1: Install the maintenance system
echo "📦 Installing maintenance system..."
./scripts/install-maintenance-system.sh

echo ""
echo "============================================================"
echo "✅ Installation Complete!"
echo "============================================================"
echo ""
echo "Next, you should:"
echo ""
echo "1. Review recommended settings:"
echo "   cat .env.maintenance"
echo ""
echo "2. Merge important settings into .env:"
echo "   nano .env  # Manually copy relevant lines"
echo ""
echo "3. Restart your services with maintenance overlay:"
echo "   docker compose -f docker-compose.yml -f compose/docker-compose.maintenance.yml up -d"
echo ""
echo "4. Monitor the system:"
echo "   tail -f /var/log/docker-maintenance.log"
echo ""
echo "🎉 Your VPS is now protected against disk space issues!"
echo "============================================================"

