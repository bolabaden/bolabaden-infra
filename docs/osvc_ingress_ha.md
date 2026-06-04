### OpenSVC HA Ingress (Dynamic, Zero Hardcoded Nodes/Services)

This repo already runs **Traefik** for HTTP(S). The missing piece for multi-node HA is **dynamic failover/load-balancing across nodes** without hardcoding node/service names.

This document describes the approach implemented in:
- `scripts/osvc_ingress_sync.py` (generates Traefik file-provider config)
- `scripts/osvc_ingress_sync.sh` (wrapper that loads `.env`)

---

### What this enables

- **Node-scoped hostnames (always hit that node first)**:
  - `https://<service>.<node>.bolabaden.org`
  - DNS resolves to `<node>`; Traefik on that node routes to local container **or** implicitly falls back to another node that has the service.

- **Global hostnames (load-balance/failover across any node running the service)**:
  - `https://<service>.bolabaden.org`
  - DNS/LB must land you on *any* healthy node ingress; that node will route locally or fall back to other nodes automatically.

---

### DNS requirements (Cloudflare)

To satisfy `service.node.domain` without hardcoding service names:

- **Per-node records**
  - `A <node>.bolabaden.org -> <node public IP>`
  - `A *. <node>.bolabaden.org -> <node public IP>`

Your `cloudflare-ddns` container already supports managing:
- `$TS_HOSTNAME.$DOMAIN`
- `*.$TS_HOSTNAME.$DOMAIN`

To satisfy `service.domain` load balancing, you need **one** of:

- **Option A (Best: zero-SPOF ingress)**: Cloudflare Load Balancer
  - Create a LB for `*.bolabaden.org` (or for selected subdomains) with origins = your nodes.
  - Health checks should hit a known stable endpoint (ex: `https://whoami.<node>.bolabaden.org/`).

- **Option B (Self-hosted VIP)**: keepalived VRRP floating IP + node ingress
  - Requires network that supports a shared VIP.
  - Traefik binds the VIP and fails over with keepalived.

- **Option C (Good enough)**: DNS round-robin A records
  - `A *.bolabaden.org -> <node1 IP>, <node2 IP>, ...`
  - Not strictly “zero spof” because clients can cache a dead node until TTL.

---

### How the Traefik failover config is generated

Run on each node:

```bash
./scripts/osvc_ingress_sync.sh
```

It:
- Reads nodes from OpenSVC: `om node ls --format json`
- Reads Traefik-enabled **HTTP** containers from Docker (`traefik.enable=true` + `traefik.http.*` labels)
- Writes: `${CONFIG_PATH}/traefik/dynamic/failover-fallbacks.yaml`

Traefik is already configured with:
- `--providers.file.directory=/traefik/dynamic/`
- `--providers.file.watch=true`

So updating the file updates routing dynamically.

---

### TCP (Redis/Mongo/etc.)

Plain TCP can’t be routed by hostname without TLS/SNI.

To get:
- `redis://redis.<node>.bolabaden.org:6379`
- `redis://redis.bolabaden.org:6379`

…you need an L4 load balancer per port (example: HAProxy in `network_mode: host`) and **true datastore HA** (Redis Sentinel/Cluster, Mongo replica set, etc.). This is planned next.


