### OpenSVC Cluster Bootstrap (Bolabaden)

This is the minimal, repeatable path to build an OpenSVC cluster across existing VPS nodes.

---

### Preconditions

- **Consistent node naming**
  - Each node should have a stable short hostname (ex: `beatapostapita`, `micklethefickle`).
  - DNS should have `A <node>.bolabaden.org -> <node public IP>`.
  - DNS should have `A *.<node>.bolabaden.org -> <node public IP>` (wildcard per node).

- **Docker installed** (we are orchestrating Docker containers as HA services).

---

### Install OpenSVC on each node

On each node:

```bash
cd /home/ubuntu/my-media-stack
./scripts/install_opensvc.sh
```

Notes:
- The installer ensures `python` exists by installing `python-is-python3`.

---

### Verify OpenSVC daemon is running

```bash
sudo om mon
sudo om node ls
```

---

### Join nodes into a cluster

Pick one node as the bootstrap node (first node).

On the first node, capture its reachable listener address (defaults to `https://<ip>:1215`).

On the second node, join:

```bash
sudo om node join --server https://<bootstrap-node-ip>:1215
```

Repeat for additional nodes.

Afterwards, on any node:

```bash
sudo om node ls --format json
sudo om svc ls
```

---

### Ingress sync (HTTP and TCP)

On each node, run:

```bash
cd /home/ubuntu/my-media-stack
./scripts/osvc_ingress_sync.sh
./scripts/osvc_l4_sync.sh
```

- HTTP writes: `${CONFIG_PATH}/traefik/dynamic/failover-fallbacks.yaml`
- TCP writes: `${CONFIG_PATH}/haproxy/haproxy.cfg`

See `docs/osvc_ingress_ha.md` for the DNS + load-balancing expectations.


