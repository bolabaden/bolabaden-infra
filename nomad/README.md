# Nomad Job Specifications for Docker Compose Stack

This directory contains Nomad job specifications that are 1:1 equivalents of the Docker Compose configuration found in `docker-compose.yml` and its included files.

## ⚠️ IMPORTANT: Secrets Management

This conversion uses **separate files for secrets and configuration**:

- **`variables.auto.tfvars.hcl`** - Non-sensitive configuration (✅ safe to commit)
- **`secrets.auto.tfvars.hcl`** - API keys, passwords, tokens (⚠️ NEVER commit)

**See [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) for complete details on managing secrets securely.**

The `secrets.auto.tfvars.hcl` file is protected by `.gitignore` and contains 461 sensitive values from your original `.env` file.

## Quick Start

```bash
# Navigate to the nomad directory
cd nomad

# ⚠️ FIRST TIME ONLY: Copy the secrets template
cp secrets.auto.tfvars.hcl.example secrets.auto.tfvars.hcl
# Then edit secrets.auto.tfvars.hcl with your actual secrets

# Run the main stack (auto-loads both variables.auto.tfvars.hcl and secrets.auto.tfvars.hcl)
nomad job run docker-compose.nomad.hcl

# Run the metrics stack
nomad job run metrics.nomad.hcl

# Check status
nomad job status docker-compose-stack
nomad job status metrics-stack
```

## Files Overview

### `docker-compose.nomad.hcl`
The main Nomad job file that converts the core Docker Compose stack including:

- **Core Services**: MongoDB, SearxNG, Code Server, Session Manager, Homepage, Redis, Portainer
- **Authentik Services**: Authentik server, worker, and PostgreSQL database
- **Watchtower**: Container update automation
- **Coolify Proxy Services**: Cloudflare DDNS, Nginx auth extensions, TinyAuth, CrowdSec, Traefik, Whoami, Autokuma, Logrotate
- **Firecrawl Services**: Playwright service, Firecrawl API, Nuq PostgreSQL
- **Headscale Services**: Headscale server and UI for Tailscale control
- **LLM Services**: Open WebUI, MCPO, LiteLLM with PostgreSQL, AI Research Wizard (GPTR)
- **Infrastructure Services**: Docker socket proxies for secure container management

### `metrics.nomad.hcl`
Nomad job specifications for the comprehensive monitoring and metrics stack.

### `variables.auto.tfvars.hcl`
**Automatic variable definitions file** that mirrors your `.env` file. This file is automatically loaded by Nomad when running jobs in this directory.

## Variable Management

Nomad uses HCL variables instead of Docker Compose's `.env` file approach. Here's how it works:

### Understanding Nomad Variables

1. **Variable Declaration** (in `.nomad.hcl` files):
   ```hcl
   variable "domain" {
     type    = string
     default = "bolabaden.org"
   }
   ```

2. **Variable Usage** (in job specifications):
   ```hcl
   env {
     DOMAIN = var.domain
   }
   ```

3. **Variable Assignment** (multiple methods):

#### Method 1: Auto-Loaded Variable File (Recommended)
The `variables.auto.tfvars.hcl` file is **automatically loaded** when you run:
```bash
nomad job run docker-compose.nomad.hcl
```

This file contains all the values from your `.env` file translated to HCL format.

#### Method 2: Environment Variables
Use `NOMAD_VAR_` prefix:
```bash
export NOMAD_VAR_domain="my-custom-domain.com"
export NOMAD_VAR_config_path="/custom/path"
nomad job run docker-compose.nomad.hcl
```

#### Method 3: Command-Line Variables
```bash
nomad job run \
  -var="domain=my-domain.com" \
  -var="config_path=/custom/path" \
  docker-compose.nomad.hcl
```

#### Method 4: Custom Variable File
```bash
nomad job run -var-file="production.hcl" docker-compose.nomad.hcl
```

### Variable Precedence
Nomad resolves variables in this order (highest to lowest priority):
1. Command-line `-var` flags
2. `NOMAD_VAR_*` environment variables
3. `*.auto.tfvars.hcl` files (alphabetical order)
4. Explicitly specified `-var-file` files
5. Default values in variable declarations

## Understanding Variables and Templates

**Important:** Nomad uses TWO different variable systems that often confuse newcomers. See **[TEMPLATE_SYNTAX.md](TEMPLATE_SYNTAX.md)** for a comprehensive guide.

**Quick Summary:**
- `var.variable_name` - Nomad job variables from `.tfvars` files (resolved at job submission)
- `{{ env "VAR" }}` - Go templates in `template` blocks (resolved at container runtime)

**Note:** Nomad does NOT read `.env` files like Docker Compose. Use `*.auto.tfvars.hcl` files instead.

## Key Differences from Docker Compose

### 1. Variable System

**Docker Compose:**
```yaml
# .env file
DOMAIN=bolabaden.org

# docker-compose.yml
services:
  web:
    environment:
      - HOST=${DOMAIN}
```

**Nomad:**
```hcl
# variables.auto.tfvars.hcl
domain = "bolabaden.org"

# job.nomad.hcl
variable "domain" {
  type = string
}

task "web" {
  env {
    HOST = var.domain
  }
}
```

### 2. Service Discovery
- Nomad uses built-in service discovery via Consul integration
- Services register automatically and are accessible via DNS
- Format: `<service-name>.service.consul` or `<service-name>.service.nomad`
- Example: `redis.service.consul` instead of `redis` (Docker network)

### 3. Volume Management
- Nomad uses host volumes instead of Docker named volumes
- **Important**: Ensure proper permissions on host directories
- Volumes are specified with full paths in `volumes` stanza
- Consider using NFS or distributed storage for production multi-node deployments

### 4. Network Configuration
- **Bridge mode**: Creates isolated network per task group (similar to Docker Compose networks)
- **Host mode**: Uses host's network stack directly
- **Port allocation**: 
  - `static = X` - Bind to specific host port X
  - `to = Y` - Forward to container port Y
  - Dynamic ports if no `static` specified

### 5. Resource Management
- CPU specified in MHz (e.g., `cpu = 500` means 500 MHz)
- Memory in MB (e.g., `memory = 512` means 512 MB)
- `memory_max` for memory limits with reservation
- More granular control than Docker Compose

### 6. Dependencies and Ordering
- Use `lifecycle` hooks for startup ordering:
  - `hook = "prestart"` with `sidecar = true` - Start before main tasks and keep running
  - `hook = "prestart"` with `sidecar = false` - Run once before main tasks
  - `hook = "poststart"` - Run after main task starts
- Service health checks ensure readiness

## Configuration

### Updating Variables

#### Edit variables.auto.tfvars.hcl
This is the easiest method for permanent changes:

```hcl
# nomad/variables.auto.tfvars.hcl
domain = "my-production-domain.com"
config_path = "/mnt/production/volumes"
puid = 1001
pgid = 121
```

#### Override at Runtime
For temporary overrides without editing files:

```bash
# Override via environment
export NOMAD_VAR_domain="staging.example.com"
nomad job run docker-compose.nomad.hcl

# Override via command line
nomad job run -var="domain=dev.local" docker-compose.nomad.hcl
```

### Secret Management

**For Production**, use HashiCorp Vault integration:

```hcl
template {
  data = <<EOF
OPENAI_API_KEY="{{ with secret "secret/openai" }}{{ .Data.api_key }}{{ end }}"
EOF
  destination = "secrets/api-keys.env"
  env         = true
}
```

**For Development**, the `variables.auto.tfvars.hcl` file contains all secrets from `.env`.

## Deployment

### Prerequisites
1. **Nomad cluster** running (tested with Nomad 1.7+)
2. **Docker runtime** available on all Nomad clients
3. **Host volumes** created with proper permissions:
   ```bash
   sudo mkdir -p /home/ubuntu/my-media-stack/volumes
   sudo chown -R 1001:121 /home/ubuntu/my-media-stack/volumes
   ```

### Deploy Main Stack

```bash
# Navigate to nomad directory
cd /home/ubuntu/my-media-stack/nomad

# Validate the job file
nomad job validate docker-compose.nomad.hcl

# Plan the deployment (dry-run)
nomad job plan docker-compose.nomad.hcl

# Deploy
nomad job run docker-compose.nomad.hcl
```

### Deploy Metrics Stack

```bash
nomad job run metrics.nomad.hcl
```

### Deploy with Custom Variables

```bash
# Create custom variable file
cat > production.hcl <<EOF
domain = "production.example.com"
config_path = "/mnt/production/volumes"
sudo_password = "your-secure-password"
EOF

# Deploy with custom variables
nomad job run -var-file="production.hcl" docker-compose.nomad.hcl
```

## Monitoring and Management

### Check Job Status
```bash
# Overall job status
nomad job status docker-compose-stack

# Detailed allocation status
nomad job status -verbose docker-compose-stack

# Check specific task group
nomad status -group core-services docker-compose-stack
```

### View Logs
```bash
# View logs for entire job
nomad logs -job docker-compose-stack

# View logs for specific task group
nomad logs -job docker-compose-stack -group core-services

# View logs for specific task
nomad logs -job docker-compose-stack -group core-services -task redis

# Follow logs (tail -f equivalent)
nomad logs -f -job docker-compose-stack -task redis

# View stderr
nomad logs -stderr -job docker-compose-stack -task redis
```

### Manage Jobs
```bash
# Stop a job (graceful)
nomad job stop docker-compose-stack

# Stop with purge (removes from job list)
nomad job stop -purge docker-compose-stack

# Restart a job (update with same spec)
nomad job run docker-compose.nomad.hcl

# Scale a task group
nomad job scale docker-compose-stack core-services=2
```

### Service Discovery
```bash
# List all services (requires Consul)
consul catalog services

# Get service details
consul catalog service redis

# DNS resolution
dig redis.service.consul
nslookup redis.service.nomad
```

## Troubleshooting

### Common Issues

#### 1. Port Conflicts
**Symptom**: Job fails with port binding errors

**Solution**:
```bash
# Check what's using the port
sudo lsof -i :443
sudo netstat -tlnp | grep :443

# Update port in variables
nomad job run -var="traefik_https_port=8443" docker-compose.nomad.hcl
```

#### 2. Volume Permission Issues
**Symptom**: Containers can't write to volumes

**Solution**:
```bash
# Fix permissions
sudo chown -R 1001:121 /home/ubuntu/my-media-stack/volumes/redis
sudo chmod -R 755 /home/ubuntu/my-media-stack/volumes/redis
```

#### 3. Service Can't Reach Dependencies
**Symptom**: Application fails to connect to database

**Solution**:
- Ensure services use correct service discovery names
- Check Consul DNS is configured: `consul.service.consul`
- Verify network mode is `bridge` for inter-service communication
- Use `nomad alloc logs <alloc-id>` to see connection errors

#### 4. Job Validation Errors
**Symptom**: `nomad job validate` fails

**Solution**:
```bash
# Check HCL syntax
nomad job validate docker-compose.nomad.hcl

# Format HCL files
nomad fmt docker-compose.nomad.hcl
```

#### 5. Out of Resources
**Symptom**: Job stays in `pending` state

**Solution**:
```bash
# Check cluster capacity
nomad node status

# View why placement failed
nomad job status -verbose docker-compose-stack

# Reduce resource requirements temporarily
nomad job run -var="redis_memory=128" docker-compose.nomad.hcl
```

### Debug Commands
```bash
# Get allocation ID
nomad job status docker-compose-stack

# View allocation details
nomad alloc status <alloc-id>

# View allocation logs
nomad alloc logs <alloc-id> <task-name>

# Execute command in running container
nomad alloc exec <alloc-id> <task-name> /bin/sh

# View recent events
nomad alloc status -verbose <alloc-id>
```

## Migration from Docker Compose

### 1. Stop Docker Compose Services
```bash
cd /home/ubuntu/my-media-stack
docker compose down
```

### 2. Verify Variables
```bash
cd nomad

# Check that variables.auto.tfvars.hcl has all your values
cat variables.auto.tfvars.hcl

# Validate job file
nomad job validate docker-compose.nomad.hcl
```

### 3. Deploy to Nomad
```bash
nomad job run docker-compose.nomad.hcl
```

### 4. Verify Services
```bash
# Check all allocations are running
nomad job status docker-compose-stack

# Test a service
curl -k https://traefik.bolabaden.org/ping
```

## Key Advantages of Nomad

1. **Better Resource Management**: Fine-grained CPU/memory controls with enforced limits
2. **Service Discovery**: Built-in DNS-based service discovery via Consul
3. **Rolling Updates**: Zero-downtime deployments with configurable strategies
4. **Multi-Region**: Deploy across multiple datacenters
5. **Scaling**: Easy horizontal scaling of services
6. **Job Monitoring**: Rich status and event information
7. **Allocation Recovery**: Automatic rescheduling on node failures

## Production Considerations

### Security
1. **Use Vault for Secrets**:
   ```hcl
   template {
     data = <<EOF
   API_KEY="{{ with secret "secret/data/api-keys" }}{{ .Data.data.openai }}{{ end }}"
   EOF
     destination = "secrets/keys.env"
     env         = true
   }
   ```

2. **Enable ACLs**: Use Nomad ACL system for access control
3. **Network Policies**: Configure Consul Connect for service mesh

### High Availability
1. **Run multiple Nomad servers** (3 or 5 for quorum)
2. **Use datacenters** for geographic distribution
3. **Configure constraints** for node placement:
   ```hcl
   constraint {
     attribute = "${node.datacenter}"
     value     = "dc1"
   }
   ```

### Monitoring
1. **Prometheus Integration**: Metrics endpoints exposed
2. **Nomad UI**: http://nomad-server:4646
3. **Consul UI**: http://consul-server:8500
4. **Logs**: Centralized via Loki/Grafana

### Backup Strategy
1. **Volume Snapshots**: Regular backups of host volumes
2. **Nomad State**: Backup Nomad server data directory
3. **Consul State**: Backup Consul data for service catalog

## Advanced Features

### Rolling Updates
```hcl
update {
  max_parallel      = 1
  min_healthy_time  = "10s"
  healthy_deadline  = "5m"
  progress_deadline = "10m"
  auto_revert       = true
}
```

### Canary Deployments
```hcl
update {
  canary       = 1
  max_parallel = 1
  auto_promote = false
  auto_revert  = true
}
```

### Affinities (Prefer certain nodes)
```hcl
affinity {
  attribute = "${node.datacenter}"
  value     = "dc1"
  weight    = 100
}
```

### Spreads (Distribute across nodes)
```hcl
spread {
  attribute = "${node.datacenter}"
  weight    = 100
}
```

## Environment Variable Reference

All variables from `.env` are available in `variables.auto.tfvars.hcl`. To add new variables:

1. **Add to job file**:
   ```hcl
   variable "my_new_var" {
     type    = string
     default = "default-value"
   }
   ```

2. **Add to variables.auto.tfvars.hcl**:
   ```hcl
   my_new_var = "actual-value"
   ```

3. **Use in job**:
   ```hcl
   env {
     MY_VAR = var.my_new_var
   }
   ```

### Variable Types

Nomad supports these types:
- `string` - Text values
- `number` - Numeric values (int or float)
- `bool` - Boolean (true/false)
- `list(type)` - Lists of values
- `map(type)` - Key-value maps
- `object({...})` - Complex nested structures

### Example: Using Lists and Maps

```hcl
# In job file
variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "labels" {
  type    = map(string)
  default = {
    environment = "production"
    team        = "platform"
  }
}

# In variables file
dns_servers = ["1.1.1.1", "1.0.0.1", "8.8.8.8"]
labels = {
  environment = "staging"
  team        = "devops"
}
```

## Updating from .env Changes

When you update your `.env` file and want to sync to Nomad:

### Option 1: Manual Update
Edit `variables.auto.tfvars.hcl` with the new values, then redeploy:
```bash
nomad job run docker-compose.nomad.hcl
```

### Option 2: Script to Convert .env to HCL (Future Enhancement)
```bash
# This could be automated with a script:
# ./scripts/env-to-hcl.sh .env > nomad/variables.auto.tfvars.hcl
```

## Template Blocks for Dynamic Configuration

Nomad supports Go templates for dynamic config generation:

```hcl
template {
  data = <<EOF
# Access environment variable with fallback
LOG_LEVEL="{{ env "LOG_LEVEL" | default "info" }}"

# Access Nomad metadata
NOMAD_ALLOC_ID="{{ env "NOMAD_ALLOC_ID" }}"
NOMAD_GROUP_NAME="{{ env "NOMAD_GROUP_NAME" }}"

# Access Consul key-value
CONFIG="{{ key "service/config" }}"

# Access Vault secret (requires Vault)
API_KEY="{{ with secret "secret/api-key" }}{{ .Data.value }}{{ end }}"
EOF

  destination = "local/config.env"
  env         = true
}
```

### Available Template Functions
- `env "VAR"` - Access environment variable
- `key "path"` - Read from Consul KV
- `secret "path"` - Read from Vault
- `with` - Conditional block
- `range` - Iteration
- `default` - Provide default value
- Many more: https://developer.hashicorp.com/nomad/docs/job-specification/template

## Support and Resources

### Nomad Documentation
- Job Specification: https://developer.hashicorp.com/nomad/docs/job-specification
- Variables: https://developer.hashicorp.com/nomad/docs/job-specification/hcl2/variables
- Templates: https://developer.hashicorp.com/nomad/docs/job-specification/template
- Docker Driver: https://developer.hashicorp.com/nomad/docs/drivers/docker

### Debugging
1. **Enable verbose logging**: Set `NOMAD_LOG_LEVEL=debug`
2. **Check Nomad agent logs**: `journalctl -u nomad -f`
3. **Validate before deploying**: Always run `nomad job validate`
4. **Use plan**: `nomad job plan` shows what will change

### Getting Help
1. Check Nomad server/client logs
2. Verify Consul is healthy (if using service discovery)
3. Review allocation events: `nomad alloc status -verbose <alloc-id>`
4. Check resource availability: `nomad node status`
5. Validate job file syntax: `nomad job validate <file>`

## Examples

### Example: Override Domain for Development

```bash
# Quick test on different domain
export NOMAD_VAR_domain="dev.local"
export NOMAD_VAR_config_path="/tmp/dev-volumes"
nomad job run docker-compose.nomad.hcl
```

### Example: Production Deployment

```bash
# Create production variables
cat > production.hcl <<EOF
domain = "production.company.com"
config_path = "/mnt/production/volumes"
sudo_password = "$(openssl rand -hex 32)"
authentik_secret_key = "$(openssl rand -hex 32)"
# ... other production values
EOF

# Deploy with production config
nomad job run -var-file="production.hcl" docker-compose.nomad.hcl
```

### Example: Update Single Service

```bash
# Modify just the Redis memory allocation
nomad job run -var="redis_memory=1024" docker-compose.nomad.hcl
```

## File Structure

```
nomad/
├── docker-compose.nomad.hcl    # Main job specification
├── metrics.nomad.hcl           # Metrics stack
├── variables.auto.tfvars.hcl   # Auto-loaded variables (from .env)
├── README.md                   # This file
└── production.hcl              # (Optional) Production overrides
```

## Comparison: Docker Compose vs Nomad

| Feature | Docker Compose | Nomad |
|---------|---------------|-------|
| Variable Files | `.env` (automatic) | `*.auto.tfvars.hcl` (automatic) |
| Variable Syntax | `${VAR:-default}` | `var.variable_name` with defaults |
| Environment Override | `export VAR=value` | `export NOMAD_VAR_variable=value` |
| Service Discovery | Docker networks | Consul DNS |
| Health Checks | `healthcheck:` | `service { check { } }` |
| Dependencies | `depends_on:` | `lifecycle { hook = "prestart" }` |
| Resource Limits | `mem_limit`, `cpus` | `resources { cpu, memory }` |
| Secrets | Environment variables | Vault integration |
| Scaling | `docker compose up --scale` | `count` parameter |
| Updates | `docker compose up` | `nomad job run` with update strategies |

## Next Steps

1. **Review Variables**: Check `variables.auto.tfvars.hcl` for accuracy
2. **Validate Jobs**: Run `nomad job validate` on all `.nomad.hcl` files
3. **Test Deploy**: Deploy to development environment first
4. **Monitor**: Watch logs and metrics after deployment
5. **Configure Vault**: Set up HashiCorp Vault for production secrets
6. **Enable Consul**: Configure Consul for service mesh features
