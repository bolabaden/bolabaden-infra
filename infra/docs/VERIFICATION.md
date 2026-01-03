# Constellation Agent Verification Runbook

This document provides step-by-step verification procedures for the Constellation zero-SPOF HA orchestration system.

## Prerequisites

- All nodes have Constellation Agent installed and running
- Tailscale/Headscale is configured and nodes can communicate
- Cloudflare API token is configured
- Docker is running on all nodes

## Verification Checklist

### 1. Gossip Membership

**Objective**: Verify all nodes are discovered and participating in gossip.

**Steps**:
1. Check agent logs on each node:
   ```bash
   journalctl -u constellation-agent -f | grep -i "node joined\|node left\|gossip"
   ```

2. Verify node discovery:
   - All nodes should appear in gossip state
   - Node metadata (IPs, priority) should be correct
   - Last seen timestamps should be recent

**Expected Result**: All nodes visible in gossip, regular heartbeat messages.

### 2. Raft Consensus

**Objective**: Verify Raft cluster is healthy and leader election works.

**Steps**:
1. Check Raft state on each node:
   ```bash
   # Query agent API or check logs
   journalctl -u constellation-agent | grep -i "raft\|leader"
   ```

2. Verify leader election:
   - Exactly one node should be Raft leader
   - Leader should have LB and DNS writer leases
   - Non-leaders should be followers

3. Test leader failover:
   - Kill leader process
   - Wait 5-10 seconds
   - Verify new leader elected
   - Verify leases transferred

**Expected Result**: Single leader, successful failover within 10 seconds.

### 3. Cloudflare DNS Updates

**Objective**: Verify DNS records are updated correctly.

**Steps**:
1. Check current DNS records:
   ```bash
   dig +short ${DOMAIN}
   dig +short "*.${DOMAIN}"
   dig +short "*.${NODE_NAME}.${DOMAIN}"
   ```

2. Verify LB leader DNS:
   - `bolabaden.org` and `*.bolabaden.org` should point to LB leader public IP
   - DNS should update within 30 seconds of leader change

3. Verify per-node DNS:
   - `*.${node}.bolabaden.org` should point to each node's public IP

**Expected Result**: DNS records match current LB leader and node IPs.

### 4. Traefik HTTP Provider

**Objective**: Verify Traefik receives dynamic configuration.

**Steps**:
1. Check Traefik logs:
   ```bash
   docker logs traefik | grep -i "http provider\|dynamic"
   ```

2. Query HTTP provider endpoint:
   ```bash
   curl http://constellation-agent:8081/api/dynamic
   ```

3. Verify config is served:
   - Should return valid JSON
   - Should include routers and services
   - Should update when services change

**Expected Result**: Traefik successfully polls and applies dynamic config.

### 5. Service Routing

**Objective**: Verify service routing works correctly.

**Steps**:
1. Test direct routing (`<service>.<node>.domain`):
   ```bash
   curl -v "https://${SERVICE}.${NODE}.${DOMAIN}"
   ```
   - Should route directly to that node's service
   - Should not failover

2. Test load-balanced routing (`<service>.domain`):
   ```bash
   curl -v "https://${SERVICE}.${DOMAIN}"
   ```
   - Should load balance across healthy nodes
   - Should failover if one node fails

3. Test failover:
   - Stop service on one node
   - Verify traffic continues to other nodes
   - Verify service recovers when restarted

**Expected Result**: Direct routing works, load balancing works, failover works.

### 6. SmartProxy Failover

**Objective**: Verify SmartProxy handles failures correctly.

**Steps**:
1. Test normal operation:
   ```bash
   curl "https://${SERVICE}.${DOMAIN}"
   ```

2. Inject failure (return 503):
   - Stop service container
   - Verify SmartProxy fails over to another node
   - Verify circuit breaker opens after failures

3. Test idempotency:
   - Send GET request - should failover on 5xx
   - Send POST without Idempotency-Key - should NOT failover on 5xx
   - Send POST with Idempotency-Key - should failover on 5xx

**Expected Result**: SmartProxy fails over correctly, respects idempotency rules.

### 7. TCP/UDP Routing

**Objective**: Verify L4 routing works.

**Steps**:
1. Test MongoDB TCP routing:
   ```bash
   mongosh "mongodb://mongodb.${DOMAIN}:27017"
   ```

2. Test Redis TCP routing:
   ```bash
   redis-cli -h redis.${DOMAIN} -p 6379 PING
   ```

3. Test failover:
   - Stop TCP service on one node
   - Verify connection still works (routes to another node)

**Expected Result**: TCP/UDP routing works, failover works.

### 8. Stateful HA

**Objective**: Verify MongoDB and Redis HA.

**Steps**:
1. MongoDB Replica Set:
   - Verify replica set is initialized
   - Check primary node: `mongosh --eval "rs.status()"`
   - Verify secondaries are replicating
   - Test primary failover

2. Redis Sentinel:
   - Verify sentinels are monitoring master
   - Check master: `redis-cli -h <sentinel> -p 26379 SENTINEL GET-MASTER-ADDR-BY-NAME <master-name>`
   - Test master failover
   - Verify new master is elected

**Expected Result**: Stateful services have HA, failover works.

### 9. Network Management

**Objective**: Verify network assignment and health.

**Steps**:
1. Check Docker networks:
   ```bash
   docker network ls | grep -E "backend|publicnet|warp-nat-net"
   ```

2. Verify network assignment:
   - Services with `traefik.enable=true` should be on `publicnet`
   - Services with `network.warp.enabled=true` should be on `warp-nat-net`
   - All services should be on `backend`

3. Test WARP gateway health:
   - Check WARP gateway container health
   - Verify routing works for WARP-enabled services

**Expected Result**: Networks created correctly, services assigned correctly.

### 10. End-to-End Test

**Objective**: Verify complete system operation.

**Steps**:
1. Deploy a test service
2. Verify it appears in gossip state
3. Verify Traefik routes to it
4. Verify DNS resolves correctly
5. Test failover scenarios
6. Verify recovery

**Expected Result**: Complete system works end-to-end.

## Troubleshooting

### Gossip not working
- Check Tailscale connectivity: `tailscale status`
- Check firewall rules
- Verify memberlist bind address is correct

### Raft not electing leader
- Check quorum (need majority of nodes)
- Check Raft data directory permissions
- Check network connectivity between nodes

### DNS not updating
- Verify Cloudflare API token is valid
- Check DNS controller has lease
- Check rate limiting (Cloudflare has limits)

### Traefik not getting config
- Check HTTP provider endpoint is accessible
- Check Traefik logs for errors
- Verify agent is running and serving config

### Services not routing
- Check service health in gossip state
- Verify Traefik routers are created
- Check service labels are correct

## Acceptance Criteria Validation

- [ ] Any node can become LB leader within 10 seconds of leader failure
- [ ] `*.bolabaden.org` and `bolabaden.org` always point to current LB leader
- [ ] `*.{node}.bolabaden.org` always resolves to that node
- [ ] `<service>.<node>.domain` routes to that node's service
- [ ] `<service>.domain` succeeds even if subset of nodes are unhealthy
- [ ] Failover works for configured status codes/transport errors
- [ ] TCP/UDP routing works with failover
- [ ] Health checks validate real protocol functionality
- [ ] Zero config files written by infra/ (everything is function calls)
- [ ] Traefik HTTP provider serves config dynamically (no file I/O)

