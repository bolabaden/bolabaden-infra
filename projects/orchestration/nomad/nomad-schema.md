# Nomad HCL Schema & Syntax Reference

## Overview
Nomad is a highly available, distributed, data-center aware cluster and application scheduler designed to support modern datacenters with long-running services and batch jobs. This document provides comprehensive HCL (HashiCorp Configuration Language) schema and syntax information for Nomad job specifications.

## Basic Job Structure

### Job Block
```hcl
job "docs" {
  constraint {
    # ...
  }

  datacenters = ["us-east-1"]

  node_pool = "prod"

  group "example" {
    # ...

    task "docs" {
      # ...
    }
  }

  meta {
    my-key = "my-value"
  }

  parameterized {
    # ...
  }

  periodic {
    # ...
  }

  priority = 100

  region = "north-america"

  update {
    # ...
  }
}
```

## Core Job Configuration

### Job Metadata
```hcl
job "example" {
  type = "service"  # service, batch, system
  region = "us"
  datacenters = ["us-west-1", "us-east-1"]
  namespace = "default"
  priority = 50
  all_at_once = false
  parameterized {
    # ...
  }
  periodic {
    # ...
  }
}
```

### Job Types
- `service`: Long-running services that should be restarted if they fail
- `batch`: Short-lived jobs that run to completion
- `system`: Jobs that run on every node in the datacenter

## Group Configuration

### Basic Group
```hcl
group "webs" {
  count = 5
  
  network {
    port "http" {}
    port "https" {
      static = 443
    }
  }
  
  service {
    # ...
  }
  
  task "frontend" {
    # ...
  }
}
```

### Group Scaling
```hcl
group "cache" {
  count = 1

  scaling {
    enabled = true
    min     = 0
    max     = 10

    policy {
      # ...
    }
  }
}
```

## Task Configuration

### Basic Task
```hcl
task "server" {
  driver = "docker"
  
  config {
    image = "hashicorp/web-frontend"
    ports = ["http", "https"]
  }
  
  env {
    DB_HOST = "db01.example.com"
    DB_USER = "web"
    DB_PASS = "loremipsum"
  }
  
  resources {
    cpu    = 500 # MHz
    memory = 128 # MB
  }
}
```

### Task Drivers
- `docker`: Run Docker containers
- `exec`: Run binaries directly on the host
- `java`: Run Java applications
- `qemu`: Run QEMU virtual machines
- `raw_exec`: Run binaries with minimal isolation
- `rkt`: Run rkt containers

## Network Configuration

### Dynamic Ports
```hcl
network {
  port "http" {}
  port "https" {}
  port "lb" {
    static = 8889
  }
}
```

### Network Modes
```hcl
network {
  mode = "bridge"  # bridge, host, none
}
```

## Service Registration

### Basic Service
```hcl
service {
  name = "count-api"
  port = "9001"
  
  check {
    type     = "http"
    path     = "/health"
    interval = "10s"
    timeout  = "2s"
  }
}
```

### Service with Tags and Metadata
```hcl
service {
  name = "count-api"
  port = "9001"
  
  tags = ["api", "v1"]
  
  meta {
    version = "1.0"
    environment = "production"
  }
  
  check {
    type     = "tcp"
    port     = "9001"
    interval = "10s"
    timeout  = "2s"
  }
}
```

### Multiple Health Checks
```hcl
service {
  name = "count-api"
  port = "9001"
  
  check {
    type     = "http"
    path     = "/health"
    interval = "10s"
    timeout  = "2s"
  }
  
  check {
    type     = "tcp"
    port     = "9001"
    interval = "10s"
    timeout  = "2s"
  }
}
```

## Consul Connect Integration

### Sidecar Service
```hcl
service {
  name = "count-api"
  port = "9001"
  
  connect {
    sidecar_service {}
  }
}
```

### Sidecar with Proxy Configuration
```hcl
service {
  name = "count-api"
  port = "9001"
  
  connect {
    sidecar_service {
      proxy {
        expose {
          path {
            path            = "/health"
            protocol        = "http"
            local_path_port = 9001
            listener_port   = "api_expose_healthcheck"
          }
        }
      }
    }
  }
}
```

### Upstream Services
```hcl
service {
  name = "count-api"
  port = "9001"
  
  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "count-api"
          local_bind_port = 8080
        }
      }
    }
  }
}
```

## Resource Configuration

### CPU and Memory
```hcl
resources {
  cpu    = 500  # MHz
  memory = 128  # MB
}
```

### Network Resources
```hcl
resources {
  network {
    mbits = 10
    port "http" {}
  }
}
```

### Device Resources
```hcl
resources {
  device "nvidia/gpu" {
    count = 2
    
    constraint {
      attribute = "${device.attr.memory}"
      operator  = ">="
      value     = "2 GiB"
    }
  }
}
```

## Constraints and Affinities

### Node Constraints
```hcl
constraint {
  attribute = "${attr.kernel.name}"
  value     = "linux"
}

constraint {
  attribute = "${meta.rack}"
  operator  = "regexp"
  value     = "rack-[0-9]+"
}
```

### Node Affinities
```hcl
affinity {
  attribute = "${node.datacenter}"
  value     = "us-west-1"
  weight    = 100
}
```

### Task Group Constraints
```hcl
constraint {
  operator  = "distinct_hosts"
  value     = "true"
}
```

## Environment Variables

### Basic Environment Variables
```hcl
env {
  DB_HOST = "db01.example.com"
  DB_USER = "web"
  DB_PASS = "loremipsum"
}
```

### Environment Variables with Dots
```hcl
env = {
  "discovery.type" = "single-node"
}
```

## Templates

### Basic Template
```hcl
template {
  source        = "local/redis.conf.tpl"
  destination   = "local/redis.conf"
  change_mode   = "signal"
  change_signal = "SIGINT"
}
```

### Template with Data
```hcl
template {
  data        = <<EOH
DATABASE_URL="postgres://{{ env "DB_USER" }}:{{ env "DB_PASS" }}@{{ env "DB_HOST" }}:5432/{{ env "DB_NAME" }}"
EOH
  destination = "local/database.env"
  env         = true
}
```

## Artifacts

### Basic Artifact
```hcl
artifact {
  source      = "https://example.com/file.tar.gz"
  destination = "local/some-directory"
  options {
    checksum = "md5:df6a4178aec9fbdc1d6d7e3634d1bc33"
  }
}
```

### S3 Artifact
```hcl
artifact {
  source = "s3::https://my-bucket-example.s3-eu-west-1.amazonaws.com/my_app.tar.gz"
}
```

## Volumes

### Host Volumes
```hcl
volume "certs" {
  type      = "host"
  source    = "ca-certificates"
  read_only = true
}
```

### CSI Volumes
```hcl
volume "cache-volume" {
  type            = "csi"
  source          = "test-volume"
  attachment_mode = "file-system"
  access_mode     = "single-node-writer"
  per_alloc       = true
}
```

### Volume Mounts
```hcl
volume_mount {
  volume      = "cache-volume"
  destination = "${NOMAD_ALLOC_DIR}/cache"
  read_only   = false
}
```

## Update Strategy

### Rolling Updates
```hcl
update {
  stagger       = "30s"
  max_parallel = 2
  health_check = "checks"
  min_healthy_time = "10s"
  healthy_deadline = "5m"
  progress_deadline = "10m"
  auto_revert = true
  auto_promote = true
  canary = 1
}
```

### Canary Deployments
```hcl
update {
  canary = 1
  max_parallel = 0
  health_check = "checks"
  min_healthy_time = "10s"
  healthy_deadline = "5m"
}
```

## Periodic Jobs

### Basic Periodic Job
```hcl
periodic {
  cron = "*/15 * * * * *"
}
```

### Periodic with Time Zone
```hcl
periodic {
  cron      = "*/15 * * * * *"
  time_zone = "America/New_York"
}
```

## Parameterized Jobs

### Basic Parameterized Job
```hcl
parameterized {
  payload       = "required"
  meta_required = ["dispatcher_email"]
  meta_optional = ["pager_email"]
}
```

### Dispatch Payload
```hcl
dispatch_payload {
  file = "config.json"
}
```

## Multi-Region Jobs

### Multi-Region Configuration
```hcl
multiregion {
  strategy {
    max_parallel = 1
    on_failure   = "fail_all"
  }

  region "west" {
    count = 2
    datacenters = ["west-1"]
    meta {
      my-key = "my-value-west"
    }
  }

  region "east" {
    count = 5
    datacenters = ["east-1", "east-2"]
    meta {
      my-key = "my-value-east"
    }
  }
}
```

## Vault Integration

### Basic Vault Configuration
```hcl
vault {
  cluster  = "default"
  role     = "prod"
  
  change_mode   = "signal"
  change_signal = "SIGUSR1"
}
```

## Identity Configuration

### Workload Identity
```hcl
identity {
  env         = true
  file        = true
  filepath    = "local/example.jwt"
  
  change_mode = "restart"
}
```

### OIDC Identity
```hcl
identity {
  name        = "example"
  aud         = ["oidc.example.com"]
  file        = true
  ttl         = "1h"
  
  change_mode   = "signal"
  change_signal = "SIGHUP"
}
```

## HCL2 Features

### Variables
```hcl
variable "image_id" {
  type        = string
  description = "The docker image used for task."
}

task "server" {
  config {
    image = var.image_id
  }
}
```

### Local Values
```hcl
locals {
  default_name_prefix = "${var.project_name}-web"
  name_prefix         = "${var.name_prefix != "" ? var.name_prefix : local.default_name_prefix}"
}

job "example" {
  name = "${local.name_prefix}_loadbalancer"
}
```

### Functions
```hcl
task "server" {
  config {
    image = "my-app"
    args = [
      "--bind", "${NOMAD_ADDR_RPC}",
      "--logs", "${NOMAD_ALLOC_DIR}/logs",
    ]
  }
}
```

## Meta Configuration

### Job Meta
```hcl
meta {
  team         = "sre"
  organization = "hashicorp"
}
```

### Meta with Special Characters
```hcl
meta = {
  "project.team" = "sre"
}
```

## Spread Configuration

### Basic Spread
```hcl
spread {
  attribute = "${node.datacenter}"
}
```

### Spread with Targets
```hcl
spread {
  attribute = "${meta.rack}"
  target "r1" {
    percent = 60
  }
  target "r2" {
    percent = 40
  }
}
```

## Complete Example

### Full Job Specification
```hcl
job "docs" {
  region = "us"
  datacenters = ["us-west-1", "us-east-1"]
  type = "service"
  
  update {
    stagger       = "30s"
    max_parallel = 2
  }
  
  group "webs" {
    count = 5
    
    network {
      port "http" {}
      port "https" {
        static = 443
      }
    }
    
    service {
      name = "count-api"
      port = "http"
      
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }
    
    task "frontend" {
      driver = "docker"
      
      config {
        image = "hashicorp/web-frontend"
        ports = ["http", "https"]
      }
      
      env {
        DB_HOST = "db01.example.com"
        DB_USER = "web"
        DB_PASS = "loremipsum"
      }
      
      resources {
        cpu    = 500
        memory = 128
      }
    }
  }
}
```

## Best Practices

### Job Organization
- Use descriptive job names
- Group related tasks together
- Use appropriate job types for your workload
- Set reasonable resource limits

### Service Configuration
- Always include health checks
- Use appropriate service tags
- Configure proper restart policies
- Use Consul Connect for service mesh

### Resource Management
- Set appropriate CPU and memory limits
- Use constraints to ensure proper placement
- Configure network resources appropriately
- Use volumes for persistent data

### Security
- Use Vault for secrets management
- Configure proper identity and authentication
- Use read-only volumes where possible
- Limit container capabilities

This reference covers the essential aspects of Nomad job specification using HCL. For more detailed information, refer to the official Nomad documentation. 