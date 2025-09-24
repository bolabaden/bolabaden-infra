# Monitoring and Metrics Services
# This job handles monitoring infrastructure including Grafana, Prometheus, and related services

job "monitoring" {
  datacenters = ["dc1"]
  type        = "service"

  # Prometheus metrics collection
  group "prometheus" {
    count = 1

    network {
      mode = "bridge"
      port "prometheus" {
        static = 9090
      }
    }

    service {
      name = "prometheus"
      port = "prometheus"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.${var.domain}`)",
        "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      ]

      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus"]
        volumes = [
          "${var.config_path}/prometheus:/etc/prometheus:ro",
          "${var.config_path}/prometheus/data:/prometheus:rw"
        ]
        command = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/etc/prometheus/console_libraries",
          "--web.console.templates=/etc/prometheus/consoles",
          "--storage.tsdb.retention.time=200h",
          "--web.enable-lifecycle"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # Grafana visualization dashboard
  group "grafana" {
    count = 1

    network {
      mode = "bridge"
      port "grafana" {
        static = 3000
      }
    }

    service {
      name = "grafana"
      port = "grafana"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.${var.domain}`)",
        "traefik.http.services.grafana.loadbalancer.server.port=3000"
      ]

      check {
        type     = "http"
        path     = "/api/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["grafana"]
        volumes = [
          "${var.config_path}/grafana/data:/var/lib/grafana:rw",
          "${var.config_path}/grafana/provisioning:/etc/grafana/provisioning:ro"
        ]
      }

      env {
        TZ                        = var.tz
        GF_SECURITY_ADMIN_USER    = "admin"
        GF_SECURITY_ADMIN_PASSWORD = "${var.grafana_admin_password}"
        GF_USERS_ALLOW_SIGN_UP    = "false"
        GF_INSTALL_PLUGINS        = "grafana-clock-panel,grafana-simple-json-datasource"
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # Node Exporter for system metrics
  group "node-exporter" {
    count = 1

    network {
      mode = "bridge"
      port "node-exporter" {
        static = 9100
      }
    }

    service {
      name = "node-exporter"
      port = "node-exporter"

      tags = ["internal", "metrics"]

      check {
        type     = "http"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image = "prom/node-exporter:latest"
        ports = ["node-exporter"]
        volumes = [
          "/proc:/host/proc:ro",
          "/sys:/host/sys:ro",
          "/:/rootfs:ro"
        ]
        command = [
          "--path.procfs=/host/proc",
          "--path.rootfs=/rootfs",
          "--path.sysfs=/host/sys",
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
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

  # cAdvisor for container metrics
  group "cadvisor" {
    count = 1

    network {
      mode = "bridge"
      port "cadvisor" {
        static = 8080
      }
    }

    service {
      name = "cadvisor"
      port = "cadvisor"

      tags = ["internal", "metrics"]

      check {
        type     = "http"
        path     = "/healthz"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "cadvisor" {
      driver = "docker"

      config {
        image = "gcr.io/cadvisor/cadvisor:latest"
        ports = ["cadvisor"]
        volumes = [
          "/:/rootfs:ro",
          "/var/run:/var/run:ro",
          "/sys:/sys:ro",
          "/var/lib/docker/:/var/lib/docker:ro",
          "/dev/disk/:/dev/disk:ro"
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

  # Blackbox Exporter for external monitoring
  group "blackbox-exporter" {
    count = 1

    network {
      mode = "bridge"
      port "blackbox-exporter" {
        static = 9115
      }
    }

    service {
      name = "blackbox-exporter"
      port = "blackbox-exporter"

      tags = ["internal", "metrics"]

      check {
        type     = "http"
        path     = "/probe?target=google.com&module=http_2xx"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "blackbox-exporter" {
      driver = "docker"

      config {
        image = "prom/blackbox-exporter:latest"
        ports = ["blackbox-exporter"]
        volumes = [
          "${var.config_path}/blackbox-exporter:/config:ro"
        ]
        command = [
          "--config.file=/config/blackbox.yml"
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

  # VictoriaMetrics for high-performance metrics storage
  group "victoriametrics" {
    count = 1

    network {
      mode = "bridge"
      port "victoriametrics" {
        static = 8428
      }
    }

    service {
      name = "victoriametrics"
      port = "victoriametrics"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.victoriametrics.rule=Host(`victoriametrics.${var.domain}`)",
        "traefik.http.services.victoriametrics.loadbalancer.server.port=8428"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "victoriametrics" {
      driver = "docker"

      config {
        image = "victoriametrics/victoria-metrics:latest"
        ports = ["victoriametrics"]
        volumes = [
          "${var.config_path}/victoriametrics/data:/victoria-metrics-data:rw"
        ]
        command = [
          "--storageDataPath=/victoria-metrics-data",
          "--retentionPeriod=12m",
          "--httpListenAddr=:8428"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # AlertManager for alert handling
  group "alertmanager" {
    count = 1

    network {
      mode = "bridge"
      port "alertmanager" {
        static = 9093
      }
    }

    service {
      name = "alertmanager"
      port = "alertmanager"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.alertmanager.rule=Host(`alertmanager.${var.domain}`)",
        "traefik.http.services.alertmanager.loadbalancer.server.port=9093"
      ]

      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image = "prom/alertmanager:latest"
        ports = ["alertmanager"]
        volumes = [
          "${var.config_path}/alertmanager:/etc/alertmanager:ro",
          "${var.config_path}/alertmanager/data:/alertmanager:rw"
        ]
        command = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--storage.path=/alertmanager",
          "--web.external-url=http://alertmanager.${var.domain}"
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

  # CrowdSec for security monitoring
  group "crowdsec" {
    count = 1

    network {
      mode = "bridge"
      port "crowdsec" {
        static = 8080
      }
    }

    service {
      name = "crowdsec"
      port = "crowdsec"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.crowdsec.rule=Host(`crowdsec.${var.domain}`)",
        "traefik.http.services.crowdsec.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/v1/watchers/login"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "crowdsec" {
      driver = "docker"

      config {
        image = "crowdsecurity/crowdsec:latest"
        ports = ["crowdsec"]
        volumes = [
          "${var.config_path}/crowdsec:/etc/crowdsec:rw",
          "/var/log:/var/log/host:ro",
          "/var/lib/docker/containers:/var/lib/docker/containers:ro"
        ]
        command = [
          "-c", "/etc/crowdsec/config.yaml",
          "-d", "/etc/crowdsec/data"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
