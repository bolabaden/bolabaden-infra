# Action Required to Achieve 100% Compliance
Generated: $(date)

## Current Status: ~70% Complete

### ✅ What's Working
- **4 HA Services at Full Capacity**: searxng (2/2), homepage (2/2), bolabaden-nextjs (2/2), litellm (2/2)
- **Critical Services Running**: mongodb, redis, traefik, aiostreams, stremio, and 20+ others
- **Service Discovery**: 30 services registered in Consul
- **1:1 Parity**: ~95% (firecrawl resources fixed)

### ❌ Critical Blockers

## BLOCKER 1: Consul Single Point of Failure (CRITICAL)

**Current**: 1 Consul server (micklethefickle)
**Required**: 3+ Consul servers for HA
**Impact**: If Consul fails, ALL service discovery fails

**Fix Required**:
```bash
# Option 1: Deploy Consul as Nomad job with count=3
# Create nomad/jobs/docker-compose.consul.nomad.hcl with:
# - count = 3
# - spread constraints
# - cluster mode (not bootstrap)

# Option 2: Deploy Consul on cloudserver1 via docker-compose
# SSH to cloudserver1 and deploy Consul there

# Option 3: Use systemd service on multiple nodes
```

**Priority**: CRITICAL - Must fix before production

## BLOCKER 2: Firecrawl Dependencies Missing Images

**Issue**: playwright-service and nuq-postgres use local images that don't exist
- `my-media-stack-playwright-service:local` - NOT FOUND
- `my-media-stack-nuq-postgres:local` - NOT FOUND

**Root Cause**: docker-compose.yml uses `build:` statements, but Nomad can't build images

**Fix Required**:
```bash
# Option 1: Build images locally and tag them
cd /home/ubuntu/my-media-stack
docker build -t my-media-stack-playwright-service:local \
  https://github.com/firecrawl/firecrawl.git#main:/apps/playwright-service-ts
docker build -t my-media-stack-nuq-postgres:local \
  https://github.com/firecrawl/firecrawl.git#main:/apps/nuq-postgres

# Option 2: Use pre-built images if available
# Check if ghcr.io/firecrawl/playwright-service exists for ARM64
# Update nomad/nomad.hcl to use registry images

# Option 3: Set up CI/CD to build and push images to registry
```

**Priority**: HIGH - Blocks firecrawl service

## BLOCKER 3: HA Services Not at Full Capacity

**Issue**: 3 HA services not running at full count
- aiostreams-group: 1/2 running (1 starting)
- stremio-group: 1/2 running (1 queued)
- traefik-group: 1/3 running (2 queued)

**Fix Required**:
```bash
# Force new evaluation
nomad job eval docker-compose-stack

# Check placement constraints
nomad job status docker-compose-stack | grep -A5 "aiostreams-group\|stremio-group\|traefik-group"

# Verify node capacity
nomad node status
nomad node status <node-id>

# If nodes have capacity, may need to:
# 1. Remove constraints preventing placement
# 2. Increase node resources
# 3. Reduce resource requirements for other services
```

**Priority**: MEDIUM - Reduces failover capacity

## BLOCKER 4: Down Nodes

**Issue**: 2 nodes down (beatapostapita, cloudserver2)
**Impact**: 50% node availability, reduced failover capacity

**Fix Required**:
```bash
# SSH to each down node and check:
ssh beatapostapita
systemctl status nomad
journalctl -u nomad -n 50
# Check network connectivity
# Restart Nomad if needed: systemctl restart nomad

ssh cloudserver2.bolabaden.org
# Same checks

# If nodes are unrecoverable:
# Remove from cluster or mark as ineligible
nomad node eligibility -disable <node-id>
```

**Priority**: MEDIUM - Reduces capacity and failover options

## BLOCKER 5: Dozzle Service Failing

**Issue**: 55 failed attempts, container exits with code 1
**Impact**: Log viewer unavailable (non-critical service)

**Fix Required**:
```bash
# Check latest allocation logs
nomad alloc logs <allocation-id> dozzle

# Verify dockerproxy-ro is accessible
consul catalog service dockerproxy-ro

# Check if dozzle can reach dockerproxy-ro
# May need to adjust network configuration or dependencies
```

**Priority**: LOW - Non-critical service

## Step-by-Step Fix Plan

### Step 1: Fix Consul HA (CRITICAL - Do First)
1. Create Consul Nomad job with count=3
2. Configure cluster mode (not bootstrap)
3. Add spread constraints
4. Deploy and verify 3+ servers
5. Test failover

### Step 2: Build Firecrawl Images
1. Build playwright-service image
2. Build nuq-postgres image
3. Tag as local images
4. Verify images exist: `docker images | grep playwright`
5. Resubmit Nomad job

### Step 3: Scale HA Services
1. Force new evaluation
2. Check placement constraints
3. Verify node capacity
4. Adjust if needed
5. Monitor until all at full count

### Step 4: Restore Down Nodes
1. SSH to each node
2. Diagnose issue
3. Fix or remove from cluster
4. Update any node-specific constraints

### Step 5: Fix Dozzle (Optional)
1. Investigate failure
2. Fix configuration
3. Verify service starts

## Verification Checklist

After fixes, verify:
- [ ] Consul: 3+ servers running
- [ ] Firecrawl: playwright-service, nuq-postgres, firecrawl all running
- [ ] HA Services: All at full count (searxng 2/2, homepage 2/2, etc.)
- [ ] Nodes: All 4 nodes operational
- [ ] Services: All critical services running
- [ ] 1:1 Parity: All services match docker-compose.yml
- [ ] Zero SPOF: No single points of failure

## Expected Final State

| Requirement | Target | Current | After Fixes |
|------------|--------|---------|-------------|
| 1:1 Parity | 100% | 95% | 100% |
| Fully Healthy | 100% | 90% | 100% |
| Complete Failover | 100% | 70% | 100% |
| Zero SPOF | 100% | 0% | 100% |
| All Nodes | 100% | 50% | 100% |

**Overall Target**: 100% compliance
**Current**: ~70%
**After Fixes**: 100% ✅

