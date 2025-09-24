# bolabaden.org: how the "no-swarm, no-cluster" multi-node setup works

## Table of Contents

- [Overview](#overview)
- [The Core Idea](#the-core-idea)
- [Components at a glance](#components)
- [Request Flow](#what-happens-when-someone-visits-bolabadenorg)
- [Multi-Node Layout](#1-multi-node-layout)
- [DNS and Failover](#2-dns-and-failover)
- [Service Discovery](#3-service-discovery)
- [Internal Failover & Routing](#4-internal-failover--routing)
- [Configuration Management](#how-config-actually-becomes-live-behavior)
- [Observability](#observability)
- [Hosting bolabaden.org](#hosting-bolabadenorg-specifically)
- [Problems I expect, and how I’m handling them](#problems-i-expect-and-how-im-handling-them)
- [Failure Scenarios](#failure-stories-on-purpose)
- [Trade-offs](#where-im-okay-with-tradeoffs)
- [Implementation Details](#what-still-needs-real-values-placeholders-to-fill)
- [Testing Checklist](#sanity-checklist-before-i-call-it-done-enough)
- [Complete Flow](#5-the-complete-flow-for-bolabadenorg)
- [Remaining Considerations](#6-remaining-considerations)
- [Summary](#-summary)

---

## Overview {#overview}

When I set out to host **bolabaden.org** across multiple nodes, I had one guiding principle: **unification without a central orchestrator, and zero single points of failure**. I didn’t want Swarm, Kubernetes, or anything heavy-handed. I just wanted things to work reliably, even if a node went offline. Here’s how the flow looks, the challenges at each step, and how I solved them.

I’ve got a handful of Docker hosts (call them `node1`, `node2`, `node3`). I don’t want Kubernetes, I don’t want Swarm. I’m fine manually deciding where a container runs. I just want requests to land anywhere and still find the right service—even if that service lives on a different node.

At the DNS tier I use Cloudflare with multiple A records for `*.bolabaden.org`, one per node (each node updates its own A record via DDNS). That gives me basic scatter/gather: a client hits any node. After that, it becomes each node’s job to either serve the request locally or bounce it—cleanly—to a peer that actually has the service.

## The core idea {#the-core-idea}

### Components at a glance {#components}

Every node runs the same “edge” stack:

* **L7 reverse proxy** for HTTP(S): Traefik v3 (file provider) with health-checked primary+fallback failover.
* **L4 proxy** for raw TCP stuff like Redis.
* A tiny **service registry** (just a file, seriously) that lists which services exist and which nodes claim to host them.
* A lightweight **watcher** that turns that registry into live proxy config and reloads the proxy without dropping connections.
* Health checks so dead targets get pulled out automatically.

No schedulers. No leaders. No replicas knob. Just: *if you ask this node for `X` and `X` isn’t here, we’ll forward you to a node that has `X`.*

---

## What happens when someone visits bolabaden.org {#what-happens-when-someone-visits-bolabadenorg}

**Flow (HTTP):**

```
User -> DNS (Cloudflare) -> node2 (picked by DNS)
  node2: edge proxy sees Host: bolabaden.org
    - If local container exists: serve it (fast path)
    - Else: look up bolabaden.org in the service registry:
        -> has backends on node1 and node3
        -> pick one that's healthy and forward (L7 proxy, keep TLS intact)
```

**Flow (Redis / TCP):**

```
Client -> DNS -> node1
  node1: L4 proxy for "redis-main"
    - If local port is bound: connect locally
    - Else: pick a healthy remote redis endpoint from registry and TCP proxy
```

If the request lands on the “wrong” node, it still succeeds. That’s the entire trick.

---

## The only hard part: service discovery (but small) {#the-only-hard-part-service-discovery-but-small}

I’m not deploying a service mesh. I’m not standing up etcd or a big gossip ring. I’m using a single **YAML file** as the source of truth, synced to every node. Updating that file is not the price I pay for not running an orchestrator: it simplifies the mental model. When the file gets too large we simply use docker compose's `include:` functionality. A tiny daemon watches the file, templates the proxy configs, and reloads. See [Service discovery](#3-service-discovery) for the full breakdown.

With that in mind, here’s how the nodes are laid out and how requests traverse them.

## 1. Multi-node layout {#1-multi-node-layout}

I have multiple servers — let’s call them `node1`, `node2`, `node3`. Each node can run any service, from web apps to Redis instances. I wanted a setup where any request hitting **any node** would always find the service it needs.

**Problem:** If a user hits `dozzle.bolabaden.org` on `node1`, and that service isn’t running there, I still need the request to succeed.

**Solution:** L4/L7 failover across nodes.

* For HTTP: each node runs Traefik v3 (L7) with primary+fallback failover. If the request hits a local service, it’s served immediately; otherwise it forwards to a healthy backend on another node.
* For TCP/Redis: each node runs an L4 load balancer that can forward requests to the node hosting the desired service.

**Flow example:**

```
User → node1 (HTTP request for dozzle.bolabaden.org)
  ├─ if service exists locally → serve
  └─ else → L7 forward → node2/node3
       └─ request served
```

* Distribution can be Git + pull, `rsync`, Syncthing—pick your poison.
* Each node keeps a **last-known-good** copy; if distribution hiccups, the world doesn’t end.
* Health checks run locally, so even if the registry says “node3 has `dozzle`,” it won’t be used if `node3` fails checks.

**Registry sketch (placeholder):**

```yaml
# /etc/bolabaden/services.yaml
version: 1
http:
  bolabaden.org:
    backends:
      - host: node1.bolabaden.org
        port: 8080
      - host: node2.bolabaden.org
        port: 8080
  dozzle.bolabaden.org:
    backends:
      - host: node3.bolabaden.org
        port: 9999
tcp:
  redis-main:
    port: 6379
    backends:
      - host: node1.bolabaden.org
        port: 6379
      - host: node2.bolabaden.org
        port: 6379
# add more services here
```

**Notes:**

* This file describes *where services live*, not where they *should* live. I place services manually by starting containers on the nodes I choose.
* Health checks + weights live in the proxy layer; the registry stays simple.

---

 

## 2. DNS and failover {#2-dns-and-failover}

**Problem:** How to avoid downtime if a node goes completely offline?

**Solution:** Cloudflare with multiple A records. Each node’s public IP is in DNS for `*.bolabaden.org`.

* If `node1` is down, DNS will resolve to `node2` or `node3`.
* Combined with the L4/L7 forwarding on each node, users rarely ever hit a dead end.

**Placeholder for configuration:**

```
*.bolabaden.org → node1_public_ip
*.bolabaden.org → node2_public_ip
*.bolabaden.org → node3_public_ip
TTL: [your TTL]
```

This gives me **multi-node failover at the network level**, without relying on a central orchestrator. Application-layer failover is handled by Traefik at the service level (primary + fallback).

---

## 3. Service discovery {#3-service-discovery}

Here’s where it gets tricky. With DNS and failover handling node-level downtime, I still need to know **which node has which service**.

**Problem:** A request might hit `node1`, but `dozzle` is only running on `node3`. How do I dynamically know where to send it?

**Solution:** Lightweight, node-aware service registry.

* Could be a simple JSON/YAML file shared across nodes, listing services and which node they are on.
* Could also be a gossip-based system (Serf, lightweight Consul).
* Each node’s L7 proxy (Traefik v3 file provider) reads generated dynamic config that defines primary+fallback per service and forwards accordingly.

### 6) Observability so I’m not guessing {#6-observability-so-im-not-guessing}

Per-node metrics + logs go to a small stack (Loki + Promtail, or just filebeat to Elasticsearch, whatever). I want to see:

* health check failures,
* upstream latencies,
* request rates per service,
* and which node is actually serving what.

**Placeholder: scrape config**

```yaml
# observability.yaml (placeholder)
metrics:
  prometheus_scrape_targets:
    - node1:9100
    - node2:9100
    - node3:9100
  proxy_exporter: ":9113"
logs:
  shipper: promtail
  targets:
    - /var/log/nginx/*.log
    - /var/log/haproxy.log
```

---

## Hosting bolabaden.org specifically {#hosting-bolabadenorg-specifically}

`bolabaden.org` is the main website. I want it up even if only one node has the container.

The website is built with Next.JS. Until I plan to do server-side routing or anything that requires the docker socket/redis implementation in nodejs specifically, I have zero reason to host this on my docker nodes. So currently, it's running on GitHub Pages.

* The **container** for the site runs on whichever node(s) I choose (at least one).
* All nodes terminate TLS for `bolabaden.org`.
* If a node without the container receives the request, it forwards to a node that does.

I have two ways to keep it fast:

1. **Run the site container on 2+ nodes** so most requests are served locally. (Forwarding still covers me if one of those nodes is missing or down.)
2. **Edge caching** for static assets (Cloudflare can help, or the L7 proxy can cache for a bit). That way forwarding doesn’t hurt perceived performance for images/CSS/JS.

**Placeholder: site entry**

```yaml
http:
  bolabaden.org:
    cache: "static, 10m" # edge cache policy (placeholder)
    backends:
      - host: node1.bolabaden.org
        port: 8080
      - host: node2.bolabaden.org
        port: 8080
```

---

## How config actually becomes live behavior {#how-config-actually-becomes-live-behavior}

There’s a tiny watcher on each node that does:

1. Parse `/etc/bolabaden/services.yaml`.
2. Render proxy configs from templates.
3. Reload the proxy safely (graceful, no dropped connections).
4. Run health checks continuously and update backend weights or mark them down.

**Placeholder: watcher settings**

```yaml
# /etc/bolabaden/watcher.yaml (placeholder)
source: /etc/bolabaden/services.yaml
templates:
  - input: /etc/bolabaden/templates/traefik-http.tmpl
    output: /etc/traefik/dynamic/bolabaden.yaml
    reload: ["systemctl", "reload", "traefik"]
  - input: /etc/bolabaden/templates/tcp.tmpl
    output: /etc/haproxy/haproxy.d/bolabaden.cfg
    reload: ["systemctl", "reload", "haproxy"]
health_checks:
  interval: 2s
  timeout: 500ms
  consecutive_failures: 3
  recovery: 2
```

I can test changes locally (dry-run render), then ship the registry file to all nodes. If something goes sideways, the last-known-good config stays in place.

---

## Observability (so I’m not guessing) {#observability}

Per-node metrics + logs go to a small stack (Loki + Promtail, or just filebeat to Elasticsearch, whatever). I want to see:

* health check failures,
* upstream latencies,
* request rates per service,
* and which node is actually serving what.

**Placeholder: scrape config**

```yaml
# observability.yaml (placeholder)
metrics:
  prometheus_scrape_targets:
    - node1:9100
    - node2:9100
    - node3:9100
  proxy_exporter: ":9113"
logs:
  shipper: promtail
  targets:
    - /var/log/nginx/*.log
    - /var/log/haproxy.log
```

---

## Problems I expect, and how I’m handling them {#problems-i-expect-and-how-im-handling-them}

### 1) “But isn’t Cloudflare a SPOF?” {#1-but-isnt-cloudflare-a-spof}

It’s a dependency, yes, but I’m not using Cloudflare as a control plane—just DNS. Multiple A records spread load; clients cache results; if one node dies, health checks at the edge stop sending to it. If I wanted to be extra-paranoid, I could add a secondary DNS provider, but that’s not today’s problem.

### 2) “What if the registry is stale?” {#2-what-if-the-registry-is-stale}

Each edge does active health checks. If the registry says “node3 has `dozzle`” but node3 is down, traffic won’t go there. Worst case, a brand-new service takes a minute to be recognized (until the registry syncs), which is acceptable.

### 3) TLS and certificates {#3-tls-and-certificates}

Terminating TLS at the edge node that receives traffic is easiest. For cross-node proxying I keep TLS to the backend (or use trusted internal certs) so I avoid mixed-content headaches and keep things private over the inter-node network.

---

## Failure stories (on purpose) {#failure-stories-on-purpose}

* **Node dies:** DNS still points to it, but clients also hit other nodes. On the dead node, nothing answers; on the live nodes, health checks have already removed the dead backends from upstream pools, so forwarded requests avoid the corpse. When DNS TTL rolls, fewer clients pick the dead IP.

* **Service moves from node3 to node1:** I update `services.yaml`, distribute it, watcher reloads, traffic starts flowing to node1. If I’m late updating the file, forwarding still works via the old mapping (worst case, a few 502s during the cutover if I get the order wrong—so I drain before stopping).

* **Registry stops syncing:** Nothing blows up. Proxies keep the last config. Health checks keep things safe.

---

## Where I’m okay with tradeoffs {#where-im-okay-with-tradeoffs}

* **Yes, there’s coordination,** but it’s a small file and local health checks—not a full control plane.
* **Yes, a request might hop nodes,** but TLS stays intact and the hop is (relatively) fast, especially when used on LAN.
* **Yes, Redis isn’t magically multi-primary,** but I prefer explicit primary/standby to mystery replication.

---

## What still needs real values (placeholders to fill) {#what-still-needs-real-values-placeholders-to-fill}

* Cloudflare DNS creds and ACME DNS-01 details.
* Proxy choices: Traefik v3 for HTTP (file/docker/redis provider and tcp), and the corresponding templates.
* Health check endpoints/ports per service (`/_healthz` or whatever).
* The distribution mechanism for `services.yaml` (Git repo URL or Syncthing config).
* Redis failover story (manual runbook or Sentinel config).

**Drop-in spots for those:**

```yaml
# /etc/bolabaden/secrets.env (placeholder)
CF_API_TOKEN=...
CF_ZONE_ID=...

# /etc/bolabaden/services.yaml (fill me)
# /etc/bolabaden/templates/http.tmpl (fill me)
# /etc/bolabaden/templates/tcp.tmpl (fill me)

# /etc/bolabaden/distribution.yaml (pick one)
method: git
repo: git@github.com:me/bolabaden-infra.git
branch: main
```

---

## Sanity checklist before I call it “done enough” {#sanity-checklist-before-i-call-it-done-enough}

* [ ] `curl -H "Host: bolabaden.org" http://<each node>` returns the site.
* [ ] `curl -H "Host: dozzle.bolabaden.org" http://<each node>` returns Dozzle from whichever node actually runs it.
* [ ] Kill a backend container → edge removes it after N failures → traffic shifts.
* [ ] Stop the registry sync → no traffic outage.
* [ ] TLS renews via DNS-01 with no downtime.
* [ ] Redis primary restart → either sentinel/manual failover works and L4 proxy follows.


**Flow example:**

```
User → node1 (HTTP request for dozzle.bolabaden.org)
  ├─ node1 checks registry → dozzle is on node3
  └─ node1 forwards request → node3
       └─ node3 serves request
```

This ensures **unified service discovery** without a “master node” that could fail.

---

## 4. Internal failover & routing {#4-internal-failover--routing}

Even if DNS resolves to a node that’s alive, the requested service might still be unavailable on that node. That’s why the **L4/L7 forwarding layer** is critical.

* For HTTP: Traefik v3 uses registry-generated dynamic config with a primary service and a fallback pool per service.
* For TCP/Redis: HAProxy (or equivalent) checks which node is live for the requested port/service, then forwards.
* Health checks: each node regularly verifies its peers’ services and updates the registry dynamically.

This **eliminates single points of failure**:

* No single orchestrator node.
* No single service node.
* DNS + proxies + registry together handle failover.

---

## 5. The complete flow for bolabaden.org {#5-the-complete-flow-for-bolabadenorg}

1. **User visits `bolabaden.org`**
2. DNS resolves to one of the nodes (say, node1).
3. node1’s reverse proxy receives the request:

   * Checks if the requested service exists locally.
   * If yes → serves it.
   * If no → looks up registry → forwards to correct node (node2 or node3).
4. The node hosting the service responds.
5. If that node fails mid-request, health checks update the registry and next requests are forwarded to surviving nodes.

At every layer, there’s **redundancy**:

* DNS provides multi-node entry points.
* L4/L7 forwarding ensures cross-node routing.
* Registry ensures dynamic awareness of services.

---

## 6. Remaining considerations {#6-remaining-considerations}

* **Redis clustering:** Need replication or sharding to avoid losing data if a node dies.
* **Registry updates:** Must propagate quickly to prevent stale routing.
* **Certificates / TLS:** Must be synced across nodes for HTTPS.
* **Load balancing policies:** Round-robin vs least connections depending on service type.

**Placeholders for final configurations:**

```
# L7 proxy config example (Traefik v3 file provider)
# yaml-language-server: $schema=https://www.schemastore.org/traefik-v3-file-provider.json
http:
  routers:
    catchall:
      service: noop@internal
      rule: Host(`bolabaden.org`) || Host(`beatapostapita.bolabaden.org`) || HostRegexp(`^(.+)$`)  # Note: leave the Host() rules for bolabaden.org || beatapostapita.bolabaden.org here! otherwise traefik spams an annoying warning. Doesn't affect functionality though.
      priority: 0
      middlewares:
        - strip-www@file
        - http-to-https-redirect-simple@file
    whoami-with-failover:
      service: whoami-with-failover@file
      rule: Host(`whoami.bolabaden.org`)
    whoami-direct:
      service: whoami-direct@file
      rule: Host(`whoami.beatapostapita.bolabaden.org`)
  services:
    whoami-with-failover:
      failover:
        service: whoami-direct@file
        fallback: whoami-servers@file
    whoami-direct:
      loadBalancer:
        servers:
          - url: http://whoami:80
        healthCheck:
          path: "/"
          interval: "15s"
          timeout: "5s"
    whoami-servers:
      loadBalancer:
        servers:
          - url: http://whoami:80
          - url: https://whoami.beatapostapita.bolabaden.org
          - url: https://whoami.beatapostapita.bolabaden.org
          - url: https://whoami.vractormania.bolabaden.org
          - url: https://whoami.arnialtrashlid.bolabaden.org
          - url: https://whoami.cloudserver1.bolabaden.org
          - url: https://whoami.cloudserver2.bolabaden.org
          - url: https://whoami.cloudserver3.bolabaden.org
        healthCheck:
          path: "/"
          interval: "15s"
          timeout: "5s"
  middlewares:
    strip-www:
      redirectRegex:
        regex: '^(http|https)?://www\.(.+)$'
        replacement: '${1}://${2}'
        permanent: false
    http-to-https-redirect-simple:
      redirectScheme:
        scheme: https
        permanent: false

# L4 proxy for Redis
frontend redis_front
    bind *:6379
    default_backend redis_back

backend redis_back
    server redis_node2 node2_ip:6379 check
    server redis_node3 node3_ip:6379 check
```

---

### ✅ Summary {#-summary}

I plan to build a **multi-node, fully unified hosting environment** with:

* Manual scheduling, where I will decide where services run
* Node-level failover via DNS
* L4/L7 forwarding for cross-node routing
* A lightweight service discovery registry
* No single points of failure for access, service routing, or DNS

The next step will be **finalizing registry automation and proxy configs**, so that bolabaden.org can become truly unified and resilient.


