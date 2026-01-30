job "media-stack-web-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 70

  variable "tz" {
    type    = string
    default = "America/Chicago"
  }

  variable "puid" {
    type    = string
    default = "1002"
  }

  variable "pgid" {
    type    = string
    default = "988"
  }

  variable "domain" {
    type = string
  }

  variable "duckdns_subdomain" {
    type = string
  }

  variable "ts_hostname" {
    type = string
  }

  variable "config_path" {
    type    = string
    default = "./configs"
  }

  variable "certs_path" {
    type    = string
    default = "./certs"
  }

  variable "docker_sock" {
    type    = string
    default = "/var/run/docker.sock"
  }

  variable "searxng_hostname" {
    type = string
  }

  variable "searxng_url" {
    type = string
  }

  variable "homepage_allowed_hosts" {
    type = string
  }

  variable "homepage_var_title" {
    type = string
  }

  variable "homepage_var_search_provider" {
    type = string
  }

  variable "homepage_var_header_style" {
    type = string
  }

  variable "homepage_var_weather_city" {
    type = string
  }

  variable "homepage_var_weather_lat" {
    type = string
  }

  variable "homepage_var_weather_long" {
    type = string
  }

  variable "homepage_var_weather_unit" {
    type = string
  }

  variable "umask" {
    type    = string
    default = "0000"
  }

  variable "speedtest_tracker_admin_email" {
    type = string
  }

  variable "speedtest_tracker_admin_name" {
    type = string
  }

  variable "speedtest_tracker_admin_password" {
    type = string
  }

  variable "speedtest_tracker_api_rate_limit" {
    type = string
  }

  variable "speedtest_tracker_app_key" {
    type = string
  }

  variable "speedtest_tracker_app_name" {
    type = string
  }

  variable "speedtest_tracker_app_timezone" {
    type = string
  }

  variable "speedtest_tracker_app_url" {
    type = string
  }

  variable "speedtest_tracker_asset_url" {
    type = string
  }

  variable "speedtest_tracker_chart_begin_at_zero" {
    type = string
  }

  variable "speedtest_tracker_chart_datetime_format" {
    type = string
  }

  variable "speedtest_tracker_content_width" {
    type = string
  }

  variable "speedtest_tracker_datetime_format" {
    type = string
  }

  variable "speedtest_tracker_db_connection" {
    type = string
  }

  variable "speedtest_tracker_display_timezone" {
    type = string
  }

  variable "speedtest_tracker_prune_results_older_than" {
    type = string
  }

  variable "speedtest_tracker_public_dashboard" {
    type = string
  }

  variable "speedtest_tracker_blocked_servers" {
    type = string
  }

  variable "speedtest_tracker_interface" {
    type = string
  }

  variable "speedtest_tracker_schedule" {
    type = string
  }

  variable "speedtest_tracker_servers" {
    type = string
  }

  variable "speedtest_tracker_skip_ips" {
    type = string
  }

  variable "speedtest_tracker_threshold_download" {
    type = string
  }

  variable "speedtest_tracker_threshold_enabled" {
    type = string
  }

  variable "speedtest_tracker_threshold_ping" {
    type = string
  }

  variable "speedtest_tracker_threshold_upload" {
    type = string
  }

  variable "flaresolverr_log_level" {
    type = string
  }

  variable "flaresolverr_log_html" {
    type = string
  }

  variable "flaresolverr_captcha_solver" {
    type = string
  }

  variable "flaresolverr_port" {
    type = string
  }

  variable "flaresolverr_host" {
    type = string
  }

  variable "flaresolverr_headless" {
    type = string
  }

  variable "flaresolverr_browser_timeout" {
    type = string
  }

  variable "flaresolverr_test_url" {
    type = string
  }

  variable "flaresolverr_prometheus_enabled" {
    type = string
  }

  variable "prometheus_port" {
    type = string
  }

  variable "warp_ipv4_address" {
    type = string
  }

  variable "mongodb_ipv4_address" {
    type = string
  }

  variable "redis_ipv4_address" {
    type = string
  }

  variable "traefik_ipv4_address" {
    type = string
  }

  variable "codeserver_password" {
    type = string
  }

  variable "codeserver_sudo_password" {
    type = string
  }

  variable "codeserver_default_workspace" {
    type = string
  }

  variable "root_dir" {
    type = string
  }

  variable "tinyauth_secret" {
    type = string
  }

  variable "tinyauth_app_url" {
    type = string
  }

  variable "tinyauth_users" {
    type = string
  }

  variable "tinyauth_google_client_id" {
    type = string
  }

  variable "tinyauth_google_client_secret" {
    type = string
  }

  variable "tinyauth_github_client_id" {
    type = string
  }

  variable "tinyauth_github_client_secret" {
    type = string
  }

  variable "tinyauth_session_expiry" {
    type = string
  }

  variable "tinyauth_cookie_secure" {
    type = string
  }

  variable "tinyauth_app_title" {
    type = string
  }

  variable "tinyauth_login_max_retries" {
    type = string
  }

  variable "tinyauth_login_timeout" {
    type = string
  }

  variable "tinyauth_oauth_auto_redirect" {
    type = string
  }

  variable "tinyauth_oauth_whitelist" {
    type = string
  }

  # Web Services Group
  group "search-and-dashboard" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "searxng"
      port = "8080"
      
      check {
        type     = "http"
        name     = "searxng-health"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
      }

      tags = [
        "search",
        "searxng",
        "homepage.group=Search",
        "homepage.name=SearxNG",
        "homepage.icon=searxng.png",
        "homepage.href=https://searxng.${var.domain}/",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "searxng" {
      driver = "docker"

      config {
        image = "searxng/searxng:latest"
        hostname = "${var.searxng_hostname}"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/searxng:/etc/searxng"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
        SEARXNG_BASE_URL = "${var.searxng_url}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "homepage"
      port = "3000"
      
      check {
        type     = "http"
        name     = "homepage-health"
        path     = "/"
        interval = "30s"
        timeout  = "15s"
      }

      tags = [
        "dashboard",
        "homepage",
        "traefik.enable=true",
        "traefik.http.routers.homepage.middlewares=nginx-auth@file",
        "traefik.http.routers.homepage.rule=Host(`homepage.${var.domain}`) || Host(`homepage.${var.duckdns_subdomain}.duckdns.org`) || Host(`homepage.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.homepage.loadbalancer.server.port=3000",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage"
        hostname = "homepage"
        network_mode = "publicnet"
        
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:z",
          "${var.config_path}/homepage:/app/config"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        HOMEPAGE_ALLOWED_HOSTS = "${var.homepage_allowed_hosts}"
        HOMEPAGE_VAR_TITLE = "${var.homepage_var_title}"
        HOMEPAGE_VAR_SEARCH_PROVIDER = "${var.homepage_var_search_provider}"
        HOMEPAGE_VAR_HEADER_STYLE = "${var.homepage_var_header_style}"
        HOMEPAGE_VAR_WEATHER_CITY = "${var.homepage_var_weather_city}"
        HOMEPAGE_VAR_WEATHER_LAT = "${var.homepage_var_weather_lat}"
        HOMEPAGE_VAR_WEATHER_LONG = "${var.homepage_var_weather_long}"
        HOMEPAGE_VAR_WEATHER_UNIT = "${var.homepage_var_weather_unit}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "monitoring-tools" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "speedtest"
      port = "80"
      
      check {
        type     = "http"
        name     = "speedtest-health"
        path     = "/"
        interval = "30s"
        timeout  = "15s"
      }

      tags = [
        "monitoring",
        "speedtest",
        "traefik.enable=true",
        "traefik.http.routers.speedtest.rule=Host(`speedtest.${var.domain}`) || Host(`speedtest.${var.duckdns_subdomain}.duckdns.org`) || Host(`speedtest.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.speedtest.loadbalancer.server.port=80",
        "homepage.group=Network Monitoring",
        "homepage.name=Speedtest",
        "homepage.icon=speedtest.png",
        "homepage.href=https://speedtest.${var.domain}/",
        "homepage.description=Regularly tests your internet speed and tracks performance over time",
        "homepage.widget.type=speedtest",
        "homepage.widget.url=https://speedtest.${var.domain}",
        "homepage.widget.fields=[\"download\", \"upload\", \"ping\", \"speedtest\"]",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "speedtest" {
      driver = "docker"

      config {
        image = "linuxserver/speedtest-tracker"
        hostname = "speedtest"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/speedtest-tracker/config:/config",
          "${var.certs_path}/speedtest-tracker/keys:/config/keys"
        ]

        security_opt = ["no-new-privileges:true"]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "autoheal" = "true",
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
        ADMIN_EMAIL = "${var.speedtest_tracker_admin_email}"
        ADMIN_NAME = "${var.speedtest_tracker_admin_name}"
        ADMIN_PASSWORD = "${var.speedtest_tracker_admin_password}"
        API_RATE_LIMIT = "${var.speedtest_tracker_api_rate_limit}"
        APP_KEY = "${var.speedtest_tracker_app_key}"
        APP_NAME = "${var.speedtest_tracker_app_name}"
        APP_TIMEZONE = "${var.speedtest_tracker_app_timezone}"
        APP_URL = "${var.speedtest_tracker_app_url}"
        ASSET_URL = "${var.speedtest_tracker_asset_url}"
        CHART_BEGIN_AT_ZERO = "${var.speedtest_tracker_chart_begin_at_zero}"
        CHART_DATETIME_FORMAT = "${var.speedtest_tracker_chart_datetime_format}"
        CONTENT_WIDTH = "${var.speedtest_tracker_content_width}"
        DATETIME_FORMAT = "${var.speedtest_tracker_datetime_format}"
        DB_CONNECTION = "${var.speedtest_tracker_db_connection}"
        DISPLAY_TIMEZONE = "${var.speedtest_tracker_display_timezone}"
        PRUNE_RESULTS_OLDER_THAN = "${var.speedtest_tracker_prune_results_older_than}"
        PUBLIC_DASHBOARD = "${var.speedtest_tracker_public_dashboard}"
        SPEEDTEST_BLOCKED_SERVERS = "${var.speedtest_tracker_blocked_servers}"
        SPEEDTEST_INTERFACE = "${var.speedtest_tracker_interface}"
        SPEEDTEST_SCHEDULE = "${var.speedtest_tracker_schedule}"
        SPEEDTEST_SERVERS = "${var.speedtest_tracker_servers}"
        SPEEDTEST_SKIP_IPS = "${var.speedtest_tracker_skip_ips}"
        THRESHOLD_DOWNLOAD = "${var.speedtest_tracker_threshold_download}"
        THRESHOLD_ENABLED = "${var.speedtest_tracker_threshold_enabled}"
        THRESHOLD_PING = "${var.speedtest_tracker_threshold_ping}"
        THRESHOLD_UPLOAD = "${var.speedtest_tracker_threshold_upload}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "dozzle"
      port = "8080"

      tags = [
        "monitoring",
        "logs",
        "dozzle",
        "traefik.enable=true",
        "traefik.http.routers.dozzle.middlewares=nginx-auth@file",
        "traefik.http.routers.dozzle.rule=Host(`dozzle.${var.domain}`) || Host(`dozzle.${var.duckdns_subdomain}.duckdns.org`) || Host(`dozzle.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.dozzle.loadbalancer.server.port=8080",
        "homepage.group=System Monitoring",
        "homepage.name=Dozzle",
        "homepage.icon=dozzle.png",
        "homepage.href=https://dozzle.${var.domain}/",
        "homepage.description=Real-time log viewer for Docker containers",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "dozzle" {
      driver = "docker"

      config {
        image = "amir20/dozzle"
        hostname = "dozzle"
        network_mode = "publicnet"
        
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:z"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "authentication-services" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "tinyauth"
      port = "3000"

      tags = [
        "auth",
        "tinyauth",
        "traefik.enable=true",
        "traefik.http.routers.tinyauth.rule=Host(`auth.${var.domain}`) || Host(`auth.${var.duckdns_subdomain}.duckdns.org`) || Host(`auth.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.middlewares.tinyauth.forwardauth.address=http://auth:3000/api/auth/traefik",
        "homepage.group=Security",
        "homepage.name=TinyAuth",
        "homepage.icon=shield-lock.png",
        "homepage.href=https://auth.${var.domain}/",
        "homepage.description=Authentication service for securing your applications",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "tinyauth" {
      driver = "docker"

      config {
        image = "ghcr.io/steveiliop56/tinyauth:v3"
        hostname = "auth"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/tinyauth:/data"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        SECRET = "${var.tinyauth_secret}"
        APP_URL = "${var.tinyauth_app_url}"
        USERS = "${var.tinyauth_users}"
        GOOGLE_CLIENT_ID = "${var.tinyauth_google_client_id}"
        GOOGLE_CLIENT_SECRET = "${var.tinyauth_google_client_secret}"
        GITHUB_CLIENT_ID = "${var.tinyauth_github_client_id}"
        GITHUB_CLIENT_SECRET = "${var.tinyauth_github_client_secret}"
        SESSION_EXPIRY = "${var.tinyauth_session_expiry}"
        COOKIE_SECURE = "${var.tinyauth_cookie_secure}"
        APP_TITLE = "${var.tinyauth_app_title}"
        LOGIN_MAX_RETRIES = "${var.tinyauth_login_max_retries}"
        LOGIN_TIMEOUT = "${var.tinyauth_login_timeout}"
        OAUTH_AUTO_REDIRECT = "${var.tinyauth_oauth_auto_redirect}"
        OAUTH_WHITELIST = "${var.tinyauth_oauth_whitelist}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "nginx-auth"
      port = "80"
      
      check {
        type     = "http"
        name     = "nginx-auth-health"
        path     = "/health"
        interval = "30s"
        timeout  = "10s"
      }

      tags = [
        "auth",
        "middleware",
        "nginx-auth",
        "traefik.enable=true",
        "traefik.http.services.nginx-auth.loadbalancer.server.port=80",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "nginx-auth" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        hostname = "nginx-auth"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/nginx-middlewares/nginx.conf:/etc/nginx/nginx.conf:ro",
          "${var.config_path}/nginx-middlewares/auth:/etc/nginx/auth:ro",
          "${var.config_path}/nginx-middlewares/cache:/var/cache/nginx",
          "${var.config_path}/nginx-middlewares/logs:/var/log/nginx"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "development-tools" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "code-dev"
      port = "8443"

      tags = [
        "development",
        "code-server",
        "traefik.enable=true",
        "traefik.http.routers.code-dev.middlewares=nginx-auth@file",
        "traefik.http.routers.code-dev.rule=Host(`code-dev.${var.domain}`) || Host(`code-dev.${var.duckdns_subdomain}.duckdns.org`) || Host(`code-dev.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.code-dev.loadbalancer.server.port=8443",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "code-dev" {
      driver = "docker"

      config {
        image = "linuxserver/code-server:latest"
        hostname = "code-dev"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/code-server/dev/config:/config",
          "${var.config_path}/code-server/dev/workspace:/workspace",
          "${var.root_dir}:/workspace"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
        CODESERVER_PASSWORD = "${var.codeserver_password}"
        PASSWORD = "${var.codeserver_password}"
        CODESERVER_SUDO_PASSWORD = "${var.codeserver_sudo_password}"
        SUDO_PASSWORD = "${var.codeserver_sudo_password}"
        CODESERVER_DEFAULT_WORKSPACE = "${var.codeserver_default_workspace}"
        DEFAULT_WORKSPACE = "${var.codeserver_default_workspace}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "code-demo"
      port = "8443"

      tags = [
        "development",
        "code-server",
        "demo",
        "traefik.enable=true",
        "traefik.http.routers.code.rule=Host(`code.${var.domain}`) || Host(`code.${var.duckdns_subdomain}.duckdns.org`) || Host(`code.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.code.loadbalancer.server.port=8443",
        "homepage.group=Development",
        "homepage.name=Code Server",
        "homepage.icon=code-server.png",
        "homepage.href=https://code.${var.domain}/",
        "homepage.description=A web-based IDE for coding, editing, and debugging code",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "code-demo" {
      driver = "docker"

      config {
        image = "linuxserver/code-server:latest"
        hostname = "code"
        network_mode = "publicnet"
        
        volumes = [
          "${var.config_path}/code-server/demo/config:/config",
          "${var.config_path}/code-server/demo/workspace:/workspace"
        ]

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
        CODESERVER_SUDO_PASSWORD = "${var.codeserver_sudo_password}"
        SUDO_PASSWORD = "${var.codeserver_sudo_password}"
        CODESERVER_DEFAULT_WORKSPACE = "${var.codeserver_default_workspace}"
        DEFAULT_WORKSPACE = "${var.codeserver_default_workspace}"
      }

      resources {
        cpu    = 200
        memory = 512
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "flaresolverr"
      port = "8191"
      
      check {
        type     = "http"
        name     = "flaresolverr-health"
        path     = "/health"
        interval = "30s"
        timeout  = "15s"
      }

      tags = [
        "proxy",
        "flaresolverr",
        "traefik.enable=true",
        "traefik.http.routers.flaresolverr.middlewares=nginx-auth@file",
        "traefik.http.routers.flaresolverr.rule=Host(`flaresolverr.${var.domain}`) || Host(`flaresolverr.${var.duckdns_subdomain}.duckdns.org`) || Host(`flaresolverr.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.services.flaresolverr.loadbalancer.server.port=${var.flaresolverr_port}",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "flaresolverr" {
      driver = "docker"

      config {
        image = "ghcr.io/flaresolverr/flaresolverr:latest"
        hostname = "flaresolverr"
        network_mode = "publicnet"

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }

        logging {
          driver = "local"
          options = {
            max-file = "5"
            max-size = "10m"
          }
        }
      }

      env {
        TZ = "${var.tz}"
        PUID = "${var.puid}"
        PGID = "${var.pgid}"
        UMASK = "${var.umask}"
        LOG_LEVEL = "${var.flaresolverr_log_level}"
        LOG_HTML = "${var.flaresolverr_log_html}"
        CAPTCHA_SOLVER = "${var.flaresolverr_captcha_solver}"
        PORT = "${var.flaresolverr_port}"
        HOST = "${var.flaresolverr_host}"
        HEADLESS = "${var.flaresolverr_headless}"
        BROWSER_TIMEOUT = "${var.flaresolverr_browser_timeout}"
        TEST_URL = "${var.flaresolverr_test_url}"
        PROMETHEUS_ENABLED = "${var.flaresolverr_prometheus_enabled}"
        PROMETHEUS_PORT = "${var.prometheus_port}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    service {
      name = "whoami"
      port = "80"

      tags = [
        "test",
        "whoami",
        "traefik.enable=true",
        "traefik.http.routers.whoami-nginx.middlewares=nginx-auth@file",
        "traefik.http.routers.whoami-nginx.rule=Host(`whoami-nginx.${var.domain}`) || Host(`whoami-nginx.${var.duckdns_subdomain}.duckdns.org`) || Host(`whoami-nginx.${var.ts_hostname}.duckdns.org`)",
        "traefik.http.routers.whoami.rule=Host(`whoami.${var.domain}`) || Host(`whoami.${var.duckdns_subdomain}.duckdns.org`) || Host(`whoami.${var.ts_hostname}.duckdns.org`)",
        "homepage.group=Web Services",
        "homepage.name=Whoami",
        "homepage.icon=whoami.png",
        "homepage.href=https://whoami-nginx.${var.domain}",
        "homepage.description=Whoami service with multiple auth examples",
        "deunhealth.restart.on.unhealthy=true"
      ]
    }

    task "whoami" {
      driver = "docker"

      config {
        image = "traefik/whoami:latest"
        hostname = "whoami"
        network_mode = "publicnet"

        extra_hosts = [
          "host.docker.internal:host-gateway",
          "boden-iphone:100.97.148.14",
          "beatapostapita:100.99.45.35",
          "micklethefickle:100.72.149.123",
          "wizard:100.119.187.62",
          "warp:${var.warp_ipv4_address}",
          "mongodb:${var.mongodb_ipv4_address}",
          "redis:${var.redis_ipv4_address}",
          "traefik:${var.traefik_ipv4_address}"
        ]

        labels = {
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      resources {
        cpu    = 50
        memory = 64
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }
} 