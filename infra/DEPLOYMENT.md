# Deployment Guide

## Prerequisites

1. **Go 1.21+** installed
2. **Docker** running with socket accessible
3. **Tailscale** installed and connected
4. **Environment variables** set (see below)

## Quick Start

```bash
cd infra

# Set environment variables
export DOMAIN=bolabaden.org
export STACK_NAME=my-media-stack
export CONFIG_PATH=/home/ubuntu/my-media-stack/volumes
export ROOT_PATH=/home/ubuntu/my-media-stack
export SECRETS_PATH=/home/ubuntu/my-media-stack/secrets
export TS_HOSTNAME=$(hostname -s)

# Build
go mod tidy
go build -o deploy .

# Deploy
sudo ./deploy
```

## Testing URL Patterns

After deployment, test the following patterns:

### Node-Specific URLs
```bash
# Should resolve to service on specific node
curl -k https://searxng.micklethefickle.bolabaden.org
curl -k https://searxng.beatapostapita.bolabaden.org
curl -k https://mongodb.micklethefickle.bolabaden.org:27017
```

### Global Load-Balanced URLs
```bash
# Should load balance across all nodes
curl -k https://searxng.bolabaden.org
curl -k https://traefik.bolabaden.org/dashboard
```

### Health Checks
```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check Traefik config
cat $CONFIG_PATH/traefik/dynamic/failover-fallbacks.yaml

# Check HAProxy config
cat $CONFIG_PATH/haproxy/haproxy.cfg
```

## Verification Checklist

- [ ] All networks created (`docker network ls`)
- [ ] All services running (`docker ps`)
- [ ] Traefik config generated (`failover-fallbacks.yaml`)
- [ ] HAProxy config generated (`haproxy.cfg`)
- [ ] Node-specific URLs work (`<service>.<node>.bolabaden.org`)
- [ ] Global URLs load balance (`<service>.bolabaden.org`)
- [ ] Health checks passing (`docker inspect <container>`)

## Troubleshooting

### Build Errors
```bash
go mod tidy
go clean -modcache
go get github.com/docker/docker@v24.0.7
```

### Deployment Errors
- Check Docker socket permissions: `sudo usermod -aG docker $USER`
- Check Tailscale status: `tailscale status --json`
- Check environment variables: `env | grep -E "(DOMAIN|STACK_NAME|CONFIG_PATH)"`

### Service Not Starting
- Check logs: `docker logs <container-name>`
- Check network connectivity: `docker network inspect <network-name>`
- Check healthcheck: `docker inspect <container-name> | grep -A 10 Healthcheck`


