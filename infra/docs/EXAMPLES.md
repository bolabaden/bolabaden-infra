# Examples and Use Cases

This guide provides practical examples of using Constellation Agent in various scenarios.

## Basic Service Deployment

### Simple Web Service

Here's how to deploy a basic web service:

```go
services = append(services, Service{
    Name:          "my-webapp",
    Image:         "docker.io/my/webapp:latest",
    ContainerName: "my-webapp",
    Hostname:      "my-webapp",
    Networks:      []string{"backend", "publicnet"},
    Ports: []PortMapping{
        {HostPort: "8080", ContainerPort: "8080", Protocol: "tcp"},
    },
    Environment: map[string]string{
        "NODE_ENV": "production",
        "PORT":     "8080",
    },
    Labels: map[string]string{
        "traefik.enable": "true",
        "traefik.http.routers.my-webapp.rule": "Host(`my-webapp.example.com`)",
        "traefik.http.services.my-webapp.loadbalancer.server.port": "8080",
    },
    Healthcheck: &Healthcheck{
        Test:        []string{"CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"},
        Interval:    "30s",
        Timeout:     "10s",
        Retries:     3,
        StartPeriod: "10s",
    },
    Restart: "always",
})
```

This service will:
- Be accessible at `my-webapp.example.com`
- Automatically load balance across all nodes
- Be removed from routing if healthcheck fails
- Restart automatically if it crashes

### Database Service

Here's a database service with proper configuration:

```go
services = append(services, Service{
    Name:          "postgres",
    Image:         "docker.io/postgres:15",
    ContainerName: "postgres",
    Hostname:      "postgres",
    Networks:      []string{"backend"},
    Environment: map[string]string{
        "POSTGRES_DB":       "mydb",
        "POSTGRES_USER":     "myuser",
        "POSTGRES_PASSWORD_FILE": "/run/secrets/postgres-password",
    },
    Secrets: []SecretMount{
        {
            Source: "/opt/constellation/secrets/postgres-password.txt",
            Target: "/run/secrets/postgres-password",
            Mode:   "0400",
        },
    },
    Volumes: []VolumeMount{
        {
            Source: "/data/postgres",
            Target: "/var/lib/postgresql/data",
            Type:   "bind",
        },
    },
    Healthcheck: &Healthcheck{
        Test:        []string{"CMD-SHELL", "pg_isready -U myuser"},
        Interval:    "30s",
        Timeout:     "10s",
        Retries:     3,
        StartPeriod: "30s",
    },
    Restart: "always",
})
```

This service:
- Only accessible on backend network (not exposed publicly)
- Uses secrets for password
- Has persistent storage
- Includes health check

## Advanced Routing

### Multiple Domains

Route a service to multiple domains:

```go
Labels: map[string]string{
    "traefik.enable": "true",
    "traefik.http.routers.my-service.rule": "Host(`my-service.example.com`) || Host(`my-service.alt.com`)",
    "traefik.http.services.my-service.loadbalancer.server.port": "8080",
},
```

### Path-Based Routing

Route based on path:

```go
Labels: map[string]string{
    "traefik.enable": "true",
    "traefik.http.routers.my-service.rule": "PathPrefix(`/api`)",
    "traefik.http.services.my-service.loadbalancer.server.port": "8080",
},
```

### TLS Configuration

Enable TLS with Let's Encrypt:

```go
Labels: map[string]string{
    "traefik.enable": "true",
    "traefik.http.routers.my-service.rule": "Host(`my-service.example.com`)",
    "traefik.http.routers.my-service.tls": "true",
    "traefik.http.routers.my-service.tls.certresolver": "letsencrypt",
    "traefik.http.services.my-service.loadbalancer.server.port": "8080",
},
```

## Service Dependencies

### Dependent Services

Define service dependencies:

```go
services = append(services, Service{
    Name:      "app",
    DependsOn: []string{"database", "redis"},
    // ... other config
})
```

The deployment tool will start dependencies first.

## Resource Limits

### Memory and CPU Limits

Set resource limits:

```go
services = append(services, Service{
    Name:          "my-service",
    MemLimit:      "2G",
    MemReservation: "512M",
    CPUs:          "1.0",
    // ... other config
})
```

This prevents services from consuming too many resources.

## Multi-Network Services

### Service on Multiple Networks

Place a service on multiple networks:

```go
services = append(services, Service{
    Name:     "my-service",
    Networks: []string{"backend", "publicnet", "warp-nat-net"},
    // ... other config
})
```

This allows the service to:
- Communicate with backend services
- Be accessible via Traefik
- Use WARP for anonymous egress

## WARP Network Usage

### Anonymous Egress

Use WARP network for anonymous outbound connections:

```go
services = append(services, Service{
    Name: "scraper",
    Labels: map[string]string{
        "network.warp.enabled": "true",
    },
    // ... other config
})
```

This routes all outbound traffic through Cloudflare WARP.

## Health Monitoring

### Comprehensive Health Check

Define a thorough health check:

```go
Healthcheck: &Healthcheck{
    Test: []string{
        "CMD-SHELL",
        "curl -f http://localhost:8080/health || exit 1",
    },
    Interval:    "30s",
    Timeout:     "10s",
    Retries:     3,
    StartPeriod: "30s",
},
```

### Auto-Restart on Failure

Enable automatic restart:

```go
Labels: map[string]string{
    "deunhealth.restart.on.unhealthy": "true",
},
```

The service will restart automatically if healthcheck fails.

## Stateful Services

### MongoDB Replica Set

The orchestrator handles MongoDB automatically. Just deploy MongoDB services:

```go
services = append(services, Service{
    Name: "mongodb",
    // MongoDB config
})
```

The orchestrator will:
- Initialize replica set
- Configure replicas
- Handle primary failover

### Redis Sentinel

Similarly for Redis:

```go
services = append(services, Service{
    Name: "redis",
    // Redis config
})
```

The orchestrator handles Sentinel configuration automatically.

## Custom Networks

### Creating Custom Networks

Define a custom network:

```go
config.Networks["my-network"] = NetworkConfig{
    Name:       "my-network",
    Driver:     "bridge",
    Subnet:     "192.168.1.0/24",
    Gateway:    "192.168.1.1",
    Attachable: true,
}
```

Then use it in services:

```go
Networks: []string{"my-network"},
```

## Service Templates

### Reusable Service Template

Create a template function:

```go
func createWebService(name, image, domain string, port int) Service {
    return Service{
        Name:          name,
        Image:         image,
        ContainerName: name,
        Hostname:      name,
        Networks:      []string{"backend", "publicnet"},
        Environment: map[string]string{
            "NODE_ENV": "production",
            "PORT":     fmt.Sprintf("%d", port),
        },
        Labels: map[string]string{
            "traefik.enable": "true",
            fmt.Sprintf("traefik.http.routers.%s.rule", name): fmt.Sprintf("Host(`%s`)", domain),
            fmt.Sprintf("traefik.http.services.%s.loadbalancer.server.port", name): fmt.Sprintf("%d", port),
        },
        Healthcheck: &Healthcheck{
            Test:        []string{"CMD-SHELL", fmt.Sprintf("curl -f http://localhost:%d/health || exit 1", port)},
            Interval:    "30s",
            Timeout:     "10s",
            Retries:     3,
            StartPeriod: "10s",
        },
        Restart: "always",
    }
}
```

Use it to create multiple services:

```go
services = append(services, createWebService("app1", "my/app1", "app1.example.com", 8080))
services = append(services, createWebService("app2", "my/app2", "app2.example.com", 8081))
```

## Environment-Specific Configuration

### Development vs Production

Use environment variables for different configurations:

```go
env := getEnv("ENV", "production")
if env == "development" {
    // Development config
    service.Environment["DEBUG"] = "true"
    service.Environment["LOG_LEVEL"] = "debug"
} else {
    // Production config
    service.Environment["DEBUG"] = "false"
    service.Environment["LOG_LEVEL"] = "info"
}
```

## Service Discovery

### Finding Healthy Services

Query cluster state for healthy services:

```go
state := gossipCluster.GetState()
healthyNodes := state.GetHealthyServiceNodes("my-service")
for _, nodeName := range healthyNodes {
    health, _ := state.GetServiceHealth("my-service", nodeName)
    fmt.Printf("Service healthy on %s: %v\n", nodeName, health.Healthy)
}
```

### Getting Service Endpoints

Get endpoints for a service:

```go
state := gossipCluster.GetState()
health, exists := state.GetServiceHealth("my-service", "node1")
if exists {
    httpEndpoint := health.Endpoints["http"]
    fmt.Printf("HTTP endpoint: %s\n", httpEndpoint)
}
```

## DNS Management

### Manual DNS Updates

Update DNS records manually (if needed):

```go
dnsController.UpdateLBLeader("1.2.3.4")
nodeIPs := map[string]string{
    "node1": "1.2.3.4",
    "node2": "5.6.7.8",
}
dnsController.UpdateNodeIPs(nodeIPs)
```

Usually this is automatic, but you can trigger it manually if needed.

## Monitoring Integration

### Kuma Integration

Add Kuma monitoring labels:

```go
Labels: map[string]string{
    "kuma.my-service.http.name": "my-service.node.example.com",
    "kuma.my-service.http.url":   "https://my-service.example.com",
    "kuma.my-service.http.interval": "60",
},
```

This enables monitoring in Uptime Kuma.

### Homepage Integration

Add homepage labels:

```go
Labels: map[string]string{
    "homepage.group": "My Services",
    "homepage.name":  "My Service",
    "homepage.icon":  "my-service.png",
    "homepage.href":  "https://my-service.example.com",
},
```

This adds the service to your homepage dashboard.

## Error Handling

### Graceful Degradation

Handle service failures gracefully:

```go
health, exists := state.GetServiceHealth("my-service", "node1")
if !exists || !health.Healthy {
    // Fallback to another node or default behavior
    health, exists = state.GetServiceHealth("my-service", "node2")
}
```

### Retry Logic

Implement retry logic:

```go
maxRetries := 3
for i := 0; i < maxRetries; i++ {
    err := deployService(service)
    if err == nil {
        break
    }
    time.Sleep(time.Second * time.Duration(i+1))
}
```

## Performance Optimization

### Resource Optimization

Optimize resource usage:

```go
// Use appropriate resource limits
service.MemLimit = "512M"  // Not too high
service.CPUs = "0.5"       // Share CPU

// Use health checks to remove unhealthy services quickly
service.Healthcheck.Interval = "10s"  // Check frequently
service.Healthcheck.Timeout = "5s"    // Fail fast
```

### Network Optimization

Optimize network usage:

```go
// Only use necessary networks
service.Networks = []string{"backend"}  // Not all networks

// Use appropriate network for service type
if needsPublicAccess {
    service.Networks = append(service.Networks, "publicnet")
}
```

## Security Best Practices

### Secret Management

Use secrets properly:

```go
// Never hardcode secrets
service.Environment["PASSWORD"] = "hardcoded"  // BAD

// Use secret files
service.Secrets = []SecretMount{
    {
        Source: "/opt/constellation/secrets/password.txt",
        Target: "/run/secrets/password",
        Mode:   "0400",
    },
}
service.Environment["PASSWORD_FILE"] = "/run/secrets/password"
```

### Least Privilege

Run with least privilege:

```go
service.User = "1001:1001"  // Non-root user
service.Privileged = false   // Not privileged
service.CapAdd = []string{}  // No extra capabilities
```

## Troubleshooting Examples

### Debug Service Discovery

Check if service is discovered:

```go
state := gossipCluster.GetState()
allHealth := state.GetAllServiceHealth()
for key, health := range allHealth {
    fmt.Printf("%s: %v\n", key, health.Healthy)
}
```

### Check Node Status

Verify node is in cluster:

```go
state := gossipCluster.GetState()
node, exists := state.GetNode("node1")
if exists {
    fmt.Printf("Node: %+v\n", node)
} else {
    fmt.Println("Node not found")
}
```

### Test HTTP Provider

Test Traefik HTTP provider:

```bash
# Get routers
curl http://localhost:8081/api/http/routers

# Get services
curl http://localhost:8081/api/http/services

# Health check
curl http://localhost:8081/health
```

These examples should help you get started with Constellation Agent. For more information, see the other documentation files.

