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
  # Start with available nodes, scale to 3+ as nodes become available
  group "consul-servers" {
    count = 3  # HA: Minimum 3 servers for quorum (will scale as nodes become available)

    spread {
      attribute = "${node.unique.name}"
      weight    = 100
    }

    # Don't constrain to only "ready" nodes - allow placement on eligible nodes
    # This allows Consul to bootstrap and nodes can join as they become ready

    network {
      mode = "host"  # Host mode for Consul server communication

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
        network_mode = "host"
        volumes = [
          "${var.config_path}/consul/data:/consul/data",
          "local/consul-config.json:/consul/config/consul.json:ro"
        ]
        command = "agent"
        args = [
          "-server",
          "-ui",
          "-client=0.0.0.0",
          "-bind=0.0.0.0",
          "-data-dir=/consul/data",
          "-config-dir=/consul/config"
        ]
      }

      template {
        data = <<EOF
{
  "datacenter": "dc1",
  "data_dir": "/consul/data",
  "log_level": "INFO",
  "ui": true,
  "server": true,
  "bootstrap_expect": 3,
  "client_addr": "0.0.0.0",
  "bind_addr": "0.0.0.0",
  "addresses": {
    "http": "0.0.0.0",
    "dns": "0.0.0.0"
  },
  "ports": {
    "http": 8500,
    "dns": 8600,
    "server": 8300,
    "serf_lan": 8301,
    "serf_wan": 8302
  },
  "retry_join": [
    "172.245.88.16:8301",
    "172.245.88.15:8301",
    "172.245.88.17:8301",
    "170.9.225.137:8301",
    "209.54.102.83:8301"
  ],
  "retry_join_wan": [],
  "retry_interval": "30s",
  "retry_max": 0,
  "rejoin_after_leave": true,
  "leave_on_terminate": false,
  "skip_leave_on_interrupt": true,
  "disable_update_check": true,
  "enable_script_checks": true,
  "enable_local_script_checks": true
}
EOF
        destination = "local/consul-config.json"
      }

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
        cpu    = 500
        memory = 512
      }
    }
  }
}

