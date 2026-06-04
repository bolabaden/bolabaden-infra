# 🧩 CUE Specification Extensions (`x-cue`)

This document defines the **Extensible Compose Schema** for the Constellation Unified Engine. To maintain industry-standard compatibility, CUE uses the `x-cue` namespace. These keys are ignored by standard Docker/Podman but are active when deployed via the CUE Controller.

## 🎯 Design Philosophy: "Hidden Power"
CUE avoids the "frustrating boilerplate" of K8s/Nomad by assuming sensible defaults based on service names and only requiring explicit configuration for advanced behavior.

---

## 🏗️ 1. High Availability & Scaling (`x-cue.ha`)

Replaces K8s `PodDisruptionBudget` and complex `Deployment` replica patterns.

```yaml
services:
  mongodb:
    image: mongo
    x-cue:
      ha:
        enabled: true
        min_available: 2
        mode: "active-passive" # Options: active-active, active-passive, stateful-quorum
        automatic_failover: true
```

## 📈 2. Autoscaling (`x-cue.autoscale`)

Replaces `HorizontalPodAutoscaler` (HPA).

```yaml
services:
  bolabaden-nextjs:
    x-cue:
      autoscale:
        min_replicas: 2
        max_replicas: 10
        metric: cpu
        target: 70 # 70% utilization
```

## 🛡️ 3. Advanced Networking (`x-cue.mesh`)

Replaces `NetworkPolicy` and `Ingress` boilerplate.

```yaml
services:
  internal-api:
    x-cue:
      mesh:
        visibility: "private" # "private", "cluster-only", "public"
        mtls: true
        allow_from:
          - "frontend-service" # Logical service name instead of IP/CIDR
        deny_all_others: true
```

## 🤖 4. Hardware Acceleration (`x-cue.hardware`)

Automates GPU/NPUs without complex device mapping.

```yaml
services:
  llm-engine:
    x-cue:
      hardware:
        gpu: "auto" # Detects NVIDIA/Intel/AMD and passes through drivers
        vram_reservation: "8GB"
        priority: "high"
```

---

## 🔄 5. K8s Primates Mapping (Deep Integration)

For power users who need *exactly* what K8s does, CUE allows embedding raw K8s fragments that are validated and applied during the `cue up` cycle.

```yaml
services:
  special-service:
    x-cue:
      k8s:
        # Raw fragments that CUE injects into the generated manifest
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: disktype
                  operator: In
                  values:
                  - ssd
        tolerations:
          - key: "hardware"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
```

---

## 🛠️ The "Smart Default" Engine

CUE looks at your service names and applies **Implicit Extensions** if `x-cue` is missing:

| Service Name | Default Intelligence Applied |
| :--- | :--- |
| `mongodb`, `redis`, `postgres` | Automates `statefulset` logic, `fsGroup` permissions, and `readinessProbes` for DB health. |
| `stremio`, `plex`, `jellyfin` | Automates `/dev/dri` passthrough for hardware transcoding. |
| `grafana`, `prometheus` | Automates `ServiceMonitor` creation to scrape the local mesh. |
| `headscale`, `tailscale` | Requests `NET_ADMIN` and `privileged` mode automatically. |

---

## ⚡ Summary: Why this is better than K8s

1.  **Readability**: You stay in a single file (`docker-compose.yml`).
2.  **Backwards Compatibility**: You can run the exact same file on your laptop with `docker compose up`.
3.  **No Boilerplate**: CUE handles the 80% of K8s work (Services, Ingress, PDBs) behind the scenes, leaving you to only define the "Business Intent."
