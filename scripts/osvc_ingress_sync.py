#!/usr/bin/env python3
"""
Generate dynamic Traefik file-provider config implementing:

- <service>.<node>.${DOMAIN} -> always hits that node's Traefik (via DNS wildcard),
  and if the service isn't local it will implicitly fall back to another node.
- <service>.${DOMAIN} -> works from any node (requires DNS/LB to land on any node),
  and will implicitly fall back to other nodes if local instance is missing.

This script intentionally does NOT contain any explicit service names or node
names. It discovers:
- nodes from OpenSVC (`om node ls --format json`)
- services from Docker containers where `traefik.enable=true`

It writes a Traefik dynamic config file to the standard dynamic directory
used by this repo: `${CONFIG_PATH}/traefik/dynamic/failover-fallbacks.yaml`.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


@dataclass(frozen=True)
class ContainerInfo:
    name: str
    labels: Dict[str, str]
    exposed_ports: List[int]


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
        # Cope with odd cases like "beatapostapita.bolabaden.org.bolabaden.org"
        # by always taking the first DNS label.
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


def _parse_exposed_ports(inspect: Dict[str, Any]) -> List[int]:
    ports: List[int] = []
    exposed = (inspect.get("Config") or {}).get("ExposedPorts") or {}
    for k in exposed.keys():
        # e.g. "3000/tcp"
        m = re.match(r"^(?P<p>[0-9]+)/", str(k))
        if not m:
            continue
        ports.append(int(m.group("p")))
    # Keep stable ordering
    return sorted(set(ports))


def _docker_inspect(container_id: str) -> Dict[str, Any]:
    out = _run(["docker", "inspect", container_id])
    data = json.loads(out)
    if not isinstance(data, list) or not data:
        raise RuntimeError(f"docker inspect returned unexpected shape for {container_id}")
    return data[0]


def _container_name(inspect: Dict[str, Any]) -> str:
    name = str(inspect.get("Name") or "").lstrip("/")
    return name


def _container_labels(inspect: Dict[str, Any]) -> Dict[str, str]:
    labels = (inspect.get("Config") or {}).get("Labels") or {}
    return {str(k): str(v) for k, v in labels.items()}


def _choose_backend_port(name: str, labels: Dict[str, str], exposed_ports: List[int]) -> Optional[int]:
    """
    Prefer an explicit Traefik service port label if present, otherwise fall back
    to the first exposed port.
    """
    # Common pattern in this repo: traefik.http.services.<service>.loadbalancer.server.port
    candidates: List[int] = []
    for k, v in labels.items():
        if k.startswith("traefik.http.services.") and k.endswith(".loadbalancer.server.port"):
            try:
                candidates.append(int(str(v)))
            except ValueError:
                continue
    if candidates:
        # Stable pick: prefer lowest
        return sorted(candidates)[0]
    if exposed_ports:
        return exposed_ports[0]
    return None


def _discover_traefik_enabled_containers() -> List[ContainerInfo]:
    containers: List[ContainerInfo] = []
    for cid in _docker_container_ids():
        insp = _docker_inspect(cid)
        name = _container_name(insp)
        labels = _container_labels(insp)
        if labels.get("traefik.enable", "false").lower() != "true":
            continue
        # Only build HTTP failover for containers that actually define HTTP routing.
        # Many services in this repo also use `traefik.enable=true` for TCP routers
        # (ex: MongoDB/Redis via `traefik.tcp.*`). Those must NOT be included here.
        if not any(k.startswith("traefik.http.") for k in labels.keys()):
            continue
        exposed_ports = _parse_exposed_ports(insp)
        containers.append(ContainerInfo(name=name, labels=labels, exposed_ports=exposed_ports))
    # Stable ordering
    containers.sort(key=lambda c: c.name)
    return containers


def _yaml_quote(s: str) -> str:
    # Minimal YAML quoting for our values
    return json.dumps(s)


def _render_failover_yaml(
    *,
    domain: str,
    local_node: str,
    nodes: List[str],
    containers: List[ContainerInfo],
) -> str:
    """
    Generates a Traefik file-provider YAML document.

    Note: The config names are generated from container names, but the script
    itself does not hardcode any service names or node names.
    """
    lines: List[str] = []
    lines.append("# yaml-language-server: $schema=https://www.schemastore.org/traefik-v3-file-provider.json")
    lines.append("http:")
    lines.append("  routers:")

    for c in containers:
        name = c.name
        # global host: service.domain
        lines.append(f"    {name}-with-failover:")
        lines.append(f"      service: {name}-with-failover@file")
        lines.append(f"      rule: Host(`{name}.{domain}`)")
        # node-specific host: service.<thisnode>.domain
        lines.append(f"    {name}-direct:")
        lines.append(f"      service: {name}-direct@file")
        lines.append(f"      rule: Host(`{name}.{local_node}.{domain}`)")

    lines.append("  services:")
    for c in containers:
        name = c.name
        port = _choose_backend_port(name, c.labels, c.exposed_ports)
        if port is None:
            # Skip if we can't determine a port safely
            continue

        # Optional healthcheck hints from labels (used elsewhere in this repo)
        health_path = c.labels.get("kuma.healthcheck.path", "/")
        health_interval = c.labels.get("kuma.healthcheck.interval", "30s")
        health_timeout = c.labels.get("kuma.healthcheck.timeout", "10s")

        lines.append(f"    {name}-direct:")
        lines.append("      loadBalancer:")
        lines.append("        servers:")
        lines.append(f"          - url: http://{name}:{port}")

        lines.append(f"    {name}-with-failover:")
        lines.append("      loadBalancer:")
        lines.append("        servers:")
        # Prefer local first (fast path)
        lines.append(f"          - url: http://{name}:{port}")
        # Then every node-specific endpoint (implicit fallback)
        for n in nodes:
            # Avoid duplicating local node as remote fallback
            if n == local_node:
                continue
            lines.append(f"          - url: https://{name}.{n}.{domain}")
        lines.append("        healthCheck:")
        lines.append(f"          path: {_yaml_quote(health_path)}")
        lines.append(f"          interval: {_yaml_quote(health_interval)}")
        lines.append(f"          timeout: {_yaml_quote(health_timeout)}")

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
    traefik_dynamic_dir = Path(config_path) / "traefik" / "dynamic"
    out_file = traefik_dynamic_dir / "failover-fallbacks.yaml"

    # Local node for node-specific hostnames. In your stack this is TS_HOSTNAME.
    local_node = os.environ.get("TS_HOSTNAME", "").strip()
    if not local_node:
        # Fallback to system hostname (short)
        local_node = _run(["hostname", "-s"]).strip()

    nodes = _node_shortnames_from_osvc()
    if local_node not in nodes:
        nodes = [local_node] + [n for n in nodes if n != local_node]

    containers = _discover_traefik_enabled_containers()
    content = _render_failover_yaml(
        domain=domain,
        local_node=local_node,
        nodes=nodes,
        containers=containers,
    )
    _atomic_write(out_file, content)
    print(f"Wrote {out_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


