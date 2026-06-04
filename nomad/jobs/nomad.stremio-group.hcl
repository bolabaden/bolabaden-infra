# Nomad job equivalent to compose/docker-compose.stremio-group.yml
# Extracted from nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "docker-compose.stremio-group" {
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

  group "stremio-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "stremio_webui" { to = 8080 }
      port "stremio_http" {
        static = 11470
        to = 11470
      }
      port "stremio_https" {
        static = 12470
        to = 12470
      }
    }

    # Stream Movies/TV over debrid instantly.
    task "stremio" {
      driver = "docker"

      config {
        image = "ghcr.io/tsaridas/stremio-docker:main"
        ports = ["stremio_webui", "stremio_http", "stremio_https"]
        volumes = [
          "${var.config_path}/stremio/root/.stremio-server:/root/.stremio-server"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "stremio"
        }
      }

      env {
        IPADDRESS        = "127.0.0.1"
        AUTO_SERVER_URL  = "1"
        SERVER_URL       = "https://stremio.${var.domain}/"
        WEBUI_LOCATION   = "https://stremio.${var.domain}/shell/"
        NO_CORS          = "0"
        CASTING_DISABLED = "1"
      }

      resources {
        cpu        = 2000
        memory     = 2048
        memory_max = 0
      
      }

      service {

        name = "stremio"
        port = "stremio_webui"
        tags = [
          "stremio",
          "${var.domain}",
          "traefik.enable=true",
          # Redirect stremio-web.$DOMAIN to stremio.$DOMAIN
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.regex=^(http|https)://stremio(-web)\\.(${var.domain}|${node.unique.name}\\.${var.domain})(.*)$$",
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.replacement=$$1://stremio.$$3$$4",
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.permanent=false",
          # Redirect stremio.$DOMAIN/shell-v4.4 to /shell
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.regex=^(http|https)://stremio\\.(${var.domain}|${node.unique.name}\\.${var.domain})(.*)$$",
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.replacement=$$1://stremio.$$2$$3",
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.permanent=false",
          # Redirect to add/replace streamingServer parameter for shell URLs
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.regex=^(http|https)://stremio\\.(${var.domain}|${node.unique.name}\\.${var.domain})(/shell[^#?]*)(\\\\?[^#]*?streamingServer=[^&#]*)?([^#]*)(#.*)?$$",
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.replacement=$$1://stremio.$$2$$3?streamingServer=https%3A%2F%2Fstremio.$$2$$5$$6",
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.permanent=false",
          # Stremio Web UI
          "traefik.http.routers.stremio.service=stremio",
          "traefik.http.routers.stremio.rule=Host(`stremio-web.${var.domain}`) || Host(`stremio-web.${node.unique.name}.${var.domain}`) || Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.stremio.middlewares=stremio-web-redirect@docker,stremio-shell-redirect@docker,stremio-streaming-server-redirect@docker",
          "traefik.http.services.stremio.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio.loadbalancer.server.port=8080",
          # Stremio HTTP Streaming Server (port 11470)
          "traefik.http.routers.stremio-http11470.service=stremio-http11470",
          "traefik.http.services.stremio-http11470.loadbalancer.server.scheme=http",
          "traefik.http.services.stremio-http11470.loadbalancer.server.port=11470",
          # Stremio API/streaming routes to 11470
          "traefik.http.routers.stremio-http11470.rule=(Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)) && ( PathPrefix(`/hlsv2`) || PathPrefix(`/casting`) || PathPrefix(`/local-addon`) || PathPrefix(`/proxy`) || PathPrefix(`/rar`) || PathPrefix(`/zip`) || PathPrefix(`/settings`) || PathPrefix(`/create`) || PathPrefix(`/removeAll`) || PathPrefix(`/samples`) || PathPrefix(`/probe`) || PathPrefix(`/subtitlesTracks`) || PathPrefix(`/opensubHash`) || PathPrefix(`/subtitles`) || PathPrefix(`/network-info`) || PathPrefix(`/device-info`) || PathPrefix(`/get-https`) || PathPrefix(`/hwaccel-profiler`) || PathPrefix(`/status`) || PathPrefix(`/exec`) || PathPrefix(`/stream`) || PathRegexp(`^/[^/]+/(stats\\\\.json|create|remove|destroy)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stats\\\\.json|hls\\\\.m3u8|master\\\\.m3u8|stream\\\\.m3u8|dlna|thumb\\\\.jpg)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+\\\\.m3u8|stream-[^/]+\\\\.m3u8|subs-[^/]+\\\\.m3u8)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+|stream-[^/]+)/[^/]+\\\\.(ts|mp4)$$`) || PathRegexp(`^/yt/[^/]+(\\\\.json)?$$`) || Path(`/thumb.jpg`) || Path(`/stats.json`) )",
          # Stremio HTTPS Streaming Server (port 12470)
          "traefik.http.routers.stremio-https12470.service=stremio-https12470",
          "traefik.http.services.stremio-https12470.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio-https12470.loadbalancer.server.port=12470",
          # Stremio API/streaming routes to 12470
          "traefik.http.routers.stremio-https12470.rule=(Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)) && ( PathPrefix(`/hlsv2`) || PathPrefix(`/casting`) || PathPrefix(`/local-addon`) || PathPrefix(`/proxy`) || PathPrefix(`/rar`) || PathPrefix(`/zip`) || PathPrefix(`/settings`) || PathPrefix(`/create`) || PathPrefix(`/removeAll`) || PathPrefix(`/samples`) || PathPrefix(`/probe`) || PathPrefix(`/subtitlesTracks`) || PathPrefix(`/opensubHash`) || PathPrefix(`/subtitles`) || PathPrefix(`/network-info`) || PathPrefix(`/device-info`) || PathPrefix(`/get-https`) || PathPrefix(`/hwaccel-profiler`) || PathPrefix(`/status`) || PathPrefix(`/exec`) || PathPrefix(`/stream`) || PathRegexp(`^/[^/]+/(stats\\\\.json|create|remove|destroy)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stats\\\\.json|hls\\\\.m3u8|master\\\\.m3u8|stream\\\\.m3u8|dlna|thumb\\\\.jpg)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+\\\\.m3u8|stream-[^/]+\\\\.m3u8|subs-[^/]+\\\\.m3u8)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+|stream-[^/]+)/[^/]+\\\\.(ts|mp4)$$`) || PathRegexp(`^/yt/[^/]+(\\\\.json)?$$`) || Path(`/thumb.jpg`) || Path(`/stats.json`) )",
          "homepage.group=Media Streaming Platforms",
          "homepage.name=Stremio",
          "homepage.icon=stremio.png",
          "homepage.href=https://stremio.${var.domain}/",
          "homepage.description=A one-stop hub for video content aggregation, allowing you to stream movies, series, and more from various sources",
          "kuma.stremio.http.name=stremio.${node.unique.name}.${var.domain}",
          "kuma.stremio.http.url=https://stremio.${var.domain}",
          "kuma.stremio.http.interval=60"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "command -v curl >/dev/null || (apk add --no-cache curl >/dev/null 2>&1 || apt-get update >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1); (curl -fs http://127.0.0.1:11470/ >/dev/null 2>&1 || curl -fsk https://127.0.0.1:12470/ >/dev/null 2>&1) || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "aiostreams-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "aiostreams" { to = 3000 }
    }

    # 🔹🔹 AIOStreams 🔹🔹
    task "aiostreams" {
      driver = "docker"

      config {
        image = "ghcr.io/viren070/aiostreams:v2.12.2"
        ports = ["aiostreams"]
        volumes = [
          "${var.config_path}/stremio/addons/aiostreams/data:/app/data",
          "${var.root_path}/secrets:/run/secrets-src:ro"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /run/secrets && for f in /run/secrets-src/*.txt; do ln -sf \"$$f\" \"/run/secrets/$$(basename \"$$f\" .txt)\" 2>/dev/null || true; done && exec node /app/dist/index.js"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "aiostreams"
        }
      }

      template {
        data = <<EOF
# ==============================================================================
#                         ESSENTIAL ADDON SETUP
# ==============================================================================
TZ=${var.tz}
PUID=${var.puid}
PGID=988
UMASK=${var.umask}

# --- Addon Identification ---
ADDON_NAME={{ env "AIOSTREAMS_ADDON_NAME" | or "BadenAIO" }}
ADDON_ID=aiostreams.${var.domain}

# --- Network Configuration ---
PORT={{ env "AIOSTREAMS_PORT" | or "3000" }}
BASE_URL=https://aiostreams.${var.domain}

# --- Security ---
SECRET_KEY=${var.aiostreams_secret_key}
ADDON_PASSWORD=${var.aiostreams_addon_password}

# --- Database ---
DATABASE_URI=sqlite://./data/db.sqlite

# ==============================================================================
#                     BUILT-IN ADDON CONFIGURATION
# ==============================================================================
BUILTIN_STREMTHRU_URL=https://stremthru.13377001.xyz
BUILTIN_DEBRID_INSTANT_AVAILABILITY_CACHE_TTL=1800
BUILTIN_DEBRID_PLAYBACK_LINK_CACHE_TTL=3600
BUILTIN_GET_TORRENT_TIMEOUT=5000
BUILTIN_GET_TORRENT_CONCURRENCY=100
BUILTIN_PROWLARR_SEARCH_TIMEOUT={{ env "BUILTIN_PROWLARR_SEARCH_TIMEOUT" | or "" }}
BUILTIN_PROWLARR_SEARCH_CACHE_TTL=604800
BUILTIN_PROWLARR_INDEXERS_CACHE_TTL=1209600

# ==============================================================================
#                     DEBRID & OTHER SERVICE API KEYS
# ==============================================================================
TMDB_ACCESS_TOKEN_FILE=/run/secrets/tmdb-access-token
TMDB_API_KEY_FILE=/run/secrets/tmdb-api-key
TRAKT_CLIENT_ID={{ env "TRAKT_CLIENT_ID" | or "" }}

DEFAULT_REALDEBRID_API_KEY_FILE=/run/secrets/realdebrid-api-key
DEFAULT_ALLDEBRID_API_KEY_FILE=/run/secrets/alldebrid-api-key
DEFAULT_PREMIUMIZE_API_KEY_FILE=/run/secrets/premiumize-api-key
DEFAULT_DEBRIDLINK_API_KEY_FILE=/run/secrets/debridlink-api-key
DEFAULT_TORBOX_API_KEY_FILE=/run/secrets/torbox-api-key
DEFAULT_OFFCLOUD_API_KEY_FILE=/run/secrets/offcloud-api-key
DEFAULT_OFFCLOUD_EMAIL={{ env "OFFCLOUD_EMAIL" | or "" }}
DEFAULT_OFFCLOUD_PASSWORD_FILE=/run/secrets/offcloud-password

# ==============================================================================
#                           CACHE CONFIGURATION
# ==============================================================================
DEFAULT_MAX_CACHE_SIZE=100000
PROXY_IP_CACHE_TTL=900
MANIFEST_CACHE_TTL=300
SUBTITLE_CACHE_TTL=300
STREAM_CACHE_TTL=1
CATALOG_CACHE_TTL=300
META_CACHE_TTL=300
ADDON_CATALOG_CACHE_TTL=300
RPDB_API_KEY_VALIDITY_CACHE_TTL=604800

# ==============================================================================
#                             FEATURE CONTROL
# ==============================================================================
DISABLE_SELF_SCRAPING=true

# ==============================================================================
#                                 LOGGING
# ==============================================================================
LOG_LEVEL=info
LOG_FORMAT=text
LOG_SENSITIVE_INFO=true
LOG_TIMEZONE=Etc/UTC

# ==============================================================================
#                         INACTIVE USER PRUNING
# ==============================================================================
PRUNE_INTERVAL=86400
PRUNE_MAX_DAYS=-1

# ==============================================================================
#                      DEFAULT/FORCED STREAM PROXY (MediaFlow, StremThru)
# ==============================================================================
FORCE_PROXY_ENABLED=true
DEFAULT_PROXY_ID=stremthru
DEFAULT_PROXY_CREDENTIALS={{ env "STREMTHRU_CREDENTIALS" | or "bolabaden:duckdns" }}
FORCE_PROXY_DISABLE_PROXIED_ADDONS=false
ENCRYPT_MEDIAFLOW_URLS=true
ENCRYPT_STREMTHRU_URLS=true

# ==============================================================================
#                       ADVANCED CONFIGURATION & LIMITS
# ==============================================================================
DEFAULT_TIMEOUT=15000
MAX_ADDONS=100
MAX_GROUPS=50
MAX_KEYWORD_FILTERS=50
MAX_STREAM_EXPRESSION_FILTERS=200
MAX_TIMEOUT=50000
MIN_TIMEOUT=1000
PRECACHE_NEXT_EPISODE_MIN_INTERVAL=86400

# ==============================================================================
#                           RATE LIMIT CONFIGURATION
# ==============================================================================
DISABLE_RATE_LIMITS=false
STATIC_RATE_LIMIT_WINDOW=5
STATIC_RATE_LIMIT_MAX_REQUESTS=75
USER_API_RATE_LIMIT_WINDOW=5
USER_API_RATE_LIMIT_MAX_REQUESTS=5
STREAM_API_RATE_LIMIT_WINDOW=5
STREAM_API_RATE_LIMIT_MAX_REQUESTS=10
FORMAT_API_RATE_LIMIT_WINDOW=5
FORMAT_API_RATE_LIMIT_MAX_REQUESTS=30
CATALOG_API_RATE_LIMIT_WINDOW=5
CATALOG_API_RATE_LIMIT_MAX_REQUESTS=5
ANIME_API_RATE_LIMIT_WINDOW=60
ANIME_API_RATE_LIMIT_MAX_REQUESTS=120
STREMIO_STREAM_RATE_LIMIT_WINDOW=15
STREMIO_STREAM_RATE_LIMIT_MAX_REQUESTS=10
STREMIO_CATALOG_RATE_LIMIT_WINDOW=5
STREMIO_CATALOG_RATE_LIMIT_MAX_REQUESTS=30
STREMIO_MANIFEST_RATE_LIMIT_WINDOW=5
STREMIO_MANIFEST_RATE_LIMIT_MAX_REQUESTS=5
STREMIO_SUBTITLE_RATE_LIMIT_WINDOW=5
STREMIO_SUBTITLE_RATE_LIMIT_MAX_REQUESTS=10
STREMIO_META_RATE_LIMIT_WINDOW=5
STREMIO_META_RATE_LIMIT_MAX_REQUESTS=15

# Anime Database
ANIME_DB_LEVEL_OF_DETAIL=required
ANIME_DB_FRIBB_MAPPINGS_REFRESH_INTERVAL=86400000
ANIME_DB_MANAMI_DB_REFRESH_INTERVAL=604800000
ANIME_DB_KITSU_IMDB_MAPPING_REFRESH_INTERVAL=86400000
ANIME_DB_EXTENDED_ANITRAKT_MOVIES_REFRESH_INTERVAL=86400000
ANIME_DB_EXTENDED_ANITRAKT_TV_REFRESH_INTERVAL=86400000

# External Addon URLs
STREMTHRU_STORE_URL=https://stremthru.${var.domain}/stremio/store/
STREMTHRU_TORZ_URL=https://stremthru.${var.domain}/stremio/torz/
DEFAULT_JACKETTIO_INDEXERS='["animetosho", "anirena", "bitsearch", "eztv", "nyaasi", "thepiratebay", "therarbg", "yts"]'
EOF
        destination = "secrets/aiostreams.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "aiostreams"
        port = "aiostreams"
        tags = [
          "aiostreams",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.aiostreams.rule=Host(`aiostreams.${var.domain}`) || Host(`aiostreams.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.aiostreams.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=AIOStreams",
          "homepage.icon=aiostreams.png",
          "homepage.href=https://aiostreams.${var.domain}/",
          "homepage.description=Stremio add-on that aggregates multiple sources into a single unified stream catalog"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/manifest.json > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "stremthru-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "stremthru" { to = 8080 }
    }

    # 🔹🔹 StremThru 🔹🔹
    task "stremthru" {
      driver = "docker"

      config {
        image = "docker.io/muniftanjim/stremthru:latest"
        ports = ["stremthru"]
        volumes = [
          "${var.config_path}/stremio/addons/stremthru/app/data:/app/data"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "stremthru"
        }
      }

      template {
        data = <<EOF
TZ=${var.tz}
PUID=${var.puid}
PGID=988
UMASK=${var.umask}

# The base URL of the StremThru instance.
# Required for the StremThru Lists addon to work correctly with Trakt OAuth.
STREMTHRU_BASE_URL=https://stremthru.${var.domain}

# =============================
#     LOGGING CONFIGURATION
# ================================
STREMTHRU_LOG_LEVEL=INFO
STREMTHRU_LOG_FORMAT=text

# ============================
#       PROXY CONFIGURATION
# ================================
# A list of user credentials for the proxy. In a comma separated list of username:password pairs.
STREMTHRU_PROXY_AUTH=${var.stremthru_proxy_auth}

# A list of admin users. Should be a comma separated list of usernames.
STREMTHRU_AUTH_ADMIN=${var.main_username}

# A list of store credentials per user. In a comma separated list of username:store_name:store_token.
STREMTHRU_STORE_AUTH=${var.stremthru_store_auth}

# A list of proxy configurations per store.
STREMTHRU_STORE_CONTENT_PROXY=*:true,premiumize:false

# This is the maximum number of connections to the proxy per user.
STREMTHRU_CONTENT_PROXY_CONNECTION_LIMIT=*:10

# ============================================================
#                   INTEGRATION CONFIGURATION
# ============================================================
# Trakt.tv Integration
STREMTHRU_INTEGRATION_TRAKT_CLIENT_ID=${var.trakt_client_id}
STREMTHRU_INTEGRATION_TRAKT_CLIENT_SECRET=${var.trakt_client_secret}
STREMTHRU_INTEGRATION_TRAKT_LIST_STALE_TIME=12h

# TMDB Integration
STREMTHRU_INTEGRATION_TMDB_ACCESS_TOKEN=${var.tmdb_access_token}
STREMTHRU_INTEGRATION_TMDB_LIST_STALE_TIME=12h

# GitHub Integration
STREMTHRU_INTEGRATION_GITHUB_USER=th3w1zard1
STREMTHRU_INTEGRATION_GITHUB_TOKEN={{ env "GITHUB_TOKEN" | or "" }}

# ================================
#             OTHER
# ================================
STREMTHRU_STREMIO_TORZ_LAZY_PULL=true

# =============================
#      FEATURE CONFIGURATION
# ================================
STREMTHRU_FEATURE=+anime,-stremio_p2p

# =============================
#    DATABASE CONFIGURATION
# ================================
STREMTHRU_DATABASE_URI=sqlite://./data/stremthru.db
STREMTHRU_REDIS_URI=redis://${var.redis_hostname}:${var.redis_port}
EOF
        destination = "secrets/stremthru.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "stremthru"
        port = "stremthru"
        tags = [
          "stremthru",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.stremthru.rule=Host(`stremthru.${var.domain}`) || Host(`stremthru.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.stremthru.loadbalancer.server.port=8080",
          "homepage.group=Stremio Addons",
          "homepage.name=StremThru",
          "homepage.icon=stremthru.png",
          "homepage.href=https://stremthru.${var.domain}/",
          "homepage.description=Tunnel/proxy bridge for Debrid services to unify access of streaming links through a single host."
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "1m"
          timeout  = "5s"
        }
      }
    }
  }
  group "flaresolverr-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "flaresolverr" { to = 8191 }
    }

    # Headless anti-bot proxy to bypass Cloudflare/JS challenges for indexers and scrapers
    task "flaresolverr" {
      driver = "docker"

      config {
        image = "ghcr.io/flaresolverr/flaresolverr:latest"
        ports = ["flaresolverr"]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "flaresolverr"
        }
      }

      env {
        TZ                = var.tz
        PUID              = var.puid
        PGID              = "988"
        UMASK             = var.umask
        LOG_LEVEL         = "debug"
        LOG_HTML          = "false"
        CAPTCHA_SOLVER    = "none"
        PORT              = "8191"
        HOST              = "0.0.0.0"
        HEADLESS          = "true"
        BROWSER_TIMEOUT   = "120000"
        TEST_URL          = "https://www.google.com"
        PROMETHEUS_ENABLED = "true"
        PROMETHEUS_PORT   = "9090"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "flaresolverr"
        port = "flaresolverr"
        tags = [
          "flaresolverr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.flaresolverr.middlewares=nginx-auth@file",
          "traefik.http.routers.flaresolverr.rule=Host(`flaresolverr.${var.domain}`) || Host(`flaresolverr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.flaresolverr.loadbalancer.server.port=8191",
          "homepage.group=Infrastructure",
          "homepage.name=Flaresolverr",
          "homepage.icon=flaresolverr.png",
          "homepage.href=https://flaresolverr.${var.domain}/",
          "homepage.description=Headless anti-bot proxy to bypass Cloudflare/JS challenges for indexers and scrapers"
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }
  group "jackett-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "jackett" {
        static = 9117
        to = 9117
      }
    }

    # 🔹🔹 Jackett 🔹🔹
    task "jackett" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/jackett:latest"
        ports = ["jackett"]
        volumes = [
          "${var.config_path}/jackett/config:/config",
          "/mnt/remote/blackhole:/blackhole"
        ]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "jackett"
        }
      }

      env {
        TZ               = var.tz
        PUID             = var.puid
        PGID             = "988"
        UMASK            = var.umask
        AUTO_UPDATE      = "true"
        RUN_OPTS         = ""
        JACKETT_API_KEY  = var.jackett_api_key
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "jackett"
        port = "jackett"
        tags = [
          "jackett",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.jackett.rule=Host(`jackett.${var.domain}`) || Host(`jackett.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.jackett.loadbalancer.server.port=9117",
          "homepage.group=Source Aggregator",
          "homepage.name=Jackett Indexer",
          "homepage.icon=jackett.png",
          "homepage.href=https://jackett.${var.domain}/",
          "homepage.description=Connects your download applications with various source providers and indexers",
          "homepage.weight=1"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs http://127.0.0.1:9117/api/v2.0/indexers/all/results/torznab?t=indexers&apikey=${var.jackett_api_key} > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "prowlarr-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "prowlarr" {
        static = 9696
        to = 9696
      }
    }

    # 🔹🔹 Prowlarr 🔹🔹
    task "prowlarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/prowlarr:latest"
        ports = ["prowlarr"]
        volumes = [
          "${var.config_path}/prowlarr/config:/config:rw"
        ]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "prowlarr"
        }
      }

      env {
        TZ   = var.tz
        PUID = var.puid
        PGID = "988"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "prowlarr"
        port = "prowlarr"
        tags = [
          "prowlarr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.${var.domain}`) || Host(`prowlarr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.prowlarr.loadbalancer.server.port=9696",
          "homepage.group=Indexers",
          "homepage.name=Prowlarr",
          "homepage.icon=prowlarr.png",
          "homepage.href=https://prowlarr.${var.domain}/",
          "homepage.description=Indexer proxy and manager; normalizes indexers and feeds PVR apps like Sonarr/Radarr",
          "homepage.weight=1"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs -H \"Authorization: Bearer ${var.prowlarr_api_key}\" http://127.0.0.1:9696/api/v1/system/status || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "rclone-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "rclone" { to = 5572 }
    }

    # 🔹🔹 Rclone 🔹🔹
    task "rclone" {
      driver = "docker"

      config {
        image = "docker.io/rclone/rclone:1.71"
        ports = ["rclone"]
        devices = [
          {
            host_path      = "/dev/fuse"
            container_path = "/dev/fuse"
          }
        ]
        cap_add = ["SYS_ADMIN"]
        security_opt = ["apparmor:unconfined"]
        volumes = [
          "/:/hostfs:rshared",
          "/etc/group:/etc/group:ro",
          "/etc/passwd:/etc/passwd:ro",
          "/mnt/remote:/mnt/remote:rshared",
          "${var.config_path}/rclone/.cache:/.cache",
          "${var.config_path}/rclone/config/rclone:/config/rclone",
          "${var.config_path}/rclonefm/js:/var/lib/rclonefm/js"
        ]
        command = "rcd"
        args = [
          "--rc-web-gui",
          "--rc-web-gui-no-open-browser",
          "--rc-addr=:5572",
          "--log-level=INFO",
          "--rc-no-auth",
          "--config=/config/rclone/rclone.conf",
          "--cache-dir=/.cache/rclone"
        ]
        labels = {
          "com.docker.compose.project" = "rclone-group"
          "com.docker.compose.service" = "rclone"
        }
      }

      # Rclone config template
      template {
        data = <<EOF
[gcache]
type = cache
remote = gdrive:x-san
plex_url = http://plex:32400
plex_username = {{ env "PLEX_EMAIL" | or "" }}
plex_password = ${var.sudo_password}
chunk_size = 16M
plex_token = {{ env "PLEX_TOKEN" | or "" }}
db_path = /config/rclone/rclone-cache
chunk_path = /config/rclone/rclone-cache
info_age = 2d
chunk_total_size = 20G
db_purge = true

[zurg]
type = webdav
url = http://zurg:9999/dav
vendor = other
pacer_min_sleep = 0

[zurghttp]
type = http
url = http://zurg:9999/http/
no_head = false
no_slash = false

[alldebrid]
type = webdav
url = {{ env "ALLDEBRID_WEBDAV_URL" | or "https://webdav.debrid.it/" }}
vendor = other
user = {{ env "ALLDUBRID_RCLONE_USER" | or "" }}

[pm]
type = premiumizeme
token: {"access_token":"{{ env "PREMIUMIZE_RCLONE_ACCESS_TOKEN" | or "" }}","token_type":"Bearer","refresh_token":"{{ env "PREMIUMIZE_RCLONE_REFRESH_TOKEN" | or "" }}","expiry":"2035-08-29T06:37:06.7039897-05:00","expires_in":315360000}
EOF
        destination = "local/rclone.conf"
      }

      # Rclone mounts JSON template
      template {
        data = <<EOF
[
  {
    "fs": "pm:",
    "mountPoint": "/mnt/remote/premiumize",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "LogLevel": "DEBUG"
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "AttrTimeout": "87600h",
      "DirCacheTime": "60s",
      "DirPerms": "0777",
      "ExtraFlags": [
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "FilePerms": "0666",
      "GID": 1000,
      "PollInterval": "30s",
      "UID": 1000
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "2m",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "CachePollInterval": "30s",
      "ChunkSize": "2M",
      "ChunkSizeLimit": "64M",
      "DiskSpaceTotalSize": "1T",
      "ExtraOptions": [
        "--vfs-refresh",
        "--transfers=16",
        "--checkers=16",
        "--multi-thread-streams=4",
        "--cache-dir=/mnt/remote/cache/realdebrid"
      ],
      "FastFingerprint": true,
      "MinFreeSpace": "1G",
      "ReadAhead": "128M",
      "ReadWait": "40ms"
    }
  },
  {
    "fs": "alldebrid:",
    "mountPoint": "/mnt/remote/alldebrid",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "ExtraFlags": [
        "--cutoff-mode=cautious",
        "--network-mode",
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "LogLevel": "DEBUG",
      "MultiThreadStreams": 0,
      "TPSLimit": 12,
      "Transfers": 8
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "DirPerms": "0777",
      "ExtraFlags": [
        "--cache-dir=/mnt/remote/cache/alldebrid"
      ],
      "FilePerms": "0666",
      "VolumeName": "AllDebrid"
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "1h",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "ChunkSize": "128M",
      "ChunkSizeLimit": "0",
      "DirCacheTime": "160h",
      "ExtraOptions": [],
      "ReadAhead": "0"
    }
  }
]
EOF
        destination = "local/rclone-mounts.json"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "rclone"
        port = "rclone"
        tags = [
          "rclone",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.rclone.middlewares=nginx-auth@file",
          "traefik.http.routers.rclone.rule=Host(`rclone.${var.domain}`) || Host(`rclone.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.rclone.loadbalancer.server.port=5572",
          "homepage.group=Cloud",
          "homepage.name=Rclone",
          "homepage.icon=rclone.png",
          "homepage.href=https://rclone.${var.domain}/",
          "homepage.description=A web interface for Rclone.",
          "homepage.weight=0"
        ]

        check {
          type     = "script"
          command  = "/bin/mountpoint"
          args     = ["-q", "/mnt/remote"]
          interval = "5s"
          timeout  = "3s"
        }
      }
    }
  }
  group "rclone-init-group" {
    count = 1

    network {
      mode = "bridge"
    }

    # Rclone Init container
    task "rclone-init" {
      driver = "docker"

      config {
        image = "ghcr.io/coanghel/rclone-docker-automount/rclone-init:latest"
        network_mode = "bridge"
        volumes = [
          "/mnt/remote:/mnt/remote:rshared"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "rclone-init"
        }
      }

      # Mount configuration template
      template {
        data = <<EOF
[
  {
    "fs": "pm:",
    "mountPoint": "/mnt/remote/premiumize",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "LogLevel": "DEBUG"
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "AttrTimeout": "87600h",
      "DirCacheTime": "60s",
      "DirPerms": "0777",
      "ExtraFlags": [
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "FilePerms": "0666",
      "GID": 1000,
      "PollInterval": "30s",
      "UID": 1000
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "2m",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "CachePollInterval": "30s",
      "ChunkSize": "2M",
      "ChunkSizeLimit": "64M",
      "DiskSpaceTotalSize": "1T",
      "ExtraOptions": [
        "--vfs-refresh",
        "--transfers=16",
        "--checkers=16",
        "--multi-thread-streams=4",
        "--cache-dir=/mnt/remote/cache/realdebrid"
      ],
      "FastFingerprint": true,
      "MinFreeSpace": "1G",
      "ReadAhead": "128M",
      "ReadWait": "40ms"
    }
  }
]
EOF
        destination = "local/mounts.json"
      }

      env {
        RCLONE_USERNAME    = ""
        RCLONE_PASSWORD    = ""
        RCLONE_PORT        = var.rclone_port
        RCLONE_CONFIG_PATH = "/config/rclone/rclone.conf"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }
}
