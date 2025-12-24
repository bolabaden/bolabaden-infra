# Continued Fixes - Cluster Stability

## Actions Taken

### 1. beatapostapita Raft State Cleanup
- **Issue**: beatapostapita was trying to reach unreachable servers (cloudserver1, cloudserver2) from old Raft state
- **Fix**: Cleared Raft state on beatapostapita (`/opt/nomad/data/raft/*`, `/var/lib/nomad/raft/*`, `/nomad/data/raft/*`)
- **Result**: Server is now "alive" in `nomad server members`, but client still showing as "down"

### 2. Retry Join Cleanup
- **Issue**: retry_join had old server IPs that were timing out
- **Fix**: Already cleaned to only include micklethefickle (`100.98.182.207:4647`)
- **Status**: ✅ Clean

### 3. MongoDB Allocation
- **Issue**: Allocation `199cae6e` stuck in failed state
- **Attempted**: Tried to restart allocation
- **Status**: ⚠️ Still investigating

## Current Status

### Nomad Cluster
- **Servers**: 2 alive (`micklethefickle` leader, `beatapostapita` follower)
- **Clients**: 1 ready (`micklethefickle`), 1 down (`beatapostapita`)
- **Issue**: beatapostapita client not registering despite server being alive

### Consul
- **Status**: 2 instances placed, both on `micklethefickle`
- **Issue**: Cannot scale to beatapostapita because client is down
- **Deployment**: Failed due to progress deadline (1 healthy, 1 unhealthy on same node)

### MongoDB
- **Status**: Allocation failed, needs restart
- **Data Directory**: Created on micklethefickle
- **Healthcheck**: Added to nomad.hcl

## Next Steps

1. **Investigate beatapostapita Client Registration**:
   - Check why client isn't registering despite server being alive
   - May need to check client configuration or network connectivity
   - UDP ping failures suggest possible firewall issues

2. **Fix MongoDB**:
   - Force new allocation creation
   - Verify data directory permissions
   - Check allocation logs for specific errors

3. **Scale Consul**:
   - Once beatapostapita client is ready, Consul should automatically scale
   - Current deployment will need to be fixed or re-deployed

## Notes

- beatapostapita server connectivity is working (can ping, RPC works)
- Client registration appears to be the blocker for HA scaling
- Both Consul instances on same node causes unhealthy state (expected - they can't form quorum on same node)

