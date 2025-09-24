#!/usr/bin/env python3
# convert_to_k8s.py - Convert Dagger container definitions to Kubernetes manifests
from __future__ import annotations

import importlib.util
import inspect
import logging
import sys
from importlib.machinery import ModuleSpec
from pathlib import Path
from re import Match
from types import ModuleType
from typing import Any, Callable

import yaml

logger: logging.Logger = logging.getLogger(__name__)


def load_module(
    path: str,
    module_name: str = "dagger_app",
) -> ModuleType:
    """Load a Python module from path."""
    spec: ModuleSpec | None = importlib.util.spec_from_file_location(module_name, path)
    if spec is None:
        raise ImportError(f"Failed to load module from {path}")
    module: ModuleType = importlib.util.module_from_spec(spec)
    if spec.loader is None:
        raise ImportError(f"Failed to load module from {path}")
    spec.loader.exec_module(module)
    return module


def get_class_methods(
    module: ModuleType,
    class_name: str,
) -> dict[str, Callable[..., Any]]:
    """Get all methods of a class in a module."""
    for name, obj in inspect.getmembers(module):
        if name == class_name and inspect.isclass(obj):
            return {
                name: method
                for name, method in inspect.getmembers(obj)
                if name.startswith("build_") and inspect.isfunction(method)
            }
    return {}


def parse_container_definition(
    method_name: str,
    method: Callable[..., Any],
) -> dict[str, Any]:
    """Extract relevant container definition information."""
    # This is a simplified parsing logic - in a real implementation,
    # you would need to analyze the method body to extract container properties
    container_name: str = method_name.replace("build_", "")

    # Get source code of the method
    source: str = inspect.getsource(method)

    # Parse container properties from the source
    container: dict[str, Any] = {
        "name": container_name,
        "image": extract_image(source),
        "ports": extract_ports(source),
        "env": extract_env_vars(source),
        "volumes": extract_volumes(source),
        "labels": extract_labels(source),
    }

    return container


def extract_image(source: str) -> str:
    """Extract container image from method source."""
    # Look for .from_() calls
    import re

    match: Match[str] | None = re.search(r"\.from_\([\"']([^\"']+)[\"']\)", source)
    if match:
        return match.group(1)
    return "unknown/image:latest"  # Default if not found


def extract_ports(source: str) -> list[dict[str, Any]]:
    """Extract exposed ports from method source."""
    import re

    ports: list[dict[str, Any]] = []
    for match in re.finditer(r"\.with_exposed_port\(int\(([^)]+)\)\)", source):
        port_var: str = match.group(1)
        if port_var.isdigit():
            port = int(port_var)
        else:
            # Try to find the port variable in the source
            port_match: re.Match[str] | None = re.search(
                f"{port_var}\\s*=\\s*os.environ.get\\([\"']([^\"']+)[\"'],\\s*[\"']([^\"']+)[\"']",
                source,
            )
            if port_match:
                port_match.group(1)
                grp2: str = port_match.group(2)
                default_value: str = grp2 if str(grp2).isdigit() else "80"
                port = int(default_value)
            else:
                port = 80  # Default if not found

        ports.append(
            {
                "containerPort": int(port) if str(port).isdigit() else int(80),
                "protocol": "TCP",
            }
        )
    return ports


def extract_env_vars(source: str) -> list[dict[str, Any]]:
    """Extract environment variables from method source."""
    import re

    env_vars: list[dict[str, Any]] = []

    # Match .with_env_variable() calls
    for match in re.finditer(
        r"\.with_env_variable\([\"']([^\"']+)[\"'],\s*([^)]+)\)", source
    ):
        key: str = match.group(1)
        value: str = match.group(2).strip()

        # If the value is an os.environ.get call, extract the default value
        env_get_match: re.Match[str] | None = re.match(
            r"os\.environ\.get\([\"']([^\"']+)[\"'],\s*[\"']([^\"']*)[\"']\)", value
        )
        if env_get_match:
            env_var: str = env_get_match.group(1)
            default_value: str = env_get_match.group(2)
            env_vars.append(
                {
                    "name": str(key),
                    "valueFrom": {
                        "configMapKeyRef": {
                            "name": "media-server-config",
                            "key": str(env_var or default_value),
                            "optional": "true",
                        }
                    },
                }
            )
        else:
            env_vars.append({"name": key, "value": value.strip("\"'")})

    return env_vars


def extract_volumes(source: str) -> tuple:
    """Extract volumes and volume mounts from method source."""
    import re

    volume_mounts: list[dict[str, Any]] = []
    volumes: list[dict[str, Any]] = []

    # Extract .with_mounted_cache() calls
    volume_counter: int = 0
    for match in re.finditer(
        r"\.with_mounted_cache\(([^,]+),\s*dag\.cache_volume\(([^)]+)\)\)", source
    ):
        mount_path: str = match.group(1).strip().strip("\"'")
        volume_path: str = match.group(2).strip().strip("\"'")

        volume_name: str = f"vol-{volume_counter}"
        volume_counter += 1

        volume_mounts.append({"name": volume_name, "mountPath": mount_path})

        volumes.append(
            {
                "name": volume_name,
                "hostPath": {"path": volume_path, "type": "DirectoryOrCreate"},
            }
        )

    return volumes, volume_mounts


def extract_labels(source: str) -> dict[str, str]:
    """Extract labels from method source."""
    import re

    labels: dict[str, str] = {}

    for match in re.finditer(r"\.with_label\([\"']([^\"']+)[\"'],\s*([^)]+)\)", source):
        key: str = match.group(1)
        value: str = match.group(2).strip().strip("\"'")
        labels[key] = value

    return labels


def generate_k8s_manifest(container: dict[str, Any]) -> dict[str, Any]:
    """Generate Kubernetes manifest for a container."""
    volumes: tuple[list[dict[str, Any]], list[dict[str, Any]]] = container.get(
        "volumes", ([], [])
    )

    manifest: dict[str, Any] = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": container["name"], "labels": {"app": container["name"]}},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": container["name"]}},
            "template": {
                "metadata": {"labels": {"app": container["name"]}},
                "spec": {
                    "containers": [
                        {
                            "name": container["name"],
                            "image": container["image"],
                            "ports": container.get("ports", []),
                            "env": container.get("env", []),
                            "volumeMounts": volumes,
                            "resources": {
                                "limits": {"memory": "1Gi", "cpu": "500m"},
                                "requests": {"memory": "512Mi", "cpu": "100m"},
                            },
                        }
                    ],
                    "volumes": volumes,
                },
            },
        },
    }

    # Generate Service if ports are defined
    service: dict[str, Any] | None = None
    if container.get("ports"):
        service = {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {
                "name": container["name"],
                "labels": {"app": container["name"]},
            },
            "spec": {
                "selector": {"app": container["name"]},
                "ports": [
                    {
                        "port": port["containerPort"],
                        "targetPort": port["containerPort"],
                        "protocol": port["protocol"],
                    }
                    for port in container.get("ports", [])
                ],
            },
        }

    # Generate Ingress if homepage.href label is present
    ingress: dict[str, Any] | None = None
    labels: dict[str, Any] = container.get("labels", {})
    if "homepage.href" in labels:
        href: str = labels["homepage.href"]
        if href.startswith("https://"):
            host: str = href[8:]  # Remove https://
            ingress = {
                "apiVersion": "networking.k8s.io/v1",
                "kind": "Ingress",
                "metadata": {
                    "name": f"{container['name']}-ingress",
                    "annotations": {
                        "kubernetes.io/ingress.class": "traefik",
                        "cert-manager.io/cluster-issuer": "letsencrypt-prod",
                    },
                },
                "spec": {
                    "rules": [
                        {
                            "host": host,
                            "http": {
                                "paths": [
                                    {
                                        "path": "/",
                                        "pathType": "Prefix",
                                        "backend": {
                                            "service": {
                                                "name": container["name"],
                                                "port": {
                                                    "number": container.get(
                                                        "ports", [{}]
                                                    )[0].get("containerPort", 80)
                                                },
                                            }
                                        },
                                    }
                                ]
                            },
                        }
                    ],
                    "tls": [
                        {
                            "hosts": [host],
                            "secretName": f"{container['name']}-tls",
                        }
                    ],
                },
            }

    return {"deployment": manifest, "service": service, "ingress": ingress}


def main():
    if len(sys.argv) != 3:
        logger.error(f"Usage: {sys.argv[0]} <dagger_file> <output_dir>")
        sys.exit(1)

    dagger_file: str = sys.argv[1]
    output_dir: str = sys.argv[2]

    try:
        # Create output directory if it doesn't exist
        Path(output_dir).mkdir(parents=True, exist_ok=True)

        # Load the module containing container definitions
        module: ModuleType = load_module(dagger_file)

        # Get class methods that build containers
        methods: dict[str, Callable[..., Any]] = get_class_methods(
            module,
            "ComposeModule",
        )

        # Generate Kubernetes manifests for each container
        for method_name, method in methods.items():
            container: dict[str, Any] = parse_container_definition(method_name, method)
            manifests: dict[str, Any] = generate_k8s_manifest(container)

            # Write manifests to files
            base_name: str = method_name.replace("build_", "")

            # Deployment
            deployment_path: Path = Path(output_dir) / f"{base_name}-deployment.yaml"
            with deployment_path.open("w") as f:
                yaml.dump(manifests["deployment"], f, default_flow_style=False)
                logger.info(f"Generated {deployment_path}")

            # Service
            if manifests["service"]:
                service_path: Path = Path(output_dir) / f"{base_name}-service.yaml"
                with service_path.open("w") as f:
                    yaml.dump(manifests["service"], f, default_flow_style=False)
                    logger.info(f"Generated {service_path}")

            # Ingress
            if manifests["ingress"]:
                ingress_path: Path = Path(output_dir) / f"{base_name}-ingress.yaml"
                with ingress_path.open("w") as f:
                    yaml.dump(manifests["ingress"], f, default_flow_style=False)
                    logger.info(f"Generated {ingress_path}")

        # Generate ConfigMap for environment variables
        configmap: dict[str, Any] = {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {"name": "media-server-config"},
            "data": {},
        }
        configmap_path: Path = Path(output_dir) / "media-server-configmap.yaml"
        with configmap_path.open("w") as f:
            yaml.dump(configmap, f, default_flow_style=False)
            logger.info(f"Generated {configmap_path}")

        logger.info("Done! Kubernetes manifests generated successfully.")

    except Exception as e:
        logger.exception(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
