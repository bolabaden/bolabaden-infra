# VPN Failover Service

A robust VPN failover service that manages multiple VPN connections with automatic failover and health checking. Supports both OpenVPN and Cloudflare WARP connections.

## Features

- **Multiple VPN Support**: Manage multiple OpenVPN and Cloudflare WARP connections
- **Automatic Failover**: Seamless switching between VPN connections when one fails
- **Health Monitoring**: Continuous health checking with configurable parameters
- **Priority-based Routing**: Route traffic through VPNs based on priority levels
- **Docker Integration**: Works with your existing `vpn-network` Docker network
- **Systemd Service**: Runs as a system service with automatic startup
- **CLI Management**: Easy-to-use command-line interface for management

## Architecture

The service works by:

1. **Monitoring VPN Health**: Continuously checking connectivity to each VPN
2. **Priority Management**: Using the highest priority available VPN
3. **Automatic Failover**: Switching to the next available VPN when the current one fails
4. **Docker Network Integration**: Updating routing for the `vpn-network` Docker network
5. **Service Management**: Running as a systemd service with proper logging

## Installation

### Quick Install

```bash
# Clone or download the files to your system
cd openvpn/

# Make the installation script executable
chmod +x install-vpn-failover.sh

# Run the installation script as root
sudo ./install-vpn-failover.sh
```

### Manual Installation

1. **Install Dependencies**:
   ```bash
   sudo apt-get update
   sudo apt-get install python3 curl openvpn
   ```

2. **Install Cloudflare WARP** (optional):
   ```bash
   curl -fsSL https://pkg.cloudflareclient.com/install.sh | sh
   ```

3. **Copy Service Files**:
   ```bash
   sudo mkdir -p /etc/vpn-failover
   sudo cp vpn-failover-service.py /etc/vpn-failover/
   sudo cp vpn-failover.service /etc/systemd/system/
   sudo cp vpn-failover-config.json /etc/vpn-failover/config.json
   ```

4. **Set Permissions**:
   ```bash
   sudo chmod +x /etc/vpn-failover/vpn-failover-service.py
   sudo chown -R root:root /etc/vpn-failover
   ```

5. **Enable and Start Service**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable vpn-failover
   sudo systemctl start vpn-failover
   ```

## Configuration

### Configuration File

The service uses `/etc/vpn-failover/config.json` for configuration:

```json
{
  "vpns": [
    {
      "name": "primary-openvpn",
      "type": "openvpn",
      "config_path": "/etc/openvpn/client/vpn_config.conf",
      "auth_path": "/etc/openvpn/client/auth.conf",
      "priority": 1,
      "health_check_url": "https://httpbin.org/ip",
      "health_check_interval": 30,
      "health_check_timeout": 10,
      "max_failures": 3,
      "reconnect_delay": 60,
      "enabled": true
    },
    {
      "name": "warp-fallback",
      "type": "warp",
      "config_path": "",
      "priority": 2,
      "health_check_url": "https://httpbin.org/ip",
      "health_check_interval": 30,
      "health_check_timeout": 10,
      "max_failures": 3,
      "reconnect_delay": 60,
      "enabled": true
    }
  ],
  "docker_network": "vpn-network",
  "log_level": "INFO"
}
```

### Configuration Parameters

#### VPN Configuration

- **name**: Unique identifier for the VPN
- **type**: `openvpn` or `warp`
- **config_path**: Path to OpenVPN configuration file
- **auth_path**: Path to OpenVPN authentication file (optional)
- **priority**: Priority level (lower number = higher priority)
- **health_check_url**: URL to test connectivity
- **health_check_interval**: Seconds between health checks
- **health_check_timeout**: Timeout for health check requests
- **max_failures**: Number of failures before marking VPN as failed
- **reconnect_delay**: Seconds to wait before reconnection attempts
- **enabled**: Whether this VPN is enabled

### Adding Multiple OpenVPN Configurations

1. **Create Additional Config Files**:
   ```bash
   sudo cp /etc/openvpn/client/vpn_config.conf /etc/openvpn/client/backup_config.conf
   sudo cp /etc/openvpn/client/auth.conf /etc/openvpn/client/backup_auth.conf
   ```

2. **Edit the Backup Configuration**:
   ```bash
   sudo nano /etc/openvpn/client/backup_config.conf
   ```
   Update the server details, certificates, etc.

3. **Update Service Configuration**:
   ```bash
   sudo nano /etc/vpn-failover/config.json
   ```
   Add the backup VPN configuration.

4. **Restart the Service**:
   ```bash
   sudo systemctl restart vpn-failover
   ```

### Cloudflare WARP Integration

1. **Install WARP**:
   ```bash
   curl -fsSL https://pkg.cloudflareclient.com/install.sh | sh
   ```

2. **Register WARP**:
   ```bash
   warp-cli register
   ```

3. **Add WARP to Configuration**:
   ```json
   {
     "name": "warp-fallback",
     "type": "warp",
     "config_path": "",
     "priority": 3,
     "health_check_url": "https://httpbin.org/ip",
     "health_check_interval": 30,
     "health_check_timeout": 10,
     "max_failures": 3,
     "reconnect_delay": 60,
     "enabled": true
   }
   ```

## Usage

### Service Management

```bash
# Start the service
sudo systemctl start vpn-failover

# Stop the service
sudo systemctl stop vpn-failover

# Restart the service
sudo systemctl restart vpn-failover

# Check service status
sudo systemctl status vpn-failover

# View logs
sudo journalctl -u vpn-failover -f
```

### CLI Management

The service includes a CLI tool for easy management:

```bash
# Install CLI tool
sudo cp vpn-failover-cli.py /usr/local/bin/vpn-failover-cli
sudo chmod +x /usr/local/bin/vpn-failover-cli

# Show service status
vpn-failover-cli status

# View logs
vpn-failover-cli logs -f

# List configured VPNs
vpn-failover-cli list

# Show configuration
vpn-failover-cli config

# Edit configuration
vpn-failover-cli edit-config

# Enable/disable VPNs
vpn-failover-cli enable primary-openvpn
vpn-failover-cli disable backup-openvpn
```

### Docker Integration

The service automatically manages routing for the `vpn-network` Docker network. When a VPN connects:

1. The service updates routing tables
2. Docker containers in the `vpn-network` use the active VPN
3. Traffic is routed through the VPN connection

To use with Docker:

```bash
# Create containers in the VPN network
docker run --network vpn-network your-container

# Or connect existing containers
docker network connect vpn-network your-container
```

## Monitoring and Troubleshooting

### Logs

- **Service Logs**: `/var/log/vpn-failover.log`
- **Systemd Logs**: `journalctl -u vpn-failover`
- **OpenVPN Logs**: `/var/log/openvpn-{vpn-name}.log`

### Health Checks

The service performs health checks by making HTTP requests to the configured URLs. You can monitor health:

```bash
# Check current status
vpn-failover-cli status

# Follow logs in real-time
vpn-failover-cli logs -f
```

### Common Issues

1. **VPN Won't Connect**:
   - Check configuration files
   - Verify authentication credentials
   - Check network connectivity

2. **Service Won't Start**:
   - Check dependencies are installed
   - Verify configuration file syntax
   - Check systemd logs

3. **Docker Network Issues**:
   - Ensure `vpn-network` exists
   - Check routing table configuration
   - Verify Docker daemon is running

### Testing VPN Connections

```bash
# Test individual VPN
vpn-failover-cli test primary-openvpn

# Manual connectivity test
curl --max-time 10 https://httpbin.org/ip

# Check OpenVPN status
sudo systemctl status openvpn@primary-openvpn
```

## Security Considerations

1. **File Permissions**: Ensure configuration files have proper permissions
2. **Authentication**: Keep VPN credentials secure
3. **Network Isolation**: Use proper firewall rules
4. **Logging**: Monitor logs for security events
5. **Updates**: Keep the service and dependencies updated

## Advanced Configuration

### Custom Health Checks

You can customize health check URLs for different VPNs:

```json
{
  "health_check_url": "https://your-custom-endpoint.com/health",
  "health_check_interval": 15,
  "health_check_timeout": 5
}
```

### Failover Behavior

The service implements intelligent failover:

1. **Priority-based Selection**: Always uses the highest priority available VPN
2. **Failure Counting**: Tracks consecutive failures
3. **Automatic Recovery**: Attempts to reconnect failed VPNs
4. **Graceful Degradation**: Continues operation with available VPNs

### Integration with Existing Setup

The service integrates with your existing OpenVPN setup:

- Uses existing configuration files
- Works with your `vpn-up.sh` and `vpn-down.sh` scripts
- Maintains the `vpn-network` Docker network
- Preserves existing routing configuration

## Support

For issues and questions:

1. Check the logs: `journalctl -u vpn-failover -f`
2. Verify configuration: `vpn-failover-cli config`
3. Test connectivity: `vpn-failover-cli test <vpn-name>`
4. Check service status: `systemctl status vpn-failover`

## License

This service is provided as-is for educational and operational purposes. 