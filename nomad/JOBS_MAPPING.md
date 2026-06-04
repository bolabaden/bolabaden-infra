# Nomad Jobs to Docker Compose Mapping

## Structure Overview
Each Nomad job file in `nomad/jobs/` corresponds exactly to a file referenced in the `include:` section of `docker-compose.yml`, maintaining 1:1 parity for the compose-to-hcl converter.

## Mapping Table

| Docker Compose File | Nomad Job File | Groups | Status |
|---------------------|----------------|--------|--------|
| docker-compose.yml (main) | nomad.core.hcl | 10 | ✓ Complete |
| compose/docker-compose.coolify-proxy.yml | nomad.coolify-proxy.hcl | 9 | ✓ Complete |
| compose/docker-compose.firecrawl.yml | nomad.firecrawl.hcl | 3 | ✓ Complete |
| compose/docker-compose.headscale.yml | nomad.headscale.hcl | 2 | ✓ Complete |
| compose/docker-compose.llm.yml | nomad.llm.hcl | 7 | ✓ Complete |
| compose/docker-compose.metrics.yml | (not yet ported) | 0 | ⚠ Pending |
| compose/docker-compose.stremio-group.yml | nomad.stremio-group.hcl | 8 | ✓ Complete |
| compose/docker-compose.warp-nat-routing.yml | nomad.warp-nat-routing.hcl | 2 | ✓ Complete |

## Group Details by Job

### nomad.core.hcl (10 groups)
Services from the main docker-compose.yml:
- mongodb-group
- redis-group
- searxng-group
- homepage-group
- bolabaden-nextjs-group
- session-manager-group
- dozzle-group
- portainer-group
- telemetry-auth-group
- authentik-services

### nomad.coolify-proxy.hcl (9 groups)
Traefik proxy and related infrastructure:
- traefik-group
- nginx-traefik-extensions-group
- tinyauth-group
- crowdsec-group
- whoami-group
- autokuma-group
- docker-gen-failover-group
- logrotate-traefik-group
- infrastructure-services

### nomad.firecrawl.hcl (3 groups)
Web crawling service and dependencies:
- firecrawl-group
- playwright-service-group
- nuq-postgres-group

### nomad.headscale.hcl (2 groups)
Tailscale coordination server:
- headscale-server-group
- headscale-group

### nomad.llm.hcl (7 groups)
LLM services and AI infrastructure:
- litellm-group
- litellm-postgres-group
- mcpo-group
- open-webui-group
- gptr-group
- qdrant-group
- mcp-proxy-group

### nomad.stremio-group.hcl (8 groups)
Media streaming and related services:
- stremio-group
- aiostreams-group
- stremthru-group
- flaresolverr-group
- jackett-group
- prowlarr-group
- rclone-group
- rclone-init-group

### nomad.warp-nat-routing.hcl (2 groups)
Cloudflare WARP networking:
- warp-nat-routing-group
- warp-nat-routing

## Usage

To run a specific job:
```bash
./nomad/run-job.sh nomad.core
./nomad/run-job.sh nomad.firecrawl
```

Or run multiple jobs:
```bash
./nomad/run-job.sh nomad.core nomad.firecrawl nomad.coolify-proxy
```

## Regenerating Job Files

If you modify `nomad.hcl` and want to regenerate the split job files:
```bash
cd nomad
python3 split-by-compose.py
```

This will recreate all job files in the `jobs/` directory with the correct naming convention.

## Future Work
- Port docker-compose.metrics.yml services (Prometheus, Grafana, Victoria Metrics, etc.) to Nomad
- Commented includes (authentik, plex, unsend, vpn-docker) can be ported following the same pattern

