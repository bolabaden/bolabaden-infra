# Headscale VPN Services
# This job handles Headscale VPN coordination server and related services

job "headscale" {
  datacenters = ["dc1"]
  type        = "service"

  # Headscale server
  group "headscale-server" {
    count = 1

    network {
      mode = "bridge"
      port "headscale" {
        static = 8080
      }
    }

    service {
      name = "headscale"
      port = "headscale"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.headscale.rule=Host(`headscale.${var.domain}`)",
        "traefik.http.services.headscale.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "headscale-server" {
      driver = "docker"

      config {
        image = "headscale/headscale:latest"
        ports = ["headscale"]
        volumes = [
          "${var.config_path}/headscale:/etc/headscale:ro",
          "${var.config_path}/headscale/data:/var/lib/headscale:rw"
        ]
        command = [
          "headscale",
          "serve"
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

  # Headscale client (for management)
  group "headscale-client" {
    count = 1

    network {
      mode = "bridge"
      port "headscale-client" {
        static = 8081
      }
    }

    service {
      name = "headscale-client"
      port = "headscale-client"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.headscale-client.rule=Host(`headscale-client.${var.domain}`)",
        "traefik.http.services.headscale-client.loadbalancer.server.port=8081"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "headscale-client" {
      driver = "docker"

      config {
        image = "headscale/headscale:latest"
        ports = ["headscale-client"]
        volumes = [
          "${var.config_path}/headscale:/etc/headscale:ro"
        ]
        command = [
          "headscale",
          "nodes",
          "list"
        ]
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
