#!/bin/bash
# Setup script for Containerized HA Cluster
# This script sets up the complete high-availability load balancing solution

set -e

echo "🚀 Setting up Containerized HA Cluster for *.bolabaden.org"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Creating directory structure..."

# Create necessary directories
mkdir -p {headscale,dns/zones,scripts,config,traefik,certs}

print_status "Setting up Headscale..."

# Generate Headscale auth key
print_warning "You need to generate a Headscale auth key. Run this command:"
echo "docker-compose exec headscale headscale apikeys create"
echo "Then add the key to your .env file as HEADSCALE_AUTHKEY=your_key_here"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    cat > .env << EOF
# HA Cluster Environment Variables
HEADSCALE_AUTHKEY=your_auth_key_here
SERVICE_VIP=100.100.10.10/32
LOCAL_PORT=8443
CHECK_INTERVAL=30
FAILURE_THRESHOLD=3
LETS_ENCRYPT_EMAIL=boden.crouch@gmail.com
EOF
    print_warning "Created .env file. Please update HEADSCALE_AUTHKEY with your actual key."
fi

print_status "Setting up DNS zones..."

# Create DNS zone file
cat > dns/zones/bolabaden.org.db << EOF
; DNS Zone file for bolabaden.org
\$TTL 300
@ IN SOA ns1.bolabaden.org. admin.bolabaden.org. (
    2023120101 ; Serial
    3600       ; Refresh
    1800       ; Retry
    1209600    ; Expire
    300        ; Minimum TTL
)

; Name servers
@ IN NS ns1.bolabaden.org.
@ IN NS ns2.bolabaden.org.

; A records for load balancing
@ IN A 172.20.0.2
@ IN A 172.20.0.3
@ IN A 172.20.0.4
@ IN A 172.20.0.5
@ IN A 172.20.0.6
@ IN A 172.20.0.7
@ IN A 172.20.0.8
@ IN A 172.20.0.9
@ IN A 172.20.0.10
@ IN A 172.20.0.11
@ IN A 172.20.0.12
@ IN A 172.20.0.13

; Wildcard for subdomains
* IN A 172.20.0.2
* IN A 172.20.0.3
* IN A 172.20.0.4
* IN A 172.20.0.5
* IN A 172.20.0.6
* IN A 172.20.0.7
* IN A 172.20.0.8
* IN A 172.20.0.9
* IN A 172.20.0.10
* IN A 172.20.0.11
* IN A 172.20.0.12
* IN A 172.20.0.13
EOF

print_status "Making scripts executable..."

# Make scripts executable
chmod +x scripts/*.sh

print_status "Starting services..."

# Start the services
docker-compose -f docker-compose.ha-cluster.yml up -d

print_status "Waiting for services to start..."

# Wait for services to be ready
sleep 30

print_status "Checking service status..."

# Check if all services are running
docker-compose -f docker-compose.ha-cluster.yml ps

print_status "Setting up Headscale nodes..."

# Instructions for setting up Headscale nodes
cat << EOF

🎉 Setup Complete! 

Next steps:

1. Generate Headscale auth key:
   docker-compose exec headscale headscale apikeys create

2. Add the key to your .env file:
   HEADSCALE_AUTHKEY=your_key_here

3. On each backend server, run:
   curl -fsSL https://tailscale.com/install.sh | sh
   tailscale up --login-server=http://YOUR_HEADSCALE_IP:50443 --authkey=YOUR_AUTH_KEY

4. Approve routes in Headscale admin:
   docker-compose exec headscale headscale routes list
   docker-compose exec headscale headscale routes enable --route=100.100.10.10/32

5. Test the setup:
   curl -H "Host: test.bolabaden.org" http://localhost/health

Services running:
- Headscale: http://localhost:50443
- Traefik Dashboard: http://localhost:8080
- DNS Server: localhost:53
- Health Checker: Monitoring all servers

EOF

print_status "Setup complete! Check the instructions above for next steps." 