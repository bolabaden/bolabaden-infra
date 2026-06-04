# Issues Found and Fixes Applied

## Summary

This document tracks the issues found and fixes applied during the cluster troubleshooting session.

## Issues Identified

### 1. beatapostapita Raft State Corruption
**Problem**: beatapostapita's Raft database contained references to old unreachable servers (cloudserver1, cloudserver2), causing continuous election attempts and instability.

**Fix Applied**:
- Removed Raft database file: `/nomad/data/server/raft/raft.db`
- Cleared all Raft state directories
- Restarted Nomad service

**Status**: ✅ Server is now "alive" in `nomad server members`

### 2. beatapostapita Client Registration Failure
**Problem**: Client was not registering despite server being alive. Logs showed:
- "Permission denied" errors when trying to update node status
- Consul DNS lookup failures: `lookup consul on 127.0.0.53:53: server misbehaving`
- "unrecognized RPC byte" errors suggesting protocol issues

**Fix Applied**:
- Disabled Consul DNS lookup by commenting out `address = "consul:8500"` in `/etc/nomad.d/nomad.hcl`
- This prevents Nomad from trying to discover servers via Consul when Consul isn't available via DNS

**Status**: ⚠️ Client still showing as "down" - Nomad service is crashing (exit code 1)

### 3. MongoDB Lock File Issue
**Problem**: MongoDB allocation failed with error:
```
DBPathInUse: Unable to lock the lock file: /data/db/mongod.lock (Resource temporarily unavailable). Another mongod instance is already running on the /data/db directory
```

**Fix Applied**:
- Removed MongoDB lock file: `/home/ubuntu/my-media-stack/volumes/mongodb/data/mongod.lock`
- Removed any existing MongoDB containers
- Stopped failed allocation to trigger restart

**Status**: ⚠️ Allocation still in "failed" state, needs new allocation

### 4. Consul HA Scaling Blocked
**Problem**: Consul cannot scale to 2 servers because:
- beatapostapita client is down, so Nomad won't place allocations there
- Both Consul instances are on micklethefickle (1 healthy, 1 unhealthy - expected when both on same node)

**Fix Applied**:
- Waiting for beatapostapita client to be ready
- Once ready, Consul should automatically scale via `spread` constraint

**Status**: ⚠️ Blocked by beatapostapita client registration

## Current Cluster Status

### Nomad Servers
- **micklethefickle**: ✅ Alive (Leader)
- **beatapostapita**: ✅ Alive (Follower) - but Nomad service is crashing

### Nomad Clients
- **micklethefickle**: ✅ Ready
- **beatapostapita**: ❌ Down (Nomad service crashing)

### Consul
- **Desired**: 2 servers
- **Placed**: 1 (both on micklethefickle)
- **Healthy**: 0
- **Unhealthy**: 1

### MongoDB
- **Status**: Failed allocation
- **Issue**: Lock file removed, but allocation hasn't restarted

## Remaining Issues

1. **beatapostapita Nomad Service Crash**: Service is in "activating (auto-restart)" state with exit code 1. Need to investigate root cause of crash.

2. **MongoDB Allocation**: Stuck in failed state. Deployment is terminal, so can't fail it. Need to force new allocation or update job.

3. **Consul HA**: Cannot scale until beatapostapita client is ready.

## Next Steps

1. Investigate beatapostapita Nomad service crash - check full logs for fatal errors
2. Force new MongoDB allocation - may need to update job or manually create allocation
3. Once beatapostapita is stable, Consul should automatically scale
4. Test connectivity between all nodes once cluster is stable

