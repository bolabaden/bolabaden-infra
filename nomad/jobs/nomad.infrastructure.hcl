# Nomad job for HA infrastructure services (Consul, Vault)
# Equivalent to compose/docker-compose.nomad.yml but with HA configuration
# Variables are loaded from ../variables.auto.tfvars.hcl automatically

variable "config_path" {
  type    = string
  default = "/home/ubuntu/my-media-stack/volumes"
}

job "infrastructure" {
  datacenters = ["dc1"]
  type        = "service"

  # Consul Server Group - HA with 3+ servers
  # Start with 1 for single node, scale to 3+ as nodes become available
  group "consul-servers" {
    count = 2  # HA: 2 servers (will scale to 3+ when third node available)

    spread {
      attribute = "${node.unique.name}"
      weight    = 100
    }

    # Allow placement on any eligible node (including balanced class)
    # Don't constrain to only "ready" nodes - allow placement on eligible nodes
    # This allows Consul to bootstrap and nodes can join as they become ready

    network {
      mode = "bridge"  # Bridge mode - will use dynamic ports initially

      port "consul_http" {
        static = 8500
        to     = 8500
      }

      port "consul_dns" {
        static = 8600
        to     = 8600
      }

      port "consul_server_rpc" {
        static = 8300
        to     = 8300
      }

      port "consul_serf_lan" {
        static = 8301
        to     = 8301
      }

      port "consul_serf_wan" {
        static = 8302
        to     = 8302
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "30s"
      healthy_deadline  = "5m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "30s"
      healthy_deadline  = "5m"
    }

    # Consul Server Task
    task "consul" {
      driver = "docker"

      config {
        image = "docker.io/hashicorp/consul:latest"
        ports = ["consul_http", "consul_dns", "consul_server_rpc", "consul_serf_lan", "consul_serf_wan"]
        volumes = [
          "${var.config_path}/consul/data:/consul/data"
        ]
        command = "agent"
        args = [
          "-server",
          "-ui",
          "-client=0.0.0.0",
          "-bind=0.0.0.0",
          "-data-dir=/consul/data",
          "-bootstrap-expect=2"
        ]
      }

      # Using command-line args instead of config file for simplicity

      # Consul reads config from file, not env var when using -config-dir
      # We'll use command args instead

      service {
        name = "consul"
        port = "consul_http"
        tags = ["consul", "server", "infrastructure"]

        check {
          type     = "http"
          path     = "/v1/status/leader"
          interval = "30s"
          timeout  = "10s"
        }
      }

      resources {
        cpu    = 100  # Reduced for single node deployment
        memory = 256
      }
    }
  }
}

