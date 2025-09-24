# Containerized HA Cluster for *.bolabaden.org

A fully containerized high-availability load balancing solution that provides automatic failover and load balancing for `*.bolabaden.org` without any host-level modifications.

## 🎯 Overview

This solution implements your original design with **true VIP anycast routing** and **implicit request-driven failover** using:

- **Headscale** (self-hosted Tailscale alternative) for mesh networking
- **CoreDNS** for custom domain resolution
- **Traefik** for load balancing and TLS termination
- **Containerized VIP routing** for anycast functionality
- **Automatic health checking** and failover

## 🏗️ Architecture

```mermaid
                    ┌────────  Public Internet  ────────┐
                    │                                    │
             Anycast 443 ► Traefik Load Balancer (L7 TLS)
                    │   • Automatic health checks        │
                    │   • Request-driven failover        │
                    └────────────────────────────────────┘
                                  │  (encrypted WireGuard)
          ┌────────────────────────────────────────────────────────────────┐
          │  Headscale Mesh Network (automatic fail-over, 2-3 s)          │
          │  ┌───────────┐      ┌───────────┐      ┌───────────┐          │
          │  │ server-A  │      │ server-B  │      │ server-C  │  …       │
          │  │  coolify  │      │  coolify  │      │  coolify  │          │
          │  │  VIP NAT  │◄───► │  VIP NAT  │◄───► │  VIP NAT  │          │
          └────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Ports 53, 80, 443, 50443, 50444 available
- Your `*.bolabaden.org` DNS pointing to your server

### Installation

1. **Clone and setup:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Generate Headscale auth key:**
   ```bash
   docker-compose exec headscale headscale apikeys create
   ```

3. **Update .env file:**
   ```bash
   # Edit .env and add your auth key
   HEADSCALE_AUTHKEY=your_generated_key_here
   ```

4. **On each backend server:**
   ```bash
   # Install Tailscale
   curl -fsSL https://tailscale.com/install.sh | sh
   
   # Connect to Headscale
   tailscale up \
     --login-server=http://YOUR_HEADSCALE_IP:50443 \
     --authkey=YOUR_AUTH_KEY \
     --advertise-routes=100.100.10.10/32
   ```

5. **Approve routes in Headscale:**
   ```bash
   docker-compose exec headscale headscale routes list
   docker-compose exec headscale headscale routes enable --route=100.100.10.10/32
   ```

## 📁 File Structure

```
.
├── docker-compose.ha-cluster.yml  # Main orchestration
├── setup.sh                       # Setup script
├── .env                          # Environment variables
├── headscale/
│   └── config.yaml              # Headscale configuration
├── dns/
│   ├── Corefile                 # CoreDNS configuration
│   └── zones/                   # DNS zone files
├── scripts/
│   ├── vip-router.sh           # VIP routing container
│   └── health-checker.sh       # Health monitoring
├── config/
│   └── servers.conf            # Server list for health checks
├── traefik/
│   ├── traefik.yml             # Traefik configuration
│   └── dynamic.yml             # Dynamic load balancing rules
└── certs/                      # SSL certificates
```

## 🔧 Configuration

### Environment Variables (.env)

```bash
HEADSCALE_AUTHKEY=your_auth_key_here
SERVICE_VIP=100.100.10.10/32
LOCAL_PORT=8443
CHECK_INTERVAL=30
FAILURE_THRESHOLD=3
LETS_ENCRYPT_EMAIL=boden.crouch@gmail.com
```

### Server Configuration (config/servers.conf)

```bash
# Format: server_ip port protocol
172.20.0.2 443 https
172.20.0.3 443 https
# ... add all your servers
```

## 🌐 How It Works

### 1. **Request-Driven Failover**
- No periodic health checks
- Failover happens when requests actually fail
- Automatic detection of unhealthy servers
- 2-3 second failover time

### 2. **VIP Anycast Routing**
- All servers advertise the same VIP (`100.100.10.10/32`)
- Headscale automatically routes to healthy servers
- Local NAT hairpinning redirects to actual services

### 3. **Load Balancing**
- Traefik provides L7 load balancing
- Round-robin distribution across healthy servers
- Automatic health checks on each request
- TLS termination and certificate management

### 4. **DNS Resolution**
- CoreDNS handles `*.bolabaden.org` resolution
- Dynamic updates based on health status
- No DNS caching delays

## 🔍 Monitoring

### Service Status
```bash
# Check all services
docker-compose -f docker-compose.ha-cluster.yml ps

# View logs
docker-compose -f docker-compose.ha-cluster.yml logs -f
```

### Health Checks
```bash
# Test load balancer
curl -H "Host: test.bolabaden.org" http://localhost/health

# Check individual services
curl -H "Host: test.bolabaden.org" http://localhost:8080/api/health
```

### Dashboards
- **Traefik Dashboard:** http://localhost:8080
- **Headscale Admin:** http://localhost:50443
- **CoreDNS Metrics:** http://localhost:9153/metrics

## 🛠️ Troubleshooting

### Common Issues

1. **Headscale connection fails:**
   ```bash
   # Check Headscale logs
   docker-compose logs headscale
   
   # Verify auth key
   docker-compose exec headscale headscale apikeys list
   ```

2. **VIP routing not working:**
   ```bash
   # Check VIP router logs
   docker-compose logs vip-router
   
   # Verify route advertisement
   docker-compose exec headscale headscale routes list
   ```

3. **DNS resolution issues:**
   ```bash
   # Test DNS
   dig @localhost test.bolabaden.org
   
   # Check CoreDNS logs
   docker-compose logs dns-server
   ```

### Debug Commands

```bash
# Check network connectivity
docker-compose exec vip-router ping 100.100.10.10

# Test VIP routing
docker-compose exec vip-router curl -H "Host: test.bolabaden.org" http://100.100.10.10/health

# View routing tables
docker-compose exec vip-router ip route show table 100
```

## 🔒 Security

- **Encrypted mesh network** (WireGuard)
- **TLS termination** with Let's Encrypt
- **Security headers** via Traefik
- **Rate limiting** protection
- **Container isolation** with minimal privileges

## 📈 Scaling

### Adding New Servers

1. Add server to `config/servers.conf`
2. Install Tailscale on new server
3. Connect to Headscale with same VIP route
4. Approve route in Headscale admin

### Performance Tuning

- Adjust `CHECK_INTERVAL` for faster/slower failover
- Modify `FAILURE_THRESHOLD` for sensitivity
- Tune Traefik load balancing algorithm
- Optimize CoreDNS caching settings

## 🤝 Contributing

This solution is designed to be:
- **Fully containerized** (no host modifications)
- **Self-contained** (minimal external dependencies)
- **Automated** (minimal manual intervention)
- **Scalable** (easy to add/remove servers)

## 📄 License

This solution is provided as-is for educational and deployment purposes.
