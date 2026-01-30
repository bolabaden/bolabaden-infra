job "media-stack-security-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 70

  group "security-authentication" {
    count = 1

    network {
      mode = "bridge"
      port "tinyauth" {
        to = 3000
      }
      port "nginx_auth" {
        to = 80
      }
      port "vaultwarden" {
        to = 80
      }
      port "authelia" {
        to = 9091
      }
      port "crowdsec_metrics" {
        to = 6060
      }
      port "crowdsec_api" {
        to = 8080
      }
      port "headscale_http" {
        to = 8080
      }
      port "headscale_grpc" {
        to = 50443
      }
      port "headscale_stun" {
        to = 3478
      }
    }

    task "tinyauth" {
      driver = "docker"

      config {
        image = "ghcr.io/steveiliop56/tinyauth:v3"
        hostname = "auth"
        ports = ["tinyauth"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/tinyauth:/data"
        ]
      }

      env {
        SECRET = "${NOMAD_META_TINYAUTH_SECRET}"
        APP_URL = "${NOMAD_META_TINYAUTH_APP_URL}"
        USERS = "${NOMAD_META_TINYAUTH_USERS}"
        GOOGLE_CLIENT_ID = "${NOMAD_META_TINYAUTH_GOOGLE_CLIENT_ID}"
        GOOGLE_CLIENT_SECRET = "${NOMAD_META_TINYAUTH_GOOGLE_CLIENT_SECRET}"
        GITHUB_CLIENT_ID = "${NOMAD_META_TINYAUTH_GITHUB_CLIENT_ID}"
        GITHUB_CLIENT_SECRET = "${NOMAD_META_TINYAUTH_GITHUB_CLIENT_SECRET}"
        SESSION_EXPIRY = "${NOMAD_META_TINYAUTH_SESSION_EXPIRY}"
        COOKIE_SECURE = "${NOMAD_META_TINYAUTH_COOKIE_SECURE}"
        APP_TITLE = "${NOMAD_META_TINYAUTH_APP_TITLE}"
        LOGIN_MAX_RETRIES = "${NOMAD_META_TINYAUTH_LOGIN_MAX_RETRIES}"
        LOGIN_TIMEOUT = "${NOMAD_META_TINYAUTH_LOGIN_TIMEOUT}"
        OAUTH_AUTO_REDIRECT = "${NOMAD_META_TINYAUTH_OAUTH_AUTO_REDIRECT}"
        OAUTH_WHITELIST = "${NOMAD_META_TINYAUTH_OAUTH_WHITELIST}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "tinyauth"
        port = "tinyauth"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tinyauth.rule=Host(`auth.${NOMAD_META_DOMAIN}`) || Host(`auth.${NOMAD_META_SECOND_DOMAIN}`) || Host(`auth.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`auth.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.middlewares.tinyauth.forwardauth.address=http://auth:3000/api/auth/traefik",
          "homepage.group=Security",
          "homepage.name=TinyAuth",
          "homepage.icon=shield-lock.png",
          "homepage.href=https://auth.${NOMAD_META_DOMAIN}/",
          "homepage.description=Authentication service for securing your applications"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "nginx-auth" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        hostname = "nginx-auth"
        ports = ["nginx_auth"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/nginx-middlewares/nginx.conf:/etc/nginx/nginx.conf:ro",
          "${NOMAD_META_CONFIG_PATH}/nginx-middlewares/auth:/etc/nginx/auth:ro"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "nginx-auth"
        port = "nginx_auth"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.nginx-auth.rule=Host(`nginx-auth.${NOMAD_META_DOMAIN}`) || Host(`nginx-auth.${NOMAD_META_SECOND_DOMAIN}`) || Host(`nginx-auth.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`nginx-auth.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.nginx-auth.loadbalancer.server.port=80",
          "traefik.http.middlewares.nginx-auth.forwardauth.address=http://nginx-auth:80/auth",
          "traefik.http.middlewares.nginx-auth.forwardauth.trustForwardHeader=true",
          "traefik.http.middlewares.nginx-auth.forwardauth.authResponseHeaders=X-Auth-Method,X-Auth-Passed,X-Middleware-Name"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "crowdsec" {
      driver = "docker"

      config {
        image = "docker.io/crowdsecurity/crowdsec:latest"
        hostname = "crowdsec"
        ports = ["crowdsec_metrics", "crowdsec_api"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/crowdsec/data:/var/lib/crowdsec/data",
          "${NOMAD_META_CONFIG_PATH}/crowdsec/etc/crowdsec:/etc/crowdsec",
          "${NOMAD_META_CONFIG_PATH}/crowdsec/plugins:/usr/local/lib/crowdsec/plugins/",
          "${NOMAD_META_CONFIG_PATH}/crowdsec/logs:/var/log"
        ]
      }

      env {
        CONFIG_FILE = "${NOMAD_META_CROWDSEC_CONFIG_FILE}"
        DISABLE_AGENT = "${NOMAD_META_CROWDSEC_DISABLE_AGENT}"
        DISABLE_LOCAL_API = "${NOMAD_META_CROWDSEC_DISABLE_LOCAL_API}"
        DISABLE_ONLINE_API = "${NOMAD_META_CROWDSEC_DISABLE_ONLINE_API}"
        TEST_MODE = "${NOMAD_META_CROWDSEC_TEST_MODE}"
        LOCAL_API_URL = "${NOMAD_META_CROWDSEC_LOCAL_API_URL}"
        PLUGIN_DIR = "${NOMAD_META_CROWDSEC_PLUGIN_DIR}"
        METRICS_PORT = "${NOMAD_META_CROWDSEC_METRICS_PORT}"
        USE_WAL = "${NOMAD_META_CROWDSEC_USE_WAL}"
        CUSTOM_HOSTNAME = "${NOMAD_META_CROWDSEC_CUSTOM_HOSTNAME}"
        CAPI_WHITELISTS_PATH = "${NOMAD_META_CROWDSEC_CAPI_WHITELISTS_PATH}"
        TYPE = "${NOMAD_META_CROWDSEC_TYPE}"
        DSN = "${NOMAD_META_CROWDSEC_DSN}"
        BOUNCER_KEY_TRAEFIK = "${NOMAD_META_CROWDSEC_BOUNCER_API_KEY}"
        ENROLL_KEY = "${NOMAD_META_CROWDSEC_ENROLL_KEY}"
        ENROLL_INSTANCE_NAME = "${NOMAD_META_CROWDSEC_ENROLL_INSTANCE_NAME}"
        ENROLL_TAGS = "${NOMAD_META_CROWDSEC_ENROLL_TAGS}"
        AGENT_USERNAME = "${NOMAD_META_CROWDSEC_AGENT_USERNAME}"
        AGENT_PASSWORD = "${NOMAD_META_CROWDSEC_AGENT_PASSWORD}"
        USE_TLS = "${NOMAD_META_CROWDSEC_USE_TLS}"
        CACERT_FILE = "${NOMAD_META_CROWDSEC_CACERT_FILE}"
        INSECURE_SKIP_VERIFY = "${NOMAD_META_CROWDSEC_INSECURE_SKIP_VERIFY}"
        LAPI_CERT_FILE = "${NOMAD_META_CROWDSEC_LAPI_CERT_FILE}"
        LAPI_KEY_FILE = "${NOMAD_META_CROWDSEC_LAPI_KEY_FILE}"
        CLIENT_CERT_FILE = "${NOMAD_META_CROWDSEC_CLIENT_CERT_FILE}"
        CLIENT_KEY_FILE = "${NOMAD_META_CROWDSEC_CLIENT_KEY_FILE}"
        AGENTS_ALLOWED_OU = "${NOMAD_META_CROWDSEC_AGENTS_ALLOWED_OU}"
        BOUNCERS_ALLOWED_OU = "${NOMAD_META_CROWDSEC_BOUNCERS_ALLOWED_OU}"
        NO_HUB_UPGRADE = "${NOMAD_META_CROWDSEC_NO_HUB_UPGRADE}"
        COLLECTIONS = "${NOMAD_META_CROWDSEC_COLLECTIONS}"
        PARSERS = "${NOMAD_META_CROWDSEC_PARSERS}"
        SCENARIOS = "${NOMAD_META_CROWDSEC_SCENARIOS}"
        POSTOVERFLOWS = "${NOMAD_META_CROWDSEC_POSTOVERFLOWS}"
        CONTEXTS = "${NOMAD_META_CROWDSEC_CONTEXTS}"
        APPSEC_CONFIGS = "${NOMAD_META_CROWDSEC_APPSEC_CONFIGS}"
        APPSEC_RULES = "${NOMAD_META_CROWDSEC_APPSEC_RULES}"
        DISABLE_COLLECTIONS = "${NOMAD_META_CROWDSEC_DISABLE_COLLECTIONS}"
        DISABLE_PARSERS = "${NOMAD_META_CROWDSEC_DISABLE_PARSERS}"
        DISABLE_SCENARIOS = "${NOMAD_META_CROWDSEC_DISABLE_SCENARIOS}"
        DISABLE_POSTOVERFLOWS = "${NOMAD_META_CROWDSEC_DISABLE_POSTOVERFLOWS}"
        DISABLE_CONTEXTS = "${NOMAD_META_CROWDSEC_DISABLE_CONTEXTS}"
        DISABLE_APPSEC_CONFIGS = "${NOMAD_META_CROWDSEC_DISABLE_APPSEC_CONFIGS}"
        DISABLE_APPSEC_RULES = "${NOMAD_META_CROWDSEC_DISABLE_APPSEC_RULES}"
        LEVEL_FATAL = "${NOMAD_META_CROWDSEC_LEVEL_FATAL}"
        LEVEL_ERROR = "${NOMAD_META_CROWDSEC_LEVEL_ERROR}"
        LEVEL_WARN = "${NOMAD_META_CROWDSEC_LEVEL_WARN}"
        LEVEL_INFO = "${NOMAD_META_CROWDSEC_LEVEL_INFO}"
        LEVEL_DEBUG = "${NOMAD_META_CROWDSEC_LEVEL_DEBUG}"
        LEVEL_TRACE = "${NOMAD_META_CROWDSEC_LEVEL_TRACE}"
        CI_TESTING = "${NOMAD_META_CROWDSEC_CI_TESTING}"
        DEBUG = "${NOMAD_META_CROWDSEC_DEBUG}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "crowdsec"
        port = "crowdsec_api"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.crowdsec.middlewares=nginx-auth@file",
          "traefik.http.routers.crowdsec.rule=Host(`crowdsec.${NOMAD_META_DOMAIN}`) || Host(`crowdsec.${NOMAD_META_SECOND_DOMAIN}`) || Host(`crowdsec.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`crowdsec.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.crowdsec.loadbalancer.server.port=8080",
          "homepage.group=Security",
          "homepage.name=Crowdsec",
          "homepage.icon=crowdsec.png",
          "homepage.href=https://crowdsec.${NOMAD_META_DOMAIN}/",
          "homepage.description=CrowdSec is an open-source, behavioral, intrusion detection system.",
          "homepage.widget.type=crowdsec",
          "homepage.widget.url=http://crowdsec:8080",
          "homepage.widget.username=${NOMAD_META_CROWDSEC_AGENT_USERNAME}",
          "homepage.widget.password=${NOMAD_META_CROWDSEC_AGENT_PASSWORD}"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "headscale" {
      driver = "docker"

      config {
        image = "docker.io/headscale/headscale:latest"
        hostname = "headscale"
        ports = ["headscale_http", "headscale_grpc", "headscale_stun"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/headscale/config:/etc/headscale",
          "${NOMAD_META_CONFIG_PATH}/headscale/lib:/var/lib/headscale",
          "${NOMAD_META_CONFIG_PATH}/headscale/run:/var/run/headscale"
        ]
        command = "serve"
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "headscale"
        port = "headscale_http"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.headscale.rule=Host(`headscale.${NOMAD_META_DOMAIN}`) || Host(`headscale.${NOMAD_META_SECOND_DOMAIN}`) || Host(`headscale.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`headscale.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.headscale.loadbalancer.server.port=8080",
          "traefik.http.routers.headscale-admin.rule=Host(`headscale-admin.${NOMAD_META_DOMAIN}`) || Host(`headscale-admin.${NOMAD_META_SECOND_DOMAIN}`) || Host(`headscale-admin.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`headscale-admin.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.headscale-admin.loadbalancer.server.port=9090",
          "homepage.group=Networking",
          "homepage.name=Headscale",
          "homepage.icon=headscale.png",
          "homepage.href=https://headscale.${NOMAD_META_DOMAIN}/",
          "homepage.description=Headscale is a server that manages your Tailscale network."
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "monitoring" {
    count = 1

    network {
      mode = "bridge"
      port "uptime_kuma" {
        to = 3001
      }
      port "portainer" {
        to = 9000
      }
      port "beszel" {
        to = 8090
      }
      port "gatus" {
        to = 8080
      }
    }

    task "uptime-kuma" {
      driver = "docker"

      config {
        image = "louislam/uptime-kuma:latest"
        hostname = "kuma"
        ports = ["uptime_kuma"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/uptime-kuma:/app/data",
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "uptime-kuma"
        port = "uptime_kuma"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.uptime-kuma.middlewares=nginx-auth@file",
          "traefik.http.routers.uptime-kuma.rule=Host(`uptime.${NOMAD_META_DOMAIN}`) || Host(`uptime.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`uptime.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.uptime-kuma.loadbalancer.server.port=3001",
          "homepage.group=Monitoring",
          "homepage.name=Uptime Kuma",
          "homepage.icon=uptime-kuma.png",
          "homepage.href=https://uptime.${NOMAD_META_DOMAIN}/",
          "homepage.description=Self-hosted uptime monitoring tool"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "portainer" {
      driver = "docker"

      config {
        image = "portainer/portainer-ce:latest"
        hostname = "portainer"
        ports = ["portainer"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "${NOMAD_META_CONFIG_PATH}/portainer:/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "portainer"
        port = "portainer"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.portainer.middlewares=nginx-auth@file",
          "traefik.http.routers.portainer.rule=Host(`portainer.${NOMAD_META_DOMAIN}`) || Host(`portainer.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`portainer.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.portainer.loadbalancer.server.port=9000",
          "homepage.group=Management",
          "homepage.name=Portainer",
          "homepage.icon=portainer.png",
          "homepage.href=https://portainer.${NOMAD_META_DOMAIN}/",
          "homepage.description=Docker container management interface"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "beszel" {
      driver = "docker"

      config {
        image = "henrygd/beszel"
        hostname = "beszel"
        ports = ["beszel"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/beszel:/beszel"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "beszel"
        port = "beszel"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.beszel.middlewares=nginx-auth@file",
          "traefik.http.routers.beszel.rule=Host(`beszel.${NOMAD_META_DOMAIN}`) || Host(`beszel.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`beszel.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.beszel.loadbalancer.server.port=8090",
          "homepage.group=Monitoring",
          "homepage.name=Beszel",
          "homepage.icon=beszel.png",
          "homepage.href=https://beszel.${NOMAD_META_DOMAIN}/",
          "homepage.description=Lightweight server monitoring dashboard"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "gatus" {
      driver = "docker"

      config {
        image = "twin/gatus:latest"
        hostname = "gatus"
        ports = ["gatus"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/gatus:/config",
          "${NOMAD_META_CONFIG_PATH}/gatus/data:/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "gatus"
        port = "gatus"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.gatus.middlewares=nginx-auth@file",
          "traefik.http.routers.gatus.rule=Host(`gatus.${NOMAD_META_DOMAIN}`) || Host(`gatus.${NOMAD_META_SECOND_DOMAIN}`) || Host(`gatus.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`gatus.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.gatus.loadbalancer.server.port=8080",
          "homepage.group=Monitoring",
          "homepage.name=Gatus",
          "homepage.icon=gatus.png",
          "homepage.href=https://gatus.${NOMAD_META_DOMAIN}/",
          "homepage.description=Automated health checking and status page"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "security-extras" {
    count = 1
    
    network {
      mode = "bridge"
      port "decluttarr" {
        to = 80
      }
    }

    task "decluttarr" {
      driver = "docker"

      config {
        image = "ghcr.io/manimatter/decluttarr"
        hostname = "decluttarr"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/decluttarr:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        FAILED_IMPORT_MESSAGE_PATTERNS = "['Not a Custom Format upgrade for existing', 'Not an upgrade for existing']"
        IGNORED_DOWNLOAD_CLIENTS = "['emulerr']"
        LIDARR_KEY = "${NOMAD_META_LIDARR_API_KEY}"
        LIDARR_URL = "http://lidarr:${NOMAD_META_LIDARR_PORT}"
        LOG_LEVEL = "${NOMAD_META_DECLUTTARR_LOG_LEVEL}"
        MIN_DOWNLOAD_SPEED = "${NOMAD_META_DECLUTTARR_MIN_DOWNLOAD_SPEED}"
        NO_STALLED_REMOVAL_QBIT_TAG = "${NOMAD_META_DECLUTTARR_NO_STALLED_REMOVAL_QBIT_TAG}"
        PERMITTED_ATTEMPTS = "${NOMAD_META_DECLUTTARR_PERMITTED_ATTEMPTS}"
        QBITTORRENT_PASSWORD = "${NOMAD_META_QBITTORRENT_PASSWORD}"
        QBITTORRENT_URL = "https://qbittorrent.${NOMAD_META_DOMAIN}"
        QBITTORRENT_USERNAME = "${NOMAD_META_QBITTORRENT_USERNAME}"
        RADARR_KEY = "${NOMAD_META_RADARR_API_KEY}"
        RADARR_URL = "${NOMAD_META_RADARR_INTERNAL_URL}"
        READARR_KEY = "${NOMAD_META_READARR_API_KEY}"
        READARR_URL = "${NOMAD_META_READARR_INTERNAL_URL}"
        REMOVE_FAILED_IMPORTS = "${NOMAD_META_DECLUTTARR_REMOVE_FAILED_IMPORTS}"
        REMOVE_FAILED = "${NOMAD_META_DECLUTTARR_REMOVE_FAILED}"
        REMOVE_METADATA_MISSING = "${NOMAD_META_DECLUTTARR_REMOVE_METADATA_MISSING}"
        REMOVE_MISSING_FILES = "${NOMAD_META_DECLUTTARR_REMOVE_MISSING_FILES}"
        REMOVE_ORPHANS = "${NOMAD_META_DECLUTTARR_REMOVE_ORPHANS}"
        REMOVE_SLOW = "${NOMAD_META_DECLUTTARR_REMOVE_SLOW}"
        REMOVE_STALLED = "${NOMAD_META_DECLUTTARR_REMOVE_STALLED}"
        REMOVE_TIMER = "${NOMAD_META_DECLUTTARR_REMOVE_TIMER}"
        REMOVE_UNMONITORED = "${NOMAD_META_DECLUTTARR_REMOVE_UNMONITORED}"
        SONARR_KEY = "${NOMAD_META_SONARR_API_KEY}"
        SONARR_URL = "${NOMAD_META_SONARR_INTERNAL_URL}"
        SSL_VERIFICATION = "${NOMAD_META_DECLUTTARR_SSL_VERIFICATION}"
        TEST_RUN = "${NOMAD_META_DECLUTTARR_TEST_RUN}"
        WHISPARR_KEY = "${NOMAD_META_WHISPARR_API_KEY}"
        WHISPARR_URL = "${NOMAD_META_WHISPARR_INTERNAL_URL}"
        RUN_PERIODIC_RESCANS = jsonencode({
          RADARR = {
            MISSING = true,
            CUTOFF_UNMET = true,
            MAX_CONCURRENT_SCANS = 3,
            MIN_DAYS_BEFORE_RESCAN = 1
          },
          SONARR = {
            MISSING = true,
            CUTOFF_UNMET = true,
            MAX_CONCURRENT_SCANS = 3,
            MIN_DAYS_BEFORE_RESCAN = 1
          }
        })
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "decluttarr"
        port = "decluttarr"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.decluttarr.middlewares=nginx-auth@file",
          "traefik.http.routers.decluttarr.rule=Host(`decluttarr.${NOMAD_META_DOMAIN}`) || Host(`decluttarr.${NOMAD_META_SECOND_DOMAIN}`) || Host(`decluttarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`decluttarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.decluttarr.loadbalancer.server.port=80"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  # Variable definitions
  meta {
    TZ = "America/Chicago"
    PUID = "1002"
    PGID = "988"
    UMASK = "002"
    CONFIG_PATH = "./configs"
    DOMAIN = "example.com"
    SECOND_DOMAIN = "bocloud.org"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"

    TINYAUTH_SECRET = ""
    TINYAUTH_APP_URL = "https://auth.example.com"
    TINYAUTH_USERS = ""
    TINYAUTH_GOOGLE_CLIENT_ID = ""
    TINYAUTH_GOOGLE_CLIENT_SECRET = ""
    TINYAUTH_GITHUB_CLIENT_ID = ""
    TINYAUTH_GITHUB_CLIENT_SECRET = ""
    TINYAUTH_SESSION_EXPIRY = "604800"
    TINYAUTH_COOKIE_SECURE = "true"
    TINYAUTH_APP_TITLE = "Bolabaden"
    TINYAUTH_LOGIN_MAX_RETRIES = "15"
    TINYAUTH_LOGIN_TIMEOUT = "300"
    TINYAUTH_OAUTH_AUTO_REDIRECT = "none"
    TINYAUTH_OAUTH_WHITELIST = "boden.crouch@gmail.com,halomastar@gmail.com,athenajaguiar@gmail.com,bolabaden.duckdns@gmail.com,dgorsch2@gmail.com,dgorsch4@gmail.com"

    CROWDSEC_CONFIG_FILE = "/etc/crowdsec/config.yaml"
    CROWDSEC_DISABLE_AGENT = "false"
    CROWDSEC_DISABLE_LOCAL_API = "false"
    CROWDSEC_DISABLE_ONLINE_API = "false"
    CROWDSEC_TEST_MODE = "false"
    CROWDSEC_LOCAL_API_URL = "http://0.0.0.0:8080"
    CROWDSEC_PLUGIN_DIR = "/usr/local/lib/crowdsec/plugins/"
    CROWDSEC_METRICS_PORT = "6060"
    CROWDSEC_USE_WAL = "false"
    CROWDSEC_CUSTOM_HOSTNAME = "localhost"
    CROWDSEC_CAPI_WHITELISTS_PATH = ""
    CROWDSEC_TYPE = ""
    CROWDSEC_DSN = ""
    CROWDSEC_BOUNCER_API_KEY = ""
    CROWDSEC_ENROLL_KEY = ""
    CROWDSEC_ENROLL_INSTANCE_NAME = ""
    CROWDSEC_ENROLL_TAGS = ""
    CROWDSEC_AGENT_USERNAME = ""
    CROWDSEC_AGENT_PASSWORD = ""
    CROWDSEC_USE_TLS = "false"
    CROWDSEC_CACERT_FILE = ""
    CROWDSEC_INSECURE_SKIP_VERIFY = ""
    CROWDSEC_LAPI_CERT_FILE = ""
    CROWDSEC_LAPI_KEY_FILE = ""
    CROWDSEC_CLIENT_CERT_FILE = ""
    CROWDSEC_CLIENT_KEY_FILE = ""
    CROWDSEC_AGENTS_ALLOWED_OU = "agent-ou"
    CROWDSEC_BOUNCERS_ALLOWED_OU = "bouncer-ou"
    CROWDSEC_NO_HUB_UPGRADE = "false"
    CROWDSEC_COLLECTIONS = "crowdsecurity/traefik"
    CROWDSEC_PARSERS = ""
    CROWDSEC_SCENARIOS = ""
    CROWDSEC_POSTOVERFLOWS = ""
    CROWDSEC_CONTEXTS = ""
    CROWDSEC_APPSEC_CONFIGS = ""
    CROWDSEC_APPSEC_RULES = ""
    CROWDSEC_DISABLE_COLLECTIONS = ""
    CROWDSEC_DISABLE_PARSERS = ""
    CROWDSEC_DISABLE_SCENARIOS = ""
    CROWDSEC_DISABLE_POSTOVERFLOWS = ""
    CROWDSEC_DISABLE_CONTEXTS = ""
    CROWDSEC_DISABLE_APPSEC_CONFIGS = ""
    CROWDSEC_DISABLE_APPSEC_RULES = ""
    CROWDSEC_LEVEL_FATAL = "false"
    CROWDSEC_LEVEL_ERROR = "false"
    CROWDSEC_LEVEL_WARN = "false"
    CROWDSEC_LEVEL_INFO = "false"
    CROWDSEC_LEVEL_DEBUG = "false"
    CROWDSEC_LEVEL_TRACE = "false"
    CROWDSEC_CI_TESTING = "false"
    CROWDSEC_DEBUG = "false"

    LIDARR_API_KEY = ""
    LIDARR_PORT = "8686"
    DECLUTTARR_LOG_LEVEL = "VERBOSE"
    DECLUTTARR_MIN_DOWNLOAD_SPEED = "100"
    DECLUTTARR_NO_STALLED_REMOVAL_QBIT_TAG = "Don't Kill"
    DECLUTTARR_PERMITTED_ATTEMPTS = "3"
    QBITTORRENT_PASSWORD = ""
    QBITTORRENT_USERNAME = ""
    RADARR_API_KEY = ""
    RADARR_INTERNAL_URL = ""
    READARR_API_KEY = ""
    READARR_INTERNAL_URL = ""
    DECLUTTARR_REMOVE_FAILED_IMPORTS = "true"
    DECLUTTARR_REMOVE_FAILED = "false"
    DECLUTTARR_REMOVE_METADATA_MISSING = "false"
    DECLUTTARR_REMOVE_MISSING_FILES = "false"
    DECLUTTARR_REMOVE_ORPHANS = "true"
    DECLUTTARR_REMOVE_SLOW = "true"
    DECLUTTARR_REMOVE_STALLED = "true"
    DECLUTTARR_REMOVE_TIMER = "10"
    DECLUTTARR_REMOVE_UNMONITORED = "false"
    SONARR_API_KEY = ""
    SONARR_INTERNAL_URL = ""
    DECLUTTARR_SSL_VERIFICATION = "false"
    DECLUTTARR_TEST_RUN = "false"
    WHISPARR_API_KEY = ""
    WHISPARR_INTERNAL_URL = ""
  }
} 