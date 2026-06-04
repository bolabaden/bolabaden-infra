# Nomad Cluster Health Check Report
Generated: $(date)

## Executive Summary

### ✅ Working Services (Running)
- homepage-group (1/2 running - HA enabled)
- searxng-group (1/2 running - HA enabled)
- bolabaden-nextjs-group (1/2 running - HA enabled)
- redis-group (1/1 running)
- nuq-postgres-group (1/1 running)
- aiostreams-group (1/2 running - HA enabled)
- stremio-group (1/2 running - HA enabled)
- traefik-group (1/3 running - HA enabled)
- litellm-postgres-group (1/1 running)
- qdrant-group (1/1 running)
- And 10+ other services

### ❌ Failed Services (Not Running)
- **mongodb-group**: 0 running, 3 failed
- **firecrawl-group**: 0 running, 29 failed
- **litellm-group**: 0 running, 4 failed
- **playwright-service-group**: 0 running, 29 failed
- **dozzle-group**: 0 running, 54 failed
- **telemetry-auth-group**: 0 running, 3 failed
- **gptr-group**: 0 running, 1 failed
- **open-webui-group**: 0 running, 1 failed
- **mcp-proxy-group**: 0 running, 1 failed

## Cluster Infrastructure

### Nomad Nodes
- **Ready**: 2 nodes (micklethefickle, cloudserver1.bolabaden.org)
- **Down**: 2 nodes (beatapostapita, cloudserver2.bolabaden.org)
- **Status**: ⚠️ 50% node availability - Single point of failure risk

### Nomad Servers
- **Active**: 2 servers (micklethefickle [Leader], cloudserver1)
- **Status**: ✅ Healthy (quorum maintained)

### Consul Servers
- **Active**: 1 server (micklethefickle)
- **Status**: ⚠️ **CRITICAL** - Single point of failure! Need minimum 3 for HA

## High Availability Analysis

### Services with HA (count > 1)
1. searxng-group: count=2 ✅
2. homepage-group: count=2 ✅
3. bolabaden-nextjs-group: count=2 ✅
4. aiostreams-group: count=2 ✅
5. stremio-group: count=2 ✅
6. traefik-group: count=3 ✅
7. litellm-group: count=2 ✅

### Services WITHOUT HA (count = 1) - Single Points of Failure
- mongodb-group: count=1 ⚠️
- redis-group: count=1 ⚠️
- nuq-postgres-group: count=1 ⚠️
- litellm-postgres-group: count=1 ⚠️
- playwright-service-group: count=1 ⚠️
- firecrawl-group: count=1 ⚠️
- dozzle-group: count=1 ⚠️
- And 20+ other services

## Critical Issues

### 1. Consul Single Point of Failure
- **Issue**: Only 1 Consul server running
- **Impact**: If Consul fails, all service discovery fails
- **Fix**: Deploy 3+ Consul servers across different nodes

### 2. Failed Critical Services
- **mongodb**: Database not running - affects all services that depend on it
- **firecrawl**: Web crawling service not running
- **litellm**: LLM gateway not running
- **playwright-service**: Required by firecrawl, not running
- **dozzle**: Log viewer not running (54 failed attempts)

### 3. Node Availability
- **Issue**: 2 of 4 nodes are down
- **Impact**: Reduced capacity, no failover for services on down nodes
- **Fix**: Investigate and restore down nodes or remove from cluster

### 4. HA Configuration Gaps
- **Issue**: Many critical services have count=1
- **Impact**: No failover if service crashes or node fails
- **Fix**: Increase count for critical services, add spread constraints

## Recommendations

### Immediate Actions
1. **Fix Consul HA**: Deploy 2 more Consul servers
2. **Fix MongoDB**: Investigate why it's failing and restore
3. **Fix Firecrawl Dependencies**: Ensure playwright-service and nuq-postgres are running
4. **Fix Dozzle**: Investigate 54 failed attempts
5. **Restore Down Nodes**: Investigate beatapostapita and cloudserver2

### High Availability Improvements
1. **Increase Count for Critical Services**:
   - redis-group: count=2 (with Redis Sentinel or cluster mode)
   - mongodb-group: count=1 (OK - MongoDB handles replication internally)
   - Add spread constraints to all HA services

2. **Add Health Checks**:
   - Ensure all services have proper health checks
   - Verify health check intervals match docker-compose

3. **Update/Migrate Strategy**:
   - Ensure all services have update and migrate blocks
   - Configure proper health check timeouts

### 1:1 Parity Verification
- Compare each service in nomad.hcl with docker-compose.yml
- Verify:
  - Image names match
  - Environment variables match
  - Volume mounts match
  - Health checks match
  - Resource limits match
  - Network configuration matches

## Next Steps
1. Investigate and fix failed services
2. Deploy additional Consul servers
3. Restore down nodes or remove from cluster
4. Increase HA for critical services
5. Verify 1:1 parity with docker-compose.yml

