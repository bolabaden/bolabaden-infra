#!/bin/bash
set -e

# OpenSVC Installation Script for Ubuntu/Debian
# Based on official documentation: https://docs.opensvc.com/latest/agent.install.html

echo "🔹 Installing Dependencies..."
sudo apt-get update
sudo apt-get install -y python-is-python3
sudo ln -sf /usr/bin/python3 /usr/bin/python

echo "🔹 Downloading OpenSVC..."
curl -o /tmp/opensvc.latest https://repo.opensvc.com/deb/2.1/current

echo "🔹 Installing OpenSVC..."
sudo dpkg -i /tmp/opensvc.latest

echo "🔹 Running Post-Install..."
# The doc mentions <OSVCROOT>/bin/postinstall. On Linux it's usually /usr/share/opensvc/bin/postinstall
if [ -f /usr/share/opensvc/bin/postinstall ]; then
    sudo /usr/share/opensvc/bin/postinstall
elif [ -f /usr/lib/opensvc/bin/postinstall ]; then
    sudo /usr/lib/opensvc/bin/postinstall
else
    echo "⚠️  Could not find postinstall script. Please run 'nodemgr node setup' manually if needed."
fi

echo "✅ OpenSVC installed successfully."
echo "ℹ️  Verify with: nodemgr node status"

