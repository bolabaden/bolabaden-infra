#!/usr/bin/env python3
"""
Generate an L4 (TCP) HAProxy config from OpenSVC nodes and Docker labels.

Design constraints:
- Plain TCP can not be routed by hostname without TLS/SNI.
- So we load-balance by *port* (e.g. 6379 for Redis).
- No explicit service/node names are hardcoded: discovered from Docker + OpenSVC.

Opt-in per container using labels:
- osvc.l4.enable=true
- osvc.l4.port=<port>            (frontend bind + backend port)
- osvc.l4.check=tcp|redis        (healthcheck type; tcp is basic connect check)

Output:
- ${CONFIG_PATH}/haproxy/haproxy.cfg
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


@dataclass(frozen=True)
class L4Service:
    name: str
    port: int
    check: str


def _run(cmd: List[str]) -> str:
    proc = subprocess.run(
        cmd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.stdout.strip()


def _node_shortnames_from_osvc() -> List[str]:
    raw = _run(["om", "node", "ls", "--format", "json"])
    nodes = json.loads(raw)
    short: List[str] = []
    for n in nodes:
        if not isinstance(n, str) or not n:
            continue
        s = n.split(".")[0].strip()
        if s and s not in short:
            short.append(s)
    return short


def _docker_container_ids() -> List[str]:
    out = _run(["docker", "ps", "-q"])
    if not out:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def _docker_inspect(container_id: str) -> Dict[str, Any]:
    out = _run(["docker", "inspect", container_id])
    data = json.loads(out)
    if not isinstance(data, list) or not data:
        raise RuntimeError(f"docker inspect returned unexpected shape for {container_id}")
    return data[0]


def _container_name(inspect: Dict[str, Any]) -> str:
    return str(inspect.get("Name") or "").lstrip("/")


def _container_labels(inspect: Dict[str, Any]) -> Dict[str, str]:
    labels = (inspect.get("Config") or {}).get("Labels") or {}
    return {str(k): str(v) for k, v in labels.items()}


def _discover_l4_services() -> List[L4Service]:
    svcs: List[L4Service] = []
    for cid in _docker_container_ids():
        insp = _docker_inspect(cid)
        name = _container_name(insp)
        labels = _container_labels(insp)
        if labels.get("osvc.l4.enable", "false").lower() != "true":
            continue
        port_raw = labels.get("osvc.l4.port", "").strip()
        if not port_raw:
            continue
        try:
            port = int(port_raw)
        except ValueError:
            continue
        check = labels.get("osvc.l4.check", "tcp").strip().lower()
        if check not in {"tcp", "redis"}:
            check = "tcp"
        svcs.append(L4Service(name=name, port=port, check=check))
    svcs.sort(key=lambda s: (s.port, s.name))
    # Deduplicate by port; if multiple containers claim the same port, keep the
    # first (operators must fix labels).
    by_port: Dict[int, L4Service] = {}
    for s in svcs:
        by_port.setdefault(s.port, s)
    return [by_port[p] for p in sorted(by_port.keys())]


def _render_haproxy_cfg(domain: str, nodes: List[str], services: List[L4Service]) -> str:
    lines: List[str] = []
    lines.append("global")
    lines.append("  log stdout format raw local0")
    lines.append("  maxconn 20000")
    lines.append("")
    lines.append("defaults")
    lines.append("  log global")
    lines.append("  mode tcp")
    lines.append("  option tcplog")
    lines.append("  timeout connect 5s")
    lines.append("  timeout client  1m")
    lines.append("  timeout server  1m")
    lines.append("")
    lines.append("listen stats")
    lines.append("  bind 0.0.0.0:8404")
    lines.append("  mode http")
    lines.append("  stats enable")
    lines.append("  stats uri /")
    lines.append("")

    for svc in services:
        port = svc.port
        lines.append(f"frontend fe_{port}")
        lines.append(f"  bind 0.0.0.0:{port}")
        lines.append(f"  default_backend be_{port}")
        lines.append("")

        lines.append(f"backend be_{port}")
        lines.append("  mode tcp")
        # Healthcheck: best-effort, protocol-aware when requested
        if svc.check == "redis":
            lines.append("  option tcp-check")
            lines.append("  tcp-check connect")
            lines.append(r"  tcp-check send PING\r\n")
            lines.append("  tcp-check expect string +PONG")
        else:
            lines.append("  option tcp-check")
            lines.append("  tcp-check connect")
        # Prefer leastconn for smoother balancing
        lines.append("  balance leastconn")
        for n in nodes:
            # Backend target is node-scoped hostname, so any node can proxy to any other.
            # DNS must resolve <svc>.<node>.<domain> to node ingress.
            target = f"{svc.name}.{n}.{domain}:{port}"
            lines.append(f"  server {svc.name}_{n} {target} check inter 3s fall 3 rise 2")
        lines.append("")

    return "\n".join(lines)


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", delete=False, dir=str(path.parent)) as tf:
        tf.write(content)
        tf.flush()
        os.fsync(tf.fileno())
        tmp = Path(tf.name)
    tmp.replace(path)


def main() -> int:
    domain = os.environ.get("DOMAIN", "").strip()
    if not domain:
        raise SystemExit("DOMAIN is required in the environment")
    config_path = os.environ.get("CONFIG_PATH", "./volumes").strip()
    out_file = Path(config_path) / "haproxy" / "haproxy.cfg"

    nodes = _node_shortnames_from_osvc()
    services = _discover_l4_services()
    cfg = _render_haproxy_cfg(domain=domain, nodes=nodes, services=services)
    _atomic_write(out_file, cfg)
    print(f"Wrote {out_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


