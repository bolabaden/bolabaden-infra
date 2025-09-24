# Bolabaden.org - Load Balancing

## 1. **Flowchart 2: Detailed Load Balancing Flow**

This flowchart will zoom in on the **load balancing** process itself, showing how requests are routed first to the Oracle Load Balancer and then to Traefik, and how traffic is split among your three URLs (`micklethefickle.bolabaden.org`, `beatapostapita.bolabaden.org`, `vractormania.bolabaden.org`).

```
User Request
     |
     v
Cloudflare (DNS)
     |
     v
Oracle Cloud Load Balancer --------------------|
     |                                         |
     v                                         v
minimedemigoddess1.bolabaden.org    minimedemigoddess2.bolabaden.org
     |                                 |
     v                                 v
   Traefik                             Traefik
    /   \                               /   \
   /     \                             /     \
micklethefickle.bolabaden.org   beatapostapita.bolabaden.org
     |                                   |
     v                                   v
vractormania.bolabaden.org         (Further internal routing, if needed)
```


## 2. **Mermaid Diagram: Traefik + Oracle Load Balancer + Cloudflare**

```mermaid
graph TD
  A[User Request] --> B[Cloudflare DNS]
  B --> C[Oracle Cloud Load Balancer (192.9.158.176) (2603:c024:c018:701:c98f:b71e:8f59:d690)]
  C --> D1[minimedemigoddess1.bolabaden.org (146.235.209.241)]
  C --> D2[minimedemigoddess2.bolabaden.org (146.235.229.30)]
  D1 --> E1[Traefik (minimedemigoddess1)]
  D2 --> E2[Traefik (minimedemigoddess2)]
  E1 --> F1[micklethefickle.bolabaden.org (170.9.225.137)]
  E1 --> F2[beatapostapita.bolabaden.org (149.130.222.229)]
  E1 --> F3[vractormania.bolabaden.org (149.130.219.117)]
  E2 --> F1
  E2 --> F2
  E2 --> F3
```


## TODO:

- DNS failover in case the oracle cloud loadbalancer goes down.
- Determine if the C-level load balancers should be layer 4 or layer 7.


## NOTES:

- minimedemigoddess1 and minimedemigoddess2 are layer 4 TCP/UDP load balancers that passthrough TLS traffic to the downstream services (micklethefickle, beatapostapita, vractormania), which run layer 7 Traefik reverse proxies.
- Since minimedemigoddess1 and 2 are handling TLS traffic at layer 4 and passing it through without termination, the Traefik instances on these servers should also passthrough the TLS traffic to the downstream layer 7 Traefik proxies on micklethefickle, beatapostapita, and vractormania. This implies that the TLS connection should not be terminated at the minimedemigoddess level but rather at the final destinations.