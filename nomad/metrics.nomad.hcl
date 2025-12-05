# Metrics Stack Nomad Job
# Equivalent to docker-compose.metrics.yml
#
# This job includes all monitoring and observability services:
# - VictoriaMetrics (time series database)
# - Prometheus (metrics collector)
# - Grafana (visualization)
# - Node Exporter (host metrics)
# - cAdvisor (container metrics)
# - Loki (log aggregation)
# - Promtail (log collector)
# - Blackbox Exporter (endpoint monitoring)

job "metrics-stack" {
  datacenters = ["dc1"]
  type        = "service"

  # VictoriaMetrics Group
  group "victoriametrics-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "victoriametrics" { to = 8428 }
    }

    # Init task for VictoriaMetrics
    task "init-victoriametrics" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "docker.io/victoriametrics/victoria-metrics:latest"
        command = "/bin/sh"
        args    = ["-c", "chown -R 65534:65534 /storage && chmod -R 755 /storage"]
        volumes = [
          "${var.config_path}/victoriametrics:/storage"
        ]
      }

      user = "root"

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 0
      }
    }

    # VictoriaMetrics - Time Series Database
    task "victoriametrics" {
      driver = "docker"

      config {
        image = "docker.io/victoriametrics/victoria-metrics:latest"
        ports = ["victoriametrics"]
        args  = [
          "--bigMergeConcurrency=0",
          "--dedup.minScrapeInterval=0s",
          "--enableTCP6=false",
          "--finalMergeDelay=0s",
          "--http.maxGracefulShutdownDuration=7s",
          "--http.shutdownDelay=0s",
          "--httpListenAddr=:8428",
          "--influx.maxLineSize=262144",
          "--loggerFormat=default",
          "--loggerLevel=INFO",
          "--memory.allowedPercent=60",
          "--promscrape.maxScrapeSize=16777216",
          "--retentionPeriod=1y",
          "--search.maxConcurrentRequests=8",
          "--search.maxMemoryPerQuery=1GB",
          "--search.maxPointsPerTimeseries=30000",
          "--search.maxQueryDuration=30s",
          "--search.maxSeries=30000",
          "--search.maxTagKeys=100000",
          "--search.maxTagValues=100000",
          "--search.maxUniqueTimeseries=300000",
          "--smallMergeConcurrency=0",
          "--storageDataPath=/storage"
        ]
        volumes = [
          "${var.config_path}/victoriametrics:/storage"
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      env {
        VM_RETENTION_PERIOD                = "1y"
        VM_MEMORY_ALLOWED_PERCENT          = "60"
        VM_SEARCH_MAX_CONCURRENT_REQUESTS  = "8"
        VM_INSERT_MAX_CONCURRENT_REQUESTS  = "32"
      }

      resources {
        cpu        = 2000
        memory     = 2048
        memory_max = 4096
      }

      service {
        name = "victoriametrics"
        port = "victoriametrics"
        tags = [
          "victoriametrics",
          "${var.domain}",
          "prometheus.io/scrape=true",
          "prometheus.io/port=8428",
          "prometheus.io/path=/metrics"
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Prometheus Group
  group "prometheus-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "prometheus" { to = 9090 }
    }

    # Init task for Prometheus
    task "init-prometheus" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "docker.io/prom/prometheus:latest"
        command = "/bin/sh"
        args    = ["-c", "chown -R 65534:65534 /prometheus"]
        volumes = [
          "${var.config_path}/prometheus/data:/prometheus"
        ]
      }

      user = "root"

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 0
      }
    }

    # Prometheus - Metrics Collector
    task "prometheus" {
      driver = "docker"

      config {
        image = "docker.io/prom/prometheus:latest"
        ports = ["prometheus"]
        args  = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--log.format=logfmt",
          "--log.level=info",
          "--query.max-concurrency=20",
          "--query.max-samples=50000000",
          "--query.timeout=2m",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.size=0",
          "--storage.tsdb.retention.time=15d",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
          "--web.enable-admin-api",
          "--web.enable-lifecycle",
          "--web.max-connections=512"
        ]
        volumes = [
          "${var.config_path}/prometheus/data:/prometheus"
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      # Prometheus configuration
      template {
        data = <<EOF
# Prometheus configuration (basic - expand as needed)
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'victoriametrics'
    static_configs:
      - targets: ['victoriametrics:8428']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
EOF
        destination = "local/prometheus.yml"
      }

      env {
        PROMETHEUS_RETENTION_TIME        = "15d"
        PROMETHEUS_RETENTION_SIZE        = "0"
        PROMETHEUS_QUERY_MAX_CONCURRENCY = "20"
        PROMETHEUS_QUERY_TIMEOUT         = "2m"
        PROMETHEUS_QUERY_MAX_SAMPLES     = "50000000"
        PROMETHEUS_WEB_MAX_CONNECTIONS   = "512"
      }

      resources {
        cpu        = 1000
        memory     = 2048
        memory_max = 4096
      }

      service {
        name = "prometheus"
        port = "prometheus"
        tags = [
          "prometheus",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.prometheus.middlewares=nginx-auth@file",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.${var.domain}`) || Host(`prometheus.${var.ts_hostname}.${var.domain}`)",
          "traefik.http.services.prometheus.loadbalancer.server.port=9090",
          "homepage.group=Infrastructure",
          "homepage.name=Prometheus",
          "homepage.icon=prometheus.png",
          "homepage.href=https://prometheus.${var.domain}",
          "homepage.description=Prometheus is an open-source monitoring system",
          "prometheus.io/scrape=true",
          "prometheus.io/port=9090",
          "prometheus.io/path=/metrics"
        ]

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Grafana Group  
  group "grafana-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "grafana" { to = 3000 }
    }

    # Grafana - Visualization Dashboard
    task "grafana" {
      driver = "docker"

      config {
        image = "docker.io/grafana/grafana:latest"
        ports = ["grafana"]
        volumes = [
          "${var.config_path}/grafana/dashboards:/var/lib/grafana/dashboards",
          "${var.config_path}/grafana/provisioning:/etc/grafana/provisioning",
          "${var.config_path}/grafana/logs:/data/log"
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      env {
        GF_LOG_LEVEL                  = "info"
        GF_SERVER_DOMAIN              = "grafana.${var.domain}"
        GF_SERVER_ROOT_URL            = "https://grafana.${var.domain}"
        GF_SECURITY_ADMIN_USER        = "admin"
        GF_SECURITY_ADMIN_PASSWORD    = var.grafana_admin_password
        GF_SECURITY_SECRET_KEY        = var.grafana_secret_key
        GF_PATHS_PROVISIONING         = "/etc/grafana/provisioning"
        GF_SERVER_SERVE_FROM_SUB_PATH = "false"
        GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS = "victoriametrics-datasource"
        GF_SECURITY_COOKIE_SECURE     = "true"
        GF_SECURITY_COOKIE_SAMESITE   = "lax"
        GF_USERS_ALLOW_SIGN_UP        = "false"
        GF_USERS_ALLOW_ORG_CREATE     = "false"
      }

      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }

      service {
        name = "grafana"
        port = "grafana"
        tags = [
          "grafana",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.${var.domain}`) || Host(`grafana.${var.ts_hostname}.${var.domain}`)",
          "traefik.http.services.grafana.loadbalancer.server.port=3000",
          "homepage.group=Infrastructure",
          "homepage.name=Grafana",
          "homepage.icon=grafana.png",
          "homepage.href=https://grafana.${var.domain}",
          "homepage.description=Grafana is an open-source platform for monitoring and observability",
          "prometheus.io/scrape=true",
          "prometheus.io/port=3000",
          "prometheus.io/path=/metrics"
        ]

        check {
          type     = "http"
          path     = "/api/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Node Exporter Group
  group "node-exporter-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "node_exporter" { to = 9100 }
    }

    # Node Exporter - Host System Metrics
    task "node-exporter" {
      driver = "docker"

      config {
        image = "docker.io/prom/node-exporter:latest"
        ports = ["node_exporter"]
        args  = [
          "--path.procfs=/host/proc",
          "--path.rootfs=/rootfs",
          "--path.sysfs=/host/sys",
          "--collector.cpu.info",
          "--collector.diskstats.device-exclude=^(ram|loop|fd|(h|s|v)d[a-z]|nvme\\d+n\\d+p)\\d+$$",
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)",
          "--collector.interrupts",
          "--collector.processes",
          "--collector.systemd",
          "--collector.systemd.unit-include=.*",
          "--collector.systemd.unit-exclude=.+\\.(automount|device|mount|scope|slice)",
          "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$$"
        ]
        volumes = [
          "/proc:/host/proc:ro",
          "/sys:/host/sys:ro",
          "/:/rootfs:ro",
          "/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "/run/udev/data:/run/udev/data:ro"
        ]
      }

      env {
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/var/run/dbus/system_bus_socket"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "node_exporter"
        port = "node_exporter"
        tags = [
          "node-exporter",
          "${var.domain}",
          "prometheus.io/scrape=true",
          "prometheus.io/port=9100",
          "prometheus.io/path=/metrics"
        ]

        check {
          type     = "http"
          path     = "/metrics"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # cAdvisor Group
  group "cadvisor-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "cadvisor" { to = 8080 }
    }

    # cAdvisor - Container Metrics
    task "cadvisor" {
      driver = "docker"

      config {
        image      = "gcr.io/cadvisor/cadvisor:latest"
        ports      = ["cadvisor"]
        privileged = true
        args = [
          "--housekeeping_interval=30s",
          "--docker_only=true",
          "--disable_metrics=cpu_topology,disk,memory_numa,tcp,udp,percpu,sched,process,hugetlb,referenced_memory,resctrl,cpuset,advtcp",
          "--store_container_labels=false"
        ]
        volumes = [
          "/:/rootfs:ro",
          "/var/run:/var/run:ro",
          "/sys:/sys:ro",
          "/var/lib/docker/:/var/lib/docker:ro",
          "/dev/disk/:/dev/disk:ro"
        ]
        devices = [
          {
            host_path      = "/dev/kmsg"
            container_path = "/dev/kmsg"
          }
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      resources {
        cpu        = 1000
        memory     = 512
        memory_max = 1024
      }

      service {
        name = "cadvisor"
        port = "cadvisor"
        tags = [
          "cadvisor",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.cadvisor.middlewares=nginx-auth@file",
          "traefik.http.routers.cadvisor.rule=Host(`cadvisor.${var.domain}`) || Host(`cadvisor.${var.ts_hostname}.${var.domain}`)",
          "traefik.http.services.cadvisor.loadbalancer.server.port=8080",
          "homepage.group=Monitoring",
          "homepage.name=cAdvisor",
          "homepage.icon=https://raw.githubusercontent.com/google/cadvisor/master/logo.png",
          "homepage.href=https://cadvisor.${var.domain}/",
          "homepage.description=Container resource usage and performance characteristics",
          "prometheus.io/scrape=true",
          "prometheus.io/port=8080",
          "prometheus.io/path=/metrics",
          "deunhealth.restart.on.unhealthy=true"
        ]

        check {
          type     = "http"
          path     = "/metrics"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Loki Group
  group "loki-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "loki" { to = 3100 }
    }

    # Loki - Log Aggregation
    task "loki" {
      driver = "docker"

      config {
        image = "docker.io/grafana/loki:latest"
        ports = ["loki"]
        args  = ["-config.file=/etc/loki/config.yaml"]
        volumes = [
          "${var.config_path}/loki/data:/loki"
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      # Basic Loki configuration
      template {
        data = <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF
        destination = "local/config.yaml"
      }

      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }

      service {
        name = "loki"
        port = "loki"
        tags = [
          "loki",
          "${var.domain}"
        ]

        check {
          type     = "http"
          path     = "/ready"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Promtail Group
  group "promtail-group" {
    count = 1

    network {
      mode = "bridge"
      
    }

    # Promtail - Log Collector
    task "promtail" {
      driver = "docker"

      config {
        image = "docker.io/grafana/promtail:latest"
        args  = ["-config.file=/etc/promtail/config.yaml"]
        volumes = [
          "/var/lib/docker/containers:/var/lib/docker/containers:ro",
          "/var/log:/var/log:ro"
        ]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      # Basic Promtail configuration
      template {
        data = <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
  
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*[^|]))
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          tag:
          container_name:
          stream:
      - output:
          source: output
EOF
        destination = "local/config.yaml"
      }

      env {
        DOCKER_HOST = "tcp://dockerproxy-ro:2375"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "promtail"
        tags = [
          "promtail",
          "${var.domain}"
        ]
      }
    }
  }

  # Blackbox Exporter Group
  group "blackbox-exporter-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "blackbox_exporter" { to = 9115 }
    }

    # Blackbox Exporter - Endpoint Monitoring
    task "blackbox-exporter" {
      driver = "docker"

      config {
        image = "docker.io/prom/blackbox-exporter:latest"
        ports = ["blackbox_exporter"]
        args  = ["--config.file=/etc/blackbox_exporter/config.yml"]
        extra_hosts = ["host.docker.internal:10.16.1.78"]
      }

      # Basic Blackbox Exporter configuration
      template {
        data = <<EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []
      method: GET
      preferred_ip_protocol: "ip4"
  
  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      valid_status_codes: []
  
  tcp_connect:
    prober: tcp
    timeout: 5s
  
  icmp:
    prober: icmp
    timeout: 5s
EOF
        destination = "local/config.yml"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "blackbox-exporter"
        port = "blackbox_exporter"
        tags = [
          "blackbox-exporter",
          "${var.domain}",
          "prometheus.io/scrape=true",
          "prometheus.io/port=9115",
          "prometheus.io/path=/metrics"
        ]

        check {
          type     = "http"
          path     = "/metrics"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
}

