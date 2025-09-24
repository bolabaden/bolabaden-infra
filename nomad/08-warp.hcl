# WARP Networking Services
# This job handles Cloudflare WARP networking and NAT routing services

job "warp-networking" {
  datacenters = ["dc1"]
  type        = "service"

  # WARP NAT Gateway
  group "warp-nat-gateway" {
    count = 1

    network {
      mode = "bridge"
      port "warp-nat-gateway" {
        static = 1080
      }
    }

    service {
      name = "warp-nat-gateway"
      port = "warp-nat-gateway"

      tags = ["internal"]

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "warp-nat-gateway" {
      driver = "docker"

      config {
        image = "caomingjun/warp:latest"
        ports = ["warp-nat-gateway"]
        volumes = [
          "${var.config_path}/warp/data:/var/lib/cloudflare-warp:rw"
        ]
      }

      env {
        WARP_SLEEP       = "2"
        WARP_LICENSE_KEY = var.warp_license_key
        TUNNEL_TOKEN     = var.tunnel_token
        TZ               = var.tz
      }

      # WARP requires special capabilities for network access
      capabilities {
        add = ["NET_ADMIN", "MKNOD", "AUDIT_WRITE"]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # WARP Router
  group "warp-router" {
    count = 1

    network {
      mode = "bridge"
      port "warp-router" {
        static = 8080
      }
    }

    service {
      name = "warp-router"
      port = "warp-router"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "warp-router" {
      driver = "docker"

      config {
        image = "warp/router:latest"
        ports = ["warp-router"]
        volumes = [
          "${var.config_path}/warp/router:/app/config:rw"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # IP Checker for WARP
  group "ip-checker-warp" {
    count = 1

    network {
      mode = "bridge"
      port "ip-checker" {
        static = 8080
      }
    }

    service {
      name = "ip-checker-warp"
      port = "ip-checker"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "ip-checker-warp" {
      driver = "docker"

      config {
        image = "ip-checker/warp:latest"
        ports = ["ip-checker"]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
