# Utility Services
# This job handles utility services including Homepage, Kuma, Dozzle, and other helper services

job "utilities" {
  datacenters = ["dc1"]
  type        = "service"

  # Homepage dashboard
  group "homepage" {
    count = 1

    network {
      mode = "bridge"
      port "homepage" {
        static = 3000
      }
    }

    service {
      name = "homepage"
      port = "homepage"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homepage.rule=Host(`homepage.${var.domain}`)",
        "traefik.http.services.homepage.loadbalancer.server.port=3000"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "15s"
      }
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage"
        ports = ["homepage"]
        volumes = [
          "${var.config_path}/homepage:/app/config:rw"
        ]
      }

      env {
        HOMEPAGE_ALLOWED_HOSTS        = "*"
        HOMEPAGE_VAR_TITLE            = "Bolabaden"
        HOMEPAGE_VAR_SEARCH_PROVIDER  = "duckduckgo"
        HOMEPAGE_VAR_HEADER_STYLE     = "glass"
        HOMEPAGE_VAR_THEME            = "dark"
        HOMEPAGE_CUSTOM_CSS           = "/app/config/custom.css"
        HOMEPAGE_CUSTOM_JS            = "/app/config/custom.js"
        HOMEPAGE_VAR_WEATHER_CITY     = "Iowa City"
        HOMEPAGE_VAR_WEATHER_LAT      = "41.661129"
        HOMEPAGE_VAR_WEATHER_LONG     = "-91.5302"
        HOMEPAGE_VAR_WEATHER_UNIT     = "fahrenheit"
        TZ                            = var.tz
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }

  # Dozzle log viewer
  group "dozzle" {
    count = 1

    network {
      mode = "bridge"
      port "dozzle" {
        static = 8080
      }
    }

    service {
      name = "dozzle"
      port = "dozzle"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dozzle.rule=Host(`dozzle.${var.domain}`)",
        "traefik.http.services.dozzle.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "dozzle" {
      driver = "docker"

      config {
        image = "amir20/dozzle:latest"
        ports = ["dozzle"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
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

  # SearxNG search engine
  group "searxng" {
    count = 1

    network {
      mode = "bridge"
      port "searxng" {
        static = 8080
      }
    }

    service {
      name = "searxng"
      port = "searxng"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.searxng.rule=Host(`searxng.${var.domain}`)",
        "traefik.http.services.searxng.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "searxng" {
      driver = "docker"

      config {
        image = "searxng/searxng:latest"
        ports = ["searxng"]
        volumes = [
          "${var.config_path}/searxng:/etc/searxng:rw"
        ]
      }

      env {
        SEARXNG_BASE_URL = var.searxng_internal_url
        TZ               = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # Code Server IDE
  group "code-server" {
    count = 1

    network {
      mode = "bridge"
      port "code-server" {
        static = 8443
      }
    }

    service {
      name = "code-server"
      port = "code-server"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.code-server.rule=Host(`code-server.${var.domain}`)",
        "traefik.http.services.code-server.loadbalancer.server.port=8443"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "code-server" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/code-server:latest"
        ports = ["code-server"]
        volumes = [
          "${var.config_path}/code-server:/config:rw",
          "${var.root_path}:/workspace:rw"
        ]
      }

      env {
        TZ                    = var.tz
        PUID                  = var.puid
        PGID                  = "121"
        UMASK                 = var.umask
        HASHED_PASSWORD       = var.codeserver_hashed_password
        SUDO_PASSWORD_HASH    = var.codeserver_sudo_password_hash
        PWA_APPNAME           = var.codeserver_pwa_appname
        DEFAULT_WORKSPACE     = var.codeserver_default_workspace
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # Session Manager
  group "session-manager" {
    count = 1

    network {
      mode = "bridge"
      port "session-manager" {
        static = 8080
      }
    }

    service {
      name = "session-manager"
      port = "session-manager"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.session-manager.rule=Host(`session-manager.${var.domain}`)",
        "traefik.http.services.session-manager.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "session-manager" {
      driver = "docker"

      config {
        image = "alpine:latest"
        ports = ["session-manager"]
        volumes = [
          "${var.root_path}/projects/kotor/kotorscript-session-manager:/workspace:rw"
        ]
        command = [
          "python3", "/workspace/session_manager.py"
        ]
      }

      env {
        DOMAIN                = var.domain
        SESSION_MANAGER_PORT  = var.session_manager_port
        INACTIVITY_TIMEOUT    = "3600"
        DEFAULT_WORKSPACE     = "/workspace"
        EXT_PATH              = "${var.root_path}/configs/extensions/holo-lsp-1.0.0.vsix"
        TZ                    = var.tz
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # Bolabaden NextJS website
  group "bolabaden-nextjs" {
    count = 1

    network {
      mode = "bridge"
      port "bolabaden-nextjs" {
        static = 3000
      }
    }

    service {
      name = "bolabaden-nextjs"
      port = "bolabaden-nextjs"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.bolabaden-nextjs.rule=Host(`bolabaden-nextjs.${var.domain}`)",
        "traefik.http.services.bolabaden-nextjs.loadbalancer.server.port=3000"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "bolabaden-nextjs" {
      driver = "docker"

      config {
        image = "th3w1zard1/bolabaden-nextjs:latest"
        ports = ["bolabaden-nextjs"]
      }

      env {
        NODE_ENV    = "production"
        PORT        = "3000"
        HOSTNAME    = "0.0.0.0"
        ALLOW_ORIGIN = "*"
        TZ          = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # Watchtower for automatic updates
  group "watchtower" {
    count = 1

    network {
      mode = "bridge"
      port "watchtower" {
        static = 8080
      }
    }

    service {
      name = "watchtower"
      port = "watchtower"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "watchtower" {
      driver = "docker"

      config {
        image = "containrrr/watchtower:latest"
        ports = ["watchtower"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "${var.config_path}/watchtower:/config:ro"
        ]
      }

      env {
        DOCKER_HOST                    = var.docker_host
        DOCKER_API_VERSION             = "1.24"
        DOCKER_TLS_VERIFY              = "false"
        TZ                            = var.tz
        REPO_USER                     = var.watchtower_repo_user
        REPO_PASS                     = var.sudo_password
        WATCHTOWER_INCLUDE_RESTARTING = var.watchtower_include_restarting
        WATCHTOWER_INCLUDE_STOPPED    = var.watchtower_include_stopped
        WATCHTOWER_REVIVE_STOPPED     = var.watchtower_revive_stopped
        WATCHTOWER_LABEL_ENABLE       = var.watchtower_label_enable
        WATCHTOWER_DISABLE_CONTAINERS = var.watchtower_disable_containers
        WATCHTOWER_LABEL_TAKE_PRECEDENCE = var.watchtower_label_take_precedence
        WATCHTOWER_SCOPE              = var.watchtower_scope
        WATCHTOWER_POLL_INTERVAL      = var.watchtower_poll_interval
        WATCHTOWER_SCHEDULE           = var.watchtower_schedule
        WATCHTOWER_MONITOR_ONLY       = var.watchtower_monitor_only
        WATCHTOWER_NO_RESTART         = var.watchtower_no_restart
        WATCHTOWER_NO_PULL            = var.watchtower_no_pull
        WATCHTOWER_CLEANUP            = var.watchtower_cleanup
        WATCHTOWER_REMOVE_VOLUMES     = var.watchtower_remove_volumes
        WATCHTOWER_ROLLING_RESTART    = var.watchtower_rolling_restart
        WATCHTOWER_TIMEOUT            = var.watchtower_timeout
        WATCHTOWER_RUN_ONCE           = var.watchtower_run_once
        WATCHTOWER_NO_STARTUP_MESSAGE = var.watchtower_no_startup_message
        WATCHTOWER_WARN_ON_HEAD_FAILURE = var.watchtower_warn_on_head_failure
        WATCHTOWER_HTTP_API_UPDATE   = var.watchtower_http_api_update
        WATCHTOWER_HTTP_API_TOKEN    = var.watchtower_http_api_token
        WATCHTOWER_HTTP_API_PERIODIC_POLLS = var.watchtower_http_api_periodic_polls
        WATCHTOWER_HTTP_API_METRICS  = var.watchtower_http_api_metrics
        WATCHTOWER_DEBUG             = var.watchtower_debug
        WATCHTOWER_TRACE             = var.watchtower_trace
        WATCHTOWER_LOG_LEVEL         = var.watchtower_log_level
        WATCHTOWER_LOG_FORMAT        = var.watchtower_log_format
        NO_COLOR                     = var.no_color
        WATCHTOWER_PORCELAIN         = var.watchtower_porcelain
        WATCHTOWER_NOTIFICATION_URL  = var.watchtower_notification_url
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
