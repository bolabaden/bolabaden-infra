# Quick Start Checklist

## Pre-Flight Checklist

- [ ] Docker Engine 24.0+ installed and running
- [ ] Tailscale installed and connected
- [ ] Go 1.24+ installed (for building)
- [ ] Cloudflare API token with DNS edit permissions
- [ ] Cloudflare Zone ID
- [ ] Network connectivity to other nodes (via Tailscale)

## Installation Steps

1. **Clone and Build**
   ```bash
   cd /path/to/my-media-stack/infra
   ./scripts/install.sh
   ```

2. **Configure Secrets**
   ```bash
   mkdir -p /opt/constellation/secrets
   echo "your-cloudflare-api-token" > /opt/constellation/secrets/cf-api-token.txt
   chmod 600 /opt/constellation/secrets/cf-api-token.txt
   ```

3. **Set Environment Variables**
   ```bash
   # Edit /etc/systemd/system/constellation-agent.service
   # Add: Environment=CLOUDFLARE_ZONE_ID=your-zone-id
   ```

4. **Start Agent**
   ```bash
   systemctl daemon-reload
   systemctl start constellation-agent
   systemctl enable constellation-agent
   ```

5. **Verify**
   ```bash
   systemctl status constellation-agent
   journalctl -u constellation-agent -f
   ```

## First Node (Bootstrap)

- [ ] Install agent
- [ ] Configure secrets
- [ ] Start agent
- [ ] Verify logs show successful startup
- [ ] Check agent is listening on gossip port (7946)
- [ ] Check agent is listening on Raft port (8300)
- [ ] Check agent is listening on HTTP provider port (8081)

## Additional Nodes

- [ ] Install agent
- [ ] Configure secrets
- [ ] Verify Tailscale connectivity to existing nodes
- [ ] Start agent
- [ ] Verify logs show peer discovery
- [ ] Verify agent joins cluster

## Deploy Services

- [ ] Deploy services: `cd infra && go run main.go`
- [ ] Verify services are running: `docker ps`
- [ ] Check service health in agent logs
- [ ] Verify Traefik is getting dynamic config
- [ ] Test service access via domain names

## Verification

- [ ] Agent logs show no errors
- [ ] Services are healthy in gossip state
- [ ] DNS records are updating correctly
- [ ] Traefik routing is working
- [ ] Services accessible via `<service>.bolabaden.org`
- [ ] Services accessible via `<service>.<node>.bolabaden.org`

## Common Issues

### Agent won't start
- Check Docker: `systemctl status docker`
- Check Tailscale: `tailscale status`
- Check logs: `journalctl -u constellation-agent -n 100`

### Services not discovered
- Verify services running: `docker ps`
- Check agent logs for health monitoring
- Verify gossip connectivity

### DNS not updating
- Check DNS writer lease in logs
- Verify Cloudflare API token
- Check zone ID configuration

### Traefik not getting config
- Test HTTP provider: `curl http://localhost:8081/api/http/routers`
- Check Traefik static config includes HTTP provider
- Verify Traefik can reach agent

## Next Steps

1. Review full deployment guide: `docs/DEPLOYMENT_GUIDE.md`
2. Configure Traefik static configuration
3. Deploy your services
4. Monitor cluster health
5. Set up backups for Raft data and secrets

