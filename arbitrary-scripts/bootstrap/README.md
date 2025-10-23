# VPS Bootstrap Script

An idempotent, flexible, and configuration-driven bootstrap script for setting up Ubuntu/Debian VPS servers with Docker, Tailscale, Nomad, and Consul.

## Features

- ✅ **Fully Idempotent** - Safe to run multiple times without breaking things
- ✅ **Configuration-Driven** - All settings via environment variables or config file
- ✅ **State Tracking** - Skips already-completed steps automatically
- ✅ **Multi-Distribution Support** - Works with Ubuntu, Debian, and other systemd-based distros
- ✅ **Dynamic Discovery** - Auto-detects network settings, timezone, Nomad servers, etc.
- ✅ **Modular** - Enable/disable components as needed
- ✅ **Production Ready** - Error handling, logging, and validation built-in

## Quick Start

### Basic Usage (with defaults)

```bash
# Run with all defaults
sudo ./dont-run-directly.sh

# Specify custom hostname
sudo ./dont-run-directly.sh myserver
```

### Using Configuration File

```bash
# Copy example config
sudo cp bootstrap-config.env.example /etc/bootstrap-config.env

# Edit configuration
sudo nano /etc/bootstrap-config.env

# Run script
sudo ./dont-run-directly.sh
```

### Using Environment Variables

```bash
sudo DOMAIN=mydomain.com \
     TAILSCALE_AUTH_KEY=tskey-auth-xxxxx \
     GITHUB_USERS=myusername \
     ENABLE_NOMAD=false \
     ./dont-run-directly.sh
```

## Configuration

### Configuration Priority

1. Command-line environment variables (highest priority)
2. Configuration file (`/etc/bootstrap-config.env` or `$BOOTSTRAP_CONFIG_FILE`)
3. Built-in defaults (lowest priority)

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `bolabaden.org` | Domain for FQDN construction |
| `BOOTSTRAP_HOSTNAME` | Auto-detected | Server hostname |
| `DEBUG` | `false` | Enable bash debug mode (`set -x`) |

### User Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PRIMARY_USER` | `ubuntu` | Main admin user |
| `ADMIN_USERS` | `root ubuntu` | Space-separated list of admin users |
| `PASSWORD_HASH` | See config | SHA-512 password hash for users |
| `GITHUB_USERS` | `th3w1zard1` | Comma-separated GitHub usernames for SSH keys |

Generate password hash:
```bash
mkpasswd -m sha-512
```

### DNS Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DNS_SERVERS` | `1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4` | Comma-separated DNS servers |

### Tailscale Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_TAILSCALE` | `true` | Install and configure Tailscale |
| `TAILSCALE_AUTH_KEY` | Required | Tailscale/Headscale auth key |
| `TAILSCALE_LOGIN_SERVER` | `https://headscale.${DOMAIN}` | Login server URL |
| `TAILSCALE_ADVERTISE_EXIT` | `true` | Advertise as exit node |

### Docker Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_DOCKER` | `true` | Install Docker |
| `DOCKER_VERSION` | `27.0` | Docker version (fallback method) |

### Nomad & Consul Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_NOMAD` | `true` | Install and configure Nomad |
| `ENABLE_CONSUL` | `true` | Install Consul |
| `NOMAD_DATACENTER` | `dc1` | Nomad datacenter name |
| `NOMAD_BOOTSTRAP_EXPECT` | `1` | Expected server count for bootstrap |
| `NOMAD_NODE_CLASS` | `balanced` | Node class for workload placement |
| `NOMAD_SERVERS` | Auto-discovered | Comma-separated server IPs for clustering |

### Swap Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SWAP_SIZE` | `4G` | Swap file size |
| `SWAP_FILE` | `/swapfile` | Swap file location |

### SSH Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_PERMIT_ROOT` | `yes` | Allow root SSH login |
| `SSH_PASSWORD_AUTH` | `yes` | Enable password authentication |

### Timezone

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | Auto-detected | Timezone (e.g., `America/New_York`) |

## Advanced Usage

### Running Specific Components Only

Disable unwanted components:

```bash
sudo ENABLE_DOCKER=false \
     ENABLE_NOMAD=false \
     ENABLE_CONSUL=false \
     ./dont-run-directly.sh
```

### Resetting State

To re-run all steps (useful for testing):

```bash
sudo rm -f /var/lib/bootstrap-state.json
sudo ./dont-run-directly.sh
```

To re-run specific step:

```bash
# Edit state file and remove the specific step
sudo nano /var/lib/bootstrap-state.json
```

### Custom State File Location

```bash
sudo BOOTSTRAP_STATE_FILE=/root/my-state.json ./dont-run-directly.sh
```

### Debug Mode

Enable verbose output:

```bash
sudo DEBUG=true ./dont-run-directly.sh
```

### Nomad Clustering

#### Standalone Node
```bash
sudo NOMAD_BOOTSTRAP_EXPECT=1 \
     NOMAD_SERVERS= \
     ./dont-run-directly.sh
```

#### Cluster Member (Manual IPs)
```bash
sudo NOMAD_BOOTSTRAP_EXPECT=3 \
     NOMAD_SERVERS=10.0.0.1,10.0.0.2,10.0.0.3 \
     ./dont-run-directly.sh
```

#### Cluster Member (Auto-Discovery via Tailscale)
```bash
sudo NOMAD_BOOTSTRAP_EXPECT=3 \
     ENABLE_TAILSCALE=true \
     ./dont-run-directly.sh
# Script will auto-discover other Nomad servers on the Tailscale network
```

## Components Installed

### Always Installed
- Essential system packages (curl, wget, git, etc.)
- Python3 ecosystem (pip, venv, pipx)
- DNS utilities
- Network tools
- Security updates configuration

### Optional (Enabled by Default)
- **Docker** - Container runtime with compose
- **Tailscale** - WireGuard-based VPN
- **Nomad** - Container orchestration
- **Consul** - Service discovery
- **Node.js** - Via `n` version manager
- **Swap File** - For additional memory

## State Management

The script tracks completed steps in `/var/lib/bootstrap-state.json`:

```json
{
  "hostname": true,
  "system_update": true,
  "essential_packages": true,
  "docker": true,
  "ssh_config": true,
  "users": true,
  "network_optimization": true,
  "dns_configuration": true,
  "tailscale": true,
  "node_tools": true,
  "security_updates": true,
  "timezone": true,
  "nomad_consul": true,
  "nomad_config": true,
  "swap": true,
  "cleanup": true
}
```

Each step is marked as `true` when completed. If a step is already `true`, it will be skipped on subsequent runs.

## Examples

### Minimal Setup (Docker + SSH only)

```bash
sudo ENABLE_TAILSCALE=false \
     ENABLE_NOMAD=false \
     ENABLE_CONSUL=false \
     GITHUB_USERS=yourusername \
     ./dont-run-directly.sh myserver
```

### Full Stack (Everything Enabled)

```bash
sudo DOMAIN=example.com \
     TAILSCALE_AUTH_KEY=tskey-auth-xxxxx \
     GITHUB_USERS=user1,user2 \
     NOMAD_BOOTSTRAP_EXPECT=3 \
     NOMAD_SERVERS=10.0.0.1,10.0.0.2,10.0.0.3 \
     ./dont-run-directly.sh server1
```

### Development Server

```bash
sudo ENABLE_NOMAD=false \
     ENABLE_CONSUL=false \
     SSH_PASSWORD_AUTH=yes \
     SWAP_SIZE=8G \
     ./dont-run-directly.sh devbox
```

### Production Cluster Node

```bash
sudo DOMAIN=prod.example.com \
     TAILSCALE_AUTH_KEY=tskey-auth-xxxxx-prod \
     GITHUB_USERS=devops-team \
     SSH_PASSWORD_AUTH=no \
     SSH_PERMIT_ROOT=no \
     NOMAD_BOOTSTRAP_EXPECT=5 \
     NOMAD_NODE_CLASS=production \
     PRIMARY_USER=deploy \
     ADMIN_USERS="deploy" \
     ./dont-run-directly.sh prod-node-01
```

## Troubleshooting

### Check Logs

```bash
# Follow script execution in real-time
sudo tail -f /var/log/syslog | grep bootstrap

# Check Nomad logs
sudo journalctl -u nomad -f

# Check Docker status
sudo systemctl status docker
```

### Verify Components

```bash
# Check Docker
docker ps
docker --version

# Check Tailscale
tailscale status

# Check Nomad
nomad node status
nomad server members

# Check DNS
dig google.com
```

### Common Issues

#### "Docker installation failed"
- Check internet connectivity
- Verify OS version compatibility
- Check for conflicting packages

#### "Tailscale setup may need manual intervention"
- Verify `TAILSCALE_AUTH_KEY` is valid
- Check if `TAILSCALE_LOGIN_SERVER` is reachable
- Ensure firewall allows Tailscale (UDP 41641)

#### "Could not determine timezone"
- Set `TZ` environment variable manually
- Check internet connectivity for GeoIP services

#### Script hangs at a step
- Enable debug mode: `DEBUG=true`
- Check for prompts waiting for input
- Review syslog for errors

### Force Re-run

```bash
# Delete state file
sudo rm -f /var/lib/bootstrap-state.json

# Re-run script
sudo ./dont-run-directly.sh
```

## Security Considerations

1. **SSH Keys**: Uses GitHub for public key distribution - ensure your GitHub account is secure
2. **Password Hash**: Change the default password hash immediately
3. **Tailscale Auth Key**: Keep auth keys secret, rotate regularly
4. **Root Access**: Consider disabling root login in production (`SSH_PERMIT_ROOT=no`)
5. **Password Auth**: Consider disabling for production (`SSH_PASSWORD_AUTH=no`)

## Distribution Support

Tested on:
- ✅ Ubuntu 20.04, 22.04, 24.04
- ✅ Debian 11, 12
- ⚠️ Other systemd-based distributions (may require adjustments)

## Contributing

Feel free to submit issues and enhancement requests!

## License

Use at your own risk. No warranty provided.

