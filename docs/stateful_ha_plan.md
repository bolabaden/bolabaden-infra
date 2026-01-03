### Stateful HA (Zero-SPOF) Plan

You can’t get “zero SPOF including stateful services” by *only* moving containers between nodes.

Stateful HA requires **replication + quorum** (or replicated block storage) so that losing one node does not lose the data and does not stop writes.

This document is the pragmatic plan for this repo.

---

### 0) Ingress reality check (TCP vs hostname)

- **HTTP(S)** can be routed by hostname (Host header/SNI) and we already generate dynamic failover config for Traefik.
- **Plain TCP** (like `redis://…`) cannot be routed by hostname unless you terminate TLS and use SNI.
  - So for TCP we load-balance by **port** (ex: 6379) and rely on DNS/LB to land you on any node.
  - See `scripts/osvc_l4_sync.py` + `compose/docker-compose.l4-ingress.yml`.

---

### 1) Redis (recommendation: Redis Sentinel + HAProxy master routing)

**Goal**: `redis://redis.<node>.bolabaden.org:6379` and `redis://redis.bolabaden.org:6379` always connect to the *current master*.

Minimum topology (3 nodes):
- 1 Redis master
- 2 Redis replicas
- 3 Sentinels (one per node)

Failover:
- Sentinels elect a new master automatically.
- HAProxy performs a protocol-aware check and forwards clients to the master.

Notes:
- This is operationally simpler than Redis Cluster for “single logical Redis” usage.
- For strict zero-SPOF you want 3 nodes so Sentinel quorum survives 1 node loss.

---

### 2) MongoDB (recommendation: Replica Set)

Minimum topology (3 nodes):
- 1 primary
- 2 secondaries

Client behavior:
- Drivers handle failover if they can see multiple members.

Two ways to make it “one hostname”:
- **Best**: Mongo SRV records (`mongodb+srv://…`) with records generated from cluster membership.
- **Acceptable**: Provide a seed list in the connection string (`mongodb://host1,host2,host3/?replicaSet=rs0`).

We can generate SRV + A records from OpenSVC membership, but it requires Cloudflare DNS API automation.

---

### 3) Postgres (if you add it later)

Options:
- **Patroni + etcd** (strong HA, more moving parts)
- **Repmgr** (simpler)
- **Citus/Spilo** variants (opinionated)

Recommendation for “zero bullshit”:
- Use a managed Postgres if possible, or keep Postgres to a single node until the rest is stable.

---

### 4) Files/Volumes (the hardest part)

Anything that uses bind-mounts like `${CONFIG_PATH}/...` becomes node-local state.

To make it HA you need:
- **Distributed filesystem** (CephFS, GlusterFS) or
- **Replicated block devices** (DRBD) + a filesystem + single active writer at a time.

For this stack, the minimal workable path is:
- Keep most app config volumes node-local initially.
- Make only the truly critical datastores replicated (Redis/Mongo).
- Promote shared volumes later once ingress + scheduling are stable.

---

### 5) What we will do next in this repo

- Introduce opt-in labels for L4 services (Redis, Mongo, etc.) so `scripts/osvc_l4_sync.py` can generate per-port HAProxy frontends/backends dynamically.
- Add a Cloudflare DNS automation script to keep:
  - per-node wildcard records (`*.node.domain`)
  - optional global wildcard (`*.domain`) via LB/VIP
  - optional Mongo SRV records for replica set discovery


