# Copilot Instructions for bolabaden-infra

## Overview
This document provides essential guidance for AI coding agents working within the bolabaden-infra codebase. Understanding the architecture, workflows, and conventions is crucial for effective contributions.

## Architecture
The bolabaden.org setup is designed around a multi-node architecture without a central orchestrator. Each node can independently host services, ensuring high availability and resilience. Key components include:
- **L7 Reverse Proxy**: Traefik v3 for HTTP(S) traffic with health checks and failover.
- **L4 Proxy**: For raw TCP services like Redis.
- **Service Registry**: A simple YAML file that lists services and their respective nodes.
- **Health Checks**: Automatically remove unhealthy services from the proxy.

## Request Flow
When a user accesses bolabaden.org, the request is routed through DNS (Cloudflare) to one of the nodes. If the requested service is not available locally, the node forwards the request to another node that hosts the service. This ensures that requests are always fulfilled, regardless of which node they hit.

## Developer Workflows
### Building and Testing
- Use `docker-compose` to build and run services. Ensure that the `services.yaml` file is updated to reflect the current state of services across nodes.
- Health checks are critical; ensure they are configured correctly in Traefik to avoid routing to unhealthy services.

### Debugging
- Check the logs of Traefik and individual services for troubleshooting. Logs can provide insights into routing issues or service failures.
- Use the service registry to verify which services are expected to be running on each node.

## Project-Specific Conventions
- Services are manually assigned to nodes; the registry reflects the current state rather than desired state.
- Use `docker-compose`'s `include:` functionality for managing large configurations in the service registry.

## Integration Points
- **DNS Configuration**: Managed via Cloudflare, with multiple A records for failover.
- **Service Discovery**: Achieved through a YAML file synced across nodes, simplifying the mental model of service management.

## Conclusion
This document serves as a foundational guide for AI agents to navigate the bolabaden-infra codebase effectively. For further details, refer to the README.md and service registry configurations.