job "media-stack-media-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 65

  group "stremio-services" {
    count = 1

    network {
      mode = "bridge"
      port "stremio" {
        to = 8080
      }
      port "stremio_http" {
        to = 11470
      }
      port "stremio_https" {
        to = 12470
      }
      port "aiostreams" {
        to = 3005
      }
    }

    task "stremio" {
      driver = "docker"

      config {
        image = "tsaridas/stremio-docker:latest"
        network_mode = "service:warp"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/stremio/root/.stremio-server:/root/.stremio-server"
        ]
      }

      env {
        IPADDRESS = "${NOMAD_META_EXTERNAL_IP}"
        SERVER_URL = "${NOMAD_META_STREMIO_SERVER_URL}"
        WEBUI_LOCATION = "${NOMAD_META_STREMIO_WEBUI_LOCATION}"
        NO_CORS = "0"
        CASTING_DISABLED = "1"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "stremio"
        
        check {
          type     = "script"
          name     = "stremio-health"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs http://127.0.0.1:11470 || curl -fs http://127.0.0.1:12470"]
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Media Streaming Platforms",
          "homepage.name=Stremio",
          "homepage.icon=stremio.png",
          "homepage.href=https://stremio.${NOMAD_META_DOMAIN}/",
          "homepage.description=A one-stop hub for video content aggregation, allowing you to stream movies, series, and more from various sources."
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "aiostreams" {
      driver = "docker"

      config {
        image = "ghcr.io/viren070/aiostreams:latest"
        network_mode = "service:warp"
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        ADDON_NAME = "BadenAIO"
        ADDON_ID = "aiostreams.${NOMAD_META_DOMAIN}"
        DETERMINISTIC_ADDON_ID = "false"
        PORT = "${NOMAD_META_AIOSTREAMS_PORT}"
        SECRET_KEY = "${NOMAD_META_AIOSTREAMS_SECRET_KEY}"
        API_KEY = "${NOMAD_META_AIOSTREAMS_API_KEY}"
        SHOW_DIE = "false"
        LOG_LEVEL = "debug"
        LOG_FORMAT = "text"
        LOG_SENSITIVE_INFO = "true"
        MAX_ADDONS = "50"
        MAX_KEYWORD_FILTERS = "30"
        MAX_REGEX_SORT_PATTERNS = "30"
        MAX_MOVIE_SIZE = "161061273600"
        MAX_EPISODE_SIZE = "161061273600"
        MAX_TIMEOUT = "50000"
        MIN_TIMEOUT = "1000"
        MEDIAFLOW_IP_TIMEOUT = "30000"
        ENCRYPT_MEDIAFLOW_URLS = "true"
        STREMTHRU_TIMEOUT = "30000"
        DEFAULT_STREMTHRU_URL = "https://stremthru.${NOMAD_META_DOMAIN}/"
        DEFAULT_STREMTHRU_CREDENTIAL = "${NOMAD_META_DEFAULT_STREMTHRU_CREDENTIAL}"
        ENCRYPT_STREMTHRU_URLS = "true"
        DEFAULT_TIMEOUT = "15000"
        COMET_URL = "http://comet:2020/"
        FORCE_COMET_HOSTNAME = "comet.${NOMAD_META_DOMAIN}"
        FORCE_COMET_PORT = "443"
        FORCE_COMET_PROTOCOL = "https"
        MEDIAFUSION_URL = "http://mediafusion:8000/"
        MEDIAFUSION_CONFIG_TIMEOUT = "5000"
        MEDIAFUSION_API_PASSWORD = "${NOMAD_META_SUDO_PASSWORD}"
        JACKETTIO_URL = "https://jackettio.elfhosted.com/"
        DEFAULT_JACKETTIO_INDEXERS = "[\"1337x\", \"animetosho\", \"anirena\", \"limetorrents\", \"nyaasi\", \"solidtorrents\", \"thepiratebay\", \"torlock\", \"yts\"]"
        DEFAULT_JACKETTIO_STREMTHRU_URL = "https://stremthru.13377001.xyz"
        STREMIO_JACKETT_URL = "https://stremio-jackett.elfhosted.com/"
        DEFAULT_STREMIO_JACKETT_TMDB_API_KEY = "${NOMAD_META_TMDB_API_KEY}"
        STREMIO_JACKETT_CACHE_ENABLED = "true"
        STREMTHRU_STORE_URL = "https://stremthru.elfhosted.com/stremio/store/"
        EASYNEWS_PLUS_URL = "https://b89262c192b0-stremio-easynews-addon.baby-beamup.club/"
        EASYNEWS_PLUS_PLUS_URL = "https://easynews-cloudflare-worker.jqrw92fchz.workers.dev/"
        DISABLE_TORRENTIO_MESSAGE = ""
        TORRENTIO_URL = "https://torrentio.strem.fun/"
        ORION_STREMIO_ADDON_URL = "https://5a0d1888fa64-orion.baby-beamup.club/"
        PEERFLIX_URL = "https://peerflix-addon.onrender.com/"
        TORBOX_STREMIO_URL = "https://stremio.torbox.app/"
        EASYNEWS_URL = "https://ea627ddf0ee7-easynews.baby-beamup.club/"
        DEBRIDIO_URL = "https://debridio.adobotec.com/"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "aiostreams"
        
        check {
          type     = "http"
          path     = "/health"
          port     = 3005
          interval = "1m"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Stremio Addons",
          "homepage.name=AIOStreams",
          "homepage.icon=aiostreams.png",
          "homepage.href=https://aiostreams.${NOMAD_META_DOMAIN}/",
          "homepage.description=AIOStreams is a stremio addon that combines multiple stremio addons into one, providing additional functionality that can be used for all these addons that may not natively otherwise support them."
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

  group "indexer-services" {
    count = 1

    network {
      mode = "bridge"
      port "jackett" {
        to = 9117
      }
      port "prowlarr" {
        to = 9696
      }
      port "comet" {
        to = 2020
      }
    }

    task "jackett" {
      driver = "docker"

      config {
        image = "linuxserver/jackett"
        network_mode = "service:warp"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/jackett/config:/config",
          "${NOMAD_META_CONFIG_PATH}/jackett/blackhole:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        AUTO_UPDATE = "true"
        RUN_OPTS = ""
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "jackett"
        
        check {
          type     = "script"
          name     = "jackett-health"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs http://127.0.0.1:9117/api/v2.0/indexers/all/results/torznab?t=indexers&apikey=${NOMAD_META_JACKETT_API_KEY}"]
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Source Aggregator",
          "homepage.name=Jackett Indexer",
          "homepage.icon=jackett.png",
          "homepage.href=https://jackett.${NOMAD_META_DOMAIN}/",
          "homepage.description=Connects your download applications with various source providers and indexers, making it easier to find and download content through your download clients.",
          "homepage.weight=1",
          "homepage.widget.type=jackett",
          "homepage.widget.url=http://jackett:9117",
          "homepage.widget.key=${NOMAD_META_JACKETT_API_KEY}"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "prowlarr" {
      driver = "docker"

      config {
        image = "linuxserver/prowlarr"
        network_mode = "service:warp"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/prowlarr/config:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        PROWLARR_API_KEY = "${NOMAD_META_PROWLARR_API_KEY}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "prowlarr"
        
        check {
          type     = "script"
          name     = "prowlarr-health"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs -H \"Authorization: Bearer ${NOMAD_META_PROWLARR_API_KEY}\" http://127.0.0.1:9696/api/v1/system/status"]
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Indexers",
          "homepage.name=Prowlarr",
          "homepage.icon=prowlarr.png",
          "homepage.href=https://prowlarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=An indexer manager/proxy for your Usenet and Torrent downloaders, integrating with PVR apps like Sonarr and Radarr.",
          "homepage.weight=1",
          "homepage.widget.type=prowlarr",
          "homepage.widget.url=http://prowlarr:9696",
          "homepage.widget.key=${NOMAD_META_PROWLARR_API_KEY}"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "comet" {
      driver = "docker"

      config {
        image = "g0ldyy/comet"
        network_mode = "service:warp"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/stremio/addons/comet/data:/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        ADDON_ID = "comet.${NOMAD_META_DOMAIN}"
        ADDON_NAME = "Comet"
        FASTAPI_HOST = "0.0.0.0"
        FASTAPI_PORT = "${NOMAD_META_COMET_PORT}"
        FASTAPI_WORKERS = "4"
        USE_GUNICORN = "True"
        DASHBOARD_ADMIN_PASSWORD = "${NOMAD_META_SUDO_PASSWORD}"
        DATABASE_TYPE = "sqlite"
        DATABASE_PATH = "/data/comet.db"
        METADATA_CACHE_TTL = "2592000"
        TORRENT_CACHE_TTL = "1296000"
        DEBRID_CACHE_TTL = "86400"
        INDEXER_MANAGER_TYPE = "${NOMAD_META_COMET_INDEXER_MANAGER_TYPE}"
        INDEXER_MANAGER_URL = "${NOMAD_META_COMET_INDEXER_MANAGER_URL}"
        INDEXER_MANAGER_API_KEY = "${NOMAD_META_COMET_INDEXER_MANAGER_API_KEY}"
        INDEXER_MANAGER_TIMEOUT = "60"
        INDEXER_MANAGER_INDEXERS = "[\"1337x\", \"animetosho\", \"anirena\", \"limetorrents\", \"nyaasi\", \"thepiratebay\", \"torlock\", \"yts\"]"
        GET_TORRENT_TIMEOUT = "2"
        DOWNLOAD_TORRENT_FILES = "False"
        SCRAPE_COMET = "false"
        COMET_URL = "https://comet.elfhosted.com"
        SCRAPE_ZILEAN = "true"
        ZILEAN_URL = "https://zilean.elfhosted.com"
        SCRAPE_TORRENTIO = "false"
        TORRENTIO_URL = "https://torrentio.strem.fun"
        SCRAPE_MEDIAFUSION = "false"
        MEDIAFUSION_URL = "https://mediafusion.elfhosted.com"
        STREMTHRU_URL = "https://stremthru.${NOMAD_META_DOMAIN}"
        PROXY_DEBRID_STREAM = "True"
        PROXY_DEBRID_STREAM_PASSWORD = "${NOMAD_META_SUDO_PASSWORD}"
        PROXY_DEBRID_STREAM_MAX_CONNECTIONS = "-1"
        PROXY_DEBRID_STREAM_DEBRID_DEFAULT_SERVICE = "premiumize"
        PROXY_DEBRID_STREAM_DEBRID_DEFAULT_APIKEY = "${NOMAD_META_PREMIUMIZE_API_KEY}"
        REMOVE_ADULT_CONTENT = "True"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "comet"
        
        check {
          type     = "http"
          path     = "/health"
          port     = 2020
          interval = "1m"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Stremio Addons",
          "homepage.name=Comet",
          "homepage.icon=comet.png",
          "homepage.href=https://comet.${NOMAD_META_DOMAIN}/"
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

  group "mediafusion-service" {
    count = 1

    network {
      mode = "bridge"
      port "mediafusion" {
        to = 8000
      }
    }

    task "mediafusion" {
      driver = "docker"

      config {
        image = "mhdzumair/mediafusion:latest"
        network_mode = "service:warp"
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        ADDON_NAME = "${NOMAD_META_MEDIAFUSION_ADDON_NAME}"
        VERSION = "${NOMAD_META_MEDIAFUSION_VERSION}"
        DESCRIPTION = "${NOMAD_META_MEDIAFUSION_DESCRIPTION}"
        BRANDING_DESCRIPTION = "${NOMAD_META_MEDIAFUSION_BRANDING_DESCRIPTION}"
        CONTACT_EMAIL = "${NOMAD_META_MEDIAFUSION_CONTACT_EMAIL}"
        HOST_URL = "https://mediafusion.${NOMAD_META_DOMAIN}"
        POSTER_HOST_URL = "${NOMAD_META_MEDIAFUSION_POSTER_HOST_URL}"
        SECRET_KEY = "${NOMAD_META_MEDIAFUSION_SECRET_KEY}"
        API_PASSWORD = "${NOMAD_META_SUDO_PASSWORD}"
        LOGGING_LEVEL = "DEBUG"
        LOGO_URL = "${NOMAD_META_MEDIAFUSION_LOGO_URL}"
        IS_PUBLIC_INSTANCE = "${NOMAD_META_MEDIAFUSION_IS_PUBLIC_INSTANCE}"
        MIN_SCRAPING_VIDEO_SIZE = "${NOMAD_META_MEDIAFUSION_MIN_SCRAPING_VIDEO_SIZE}"
        METADATA_PRIMARY_SOURCE = "${NOMAD_META_MEDIAFUSION_METADATA_PRIMARY_SOURCE}"
        DISABLED_PROVIDERS = "${NOMAD_META_MEDIAFUSION_DISABLED_PROVIDERS}"
        MONGO_URI = "${NOMAD_META_MEDIAFUSION_MONGO_URI}"
        DB_MAX_CONNECTIONS = "${NOMAD_META_MEDIAFUSION_DB_MAX_CONNECTIONS}"
        REDIS_URL = "${NOMAD_META_MEDIAFUSION_REDIS_URL}"
        REDIS_MAX_CONNECTIONS = "${NOMAD_META_MEDIAFUSION_REDIS_MAX_CONNECTIONS}"
        PLAYWRIGHT_CDP_URL = "${NOMAD_META_MEDIAFUSION_PLAYWRIGHT_CDP_URL}"
        FLARESOLVERR_URL = "${NOMAD_META_MEDIAFUSION_FLARESOLVERR_URL}"
        TMDB_API_KEY = "${NOMAD_META_TMDB_API_KEY}"
        IS_SCRAP_FROM_PROWLARR = "True"
        PROWLARR_API_KEY = "${NOMAD_META_PROWLARR_API_KEY}"
        PROWLARR_URL = "${NOMAD_META_PROWLARR_URL}"
        PROWLARR_LIVE_TITLE_SEARCH = "${NOMAD_META_MEDIAFUSION_PROWLARR_LIVE_TITLE_SEARCH}"
        PROWLARR_BACKGROUND_TITLE_SEARCH = "${NOMAD_META_MEDIAFUSION_PROWLARR_BACKGROUND_TITLE_SEARCH}"
        PROWLARR_SEARCH_QUERY_TIMEOUT = "${NOMAD_META_MEDIAFUSION_PROWLARR_SEARCH_QUERY_TIMEOUT}"
        PROWLARR_IMMEDIATE_MAX_PROCESS = "${NOMAD_META_MEDIAFUSION_PROWLARR_IMMEDIATE_MAX_PROCESS}"
        PROWLARR_IMMEDIATE_MAX_PROCESS_TIME = "${NOMAD_META_MEDIAFUSION_PROWLARR_IMMEDIATE_MAX_PROCESS_TIME}"
        PROWLARR_SEARCH_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_PROWLARR_SEARCH_INTERVAL_HOUR}"
        PROWLARR_FEED_SCRAPE_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_PROWLARR_FEED_SCRAPE_INTERVAL_HOUR}"
        IS_SCRAP_FROM_JACKETT = "True"
        JACKETT_URL = "${NOMAD_META_JACKETT_URL}"
        JACKETT_API_KEY = "${NOMAD_META_JACKETT_API_KEY}"
        JACKETT_SEARCH_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_JACKETT_SEARCH_INTERVAL_HOUR}"
        JACKETT_SEARCH_QUERY_TIMEOUT = "${NOMAD_META_MEDIAFUSION_JACKETT_SEARCH_QUERY_TIMEOUT}"
        JACKETT_IMMEDIATE_MAX_PROCESS = "${NOMAD_META_MEDIAFUSION_JACKETT_IMMEDIATE_MAX_PROCESS}"
        JACKETT_IMMEDIATE_MAX_PROCESS_TIME = "${NOMAD_META_MEDIAFUSION_JACKETT_IMMEDIATE_MAX_PROCESS_TIME}"
        JACKETT_LIVE_TITLE_SEARCH = "${NOMAD_META_MEDIAFUSION_JACKETT_LIVE_TITLE_SEARCH}"
        JACKETT_BACKGROUND_TITLE_SEARCH = "${NOMAD_META_MEDIAFUSION_JACKETT_BACKGROUND_TITLE_SEARCH}"
        JACKETT_FEED_SCRAPE_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_JACKETT_FEED_SCRAPE_INTERVAL_HOUR}"
        IS_SCRAP_FROM_ZILEAN = "True"
        ZILEAN_SEARCH_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_ZILEAN_SEARCH_INTERVAL_HOUR}"
        ZILEAN_URL = "${NOMAD_META_ZILEAN_URL}"
        IS_SCRAP_FROM_TORRENTIO = "True"
        TORRENTIO_SEARCH_INTERVAL_DAYS = "${NOMAD_META_MEDIAFUSION_TORRENTIO_SEARCH_INTERVAL_DAYS}"
        TORRENTIO_URL = "${NOMAD_META_TORRENTIO_URL}"
        IS_SCRAP_FROM_MEDIAFUSION = "True"
        MEDIAFUSION_SEARCH_INTERVAL_DAYS = "${NOMAD_META_MEDIAFUSION_MEDIAFUSION_SEARCH_INTERVAL_DAYS}"
        MEDIAFUSION_URL = "${NOMAD_META_MEDIAFUSION_URL}"
        SYNC_DEBRID_CACHE_STREAMS = "${NOMAD_META_MEDIAFUSION_SYNC_DEBRID_CACHE_STREAMS}"
        IS_SCRAP_FROM_BT4G = "True"
        BT4G_URL = "${NOMAD_META_BT4G_URL}"
        BT4G_SEARCH_INTERVAL_HOUR = "${NOMAD_META_MEDIAFUSION_BT4G_SEARCH_INTERVAL_HOUR}"
        BT4G_SEARCH_TIMEOUT = "${NOMAD_META_MEDIAFUSION_BT4G_SEARCH_TIMEOUT}"
        BT4G_IMMEDIATE_MAX_PROCESS = "${NOMAD_META_MEDIAFUSION_BT4G_IMMEDIATE_MAX_PROCESS}"
        BT4G_IMMEDIATE_MAX_PROCESS_TIME = "${NOMAD_META_MEDIAFUSION_BT4G_IMMEDIATE_MAX_PROCESS_TIME}"
        TELEGRAM_BOT_TOKEN = "${NOMAD_META_TELEGRAM_BOT_TOKEN}"
        TELEGRAM_CHAT_ID = "${NOMAD_META_TELEGRAM_CHAT_ID}"
        ADULT_CONTENT_REGEX_KEYWORDS = "${NOMAD_META_MEDIAFUSION_ADULT_CONTENT_REGEX_KEYWORDS}"
        ADULT_CONTENT_FILTER_IN_TORRENT_TITLE = "${NOMAD_META_MEDIAFUSION_ADULT_CONTENT_FILTER_IN_TORRENT_TITLE}"
        IS_SCRAP_FROM_YTS = "True"
        ENABLE_RATE_LIMIT = "${NOMAD_META_MEDIAFUSION_ENABLE_RATE_LIMIT}"
        VALIDATE_M3U8_URLS_LIVENESS = "${NOMAD_META_MEDIAFUSION_VALIDATE_M3U8_URLS_LIVENESS}"
        STORE_STREMTHRU_MAGNET_CACHE = "${NOMAD_META_MEDIAFUSION_STORE_STREMTHRU_MAGNET_CACHE}"
        SCRAPE_WITH_AKA_TITLES = "${NOMAD_META_MEDIAFUSION_SCRAPE_WITH_AKA_TITLES}"
        ENABLE_FETCHING_TORRENT_METADATA_FROM_P2P = "${NOMAD_META_MEDIAFUSION_ENABLE_FETCHING_TORRENT_METADATA_FROM_P2P}"
        META_CACHE_TTL = "${NOMAD_META_MEDIAFUSION_META_CACHE_TTL}"
        WORKER_MAX_TASKS_PER_CHILD = "${NOMAD_META_MEDIAFUSION_WORKER_MAX_TASKS_PER_CHILD}"
        DISABLE_ALL_SCHEDULER = "${NOMAD_META_MEDIAFUSION_DISABLE_ALL_SCHEDULER}"
        BACKGROUND_SEARCH_INTERVAL_HOURS = "${NOMAD_META_MEDIAFUSION_BACKGROUND_SEARCH_INTERVAL_HOURS}"
        BACKGROUND_SEARCH_CRONTAB = "${NOMAD_META_MEDIAFUSION_BACKGROUND_SEARCH_CRONTAB}"
        TAMILMV_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_TAMILMV_SCHEDULER_CRONTAB}"
        TAMIL_BLASTERS_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_TAMIL_BLASTERS_SCHEDULER_CRONTAB}"
        FORMULA_TGX_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_FORMULA_TGX_SCHEDULER_CRONTAB}"
        NOWMETV_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_NOWMETV_SCHEDULER_CRONTAB}"
        NOWSPORTS_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_NOWSPORTS_SCHEDULER_CRONTAB}"
        TAMILULTRA_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_TAMILULTRA_SCHEDULER_CRONTAB}"
        VALIDATE_TV_STREAMS_IN_DB_CRONTAB = "${NOMAD_META_MEDIAFUSION_VALIDATE_TV_STREAMS_IN_DB_CRONTAB}"
        SPORT_VIDEO_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_SPORT_VIDEO_SCHEDULER_CRONTAB}"
        DLHD_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_DLHD_SCHEDULER_CRONTAB}"
        MOTOGP_TGX_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_MOTOGP_TGX_SCHEDULER_CRONTAB}"
        UPDATE_SEEDERS_CRONTAB = "${NOMAD_META_MEDIAFUSION_UPDATE_SEEDERS_CRONTAB}"
        ARAB_TORRENTS_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_ARAB_TORRENTS_SCHEDULER_CRONTAB}"
        WWE_TGX_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_WWE_TGX_SCHEDULER_CRONTAB}"
        UFC_TGX_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_UFC_TGX_SCHEDULER_CRONTAB}"
        MOVIES_TV_TGX_SCHEDULER_CRONTAB = "${NOMAD_META_MEDIAFUSION_MOVIES_TV_TGX_SCHEDULER_CRONTAB}"
        PROWLARR_FEED_SCRAPER_CRONTAB = "${NOMAD_META_MEDIAFUSION_PROWLARR_FEED_SCRAPER_CRONTAB}"
        JACKETT_FEED_SCRAPER_CRONTAB = "${NOMAD_META_MEDIAFUSION_JACKETT_FEED_SCRAPER_CRONTAB}"
        CLEANUP_EXPIRED_SCRAPER_TASK_CRONTAB = "${NOMAD_META_MEDIAFUSION_CLEANUP_EXPIRED_SCRAPER_TASK_CRONTAB}"
        CLEANUP_EXPIRED_CACHE_TASK_CRONTAB = "${NOMAD_META_MEDIAFUSION_CLEANUP_EXPIRED_CACHE_TASK_CRONTAB}"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "mediafusion"
        
        check {
          type     = "http"
          path     = "/health"
          port     = 8000
          interval = "1m"
          timeout  = "10s"
        }

        tags = [
          "homepage.group=Stremio Addons",
          "homepage.name=MediaFusion",
          "homepage.icon=mediafusion.png",
          "homepage.href=https://mediafusion.${NOMAD_META_DOMAIN}/"
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
    # Common environment variables
    TZ = "America/Chicago"
    PUID = "1002"
    PGID = "988"
    UMASK = "002"
    
    # Paths
    CONFIG_PATH = "./configs"
    
    # Domain configuration
    DOMAIN = "example.com"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"
    
    # External configuration
    EXTERNAL_IP = "149.130.221.93"
    SUDO_PASSWORD = ""
    
    # Stremio configuration
    STREMIO_SERVER_URL = "https://stremio.example.com"
    STREMIO_WEBUI_LOCATION = "https://stremio-web.example.com/"
    
    # AIOStreams configuration
    AIOSTREAMS_PORT = "3005"
    AIOSTREAMS_SECRET_KEY = "1070c705d193441da9fce510d5977e824686d5d0a0ab44bc8d8cb006ff64ee82"
    AIOSTREAMS_API_KEY = "sk_4dc059c0399c43fd94c09baaf0b94da119fc526775914bf2b3a3fb6e073e26d9"
    DEFAULT_STREMTHRU_CREDENTIAL = ""
    
    # API Keys
    TMDB_API_KEY = ""
    JACKETT_API_KEY = ""
    PROWLARR_API_KEY = ""
    PREMIUMIZE_API_KEY = ""
    
    # Comet configuration
    COMET_PORT = "2020"
    COMET_INDEXER_MANAGER_TYPE = "prowlarr"
    COMET_INDEXER_MANAGER_URL = "http://prowlarr:9696"
    COMET_INDEXER_MANAGER_API_KEY = ""
    
    # MediaFusion configuration
    MEDIAFUSION_ADDON_NAME = "MediaFusion"
    MEDIAFUSION_VERSION = "1.0.0"
    MEDIAFUSION_DESCRIPTION = "MediaFusion Stremio Addon"
    MEDIAFUSION_BRANDING_DESCRIPTION = ""
    MEDIAFUSION_CONTACT_EMAIL = "mhdzumair@gmail.com"
    MEDIAFUSION_POSTER_HOST_URL = "https://mediafusion.example.com"
    MEDIAFUSION_SECRET_KEY = ""
    MEDIAFUSION_LOGO_URL = ""
    MEDIAFUSION_IS_PUBLIC_INSTANCE = "False"
    MEDIAFUSION_MIN_SCRAPING_VIDEO_SIZE = "26214400"
    MEDIAFUSION_METADATA_PRIMARY_SOURCE = "imdb"
    MEDIAFUSION_DISABLED_PROVIDERS = "[]"
    MEDIAFUSION_MONGO_URI = "mongodb://mongodb:27017/mediafusion"
    MEDIAFUSION_DB_MAX_CONNECTIONS = "50"
    MEDIAFUSION_REDIS_URL = "redis://redis:6379"
    MEDIAFUSION_REDIS_MAX_CONNECTIONS = "100"
    MEDIAFUSION_PLAYWRIGHT_CDP_URL = "ws://browserless:3000?blockAds=true&stealth=true"
    MEDIAFUSION_FLARESOLVERR_URL = "http://flaresolverr:8191/v1"
    PROWLARR_URL = "http://prowlarr:9696"
    MEDIAFUSION_PROWLARR_LIVE_TITLE_SEARCH = "False"
    MEDIAFUSION_PROWLARR_BACKGROUND_TITLE_SEARCH = "True"
    MEDIAFUSION_PROWLARR_SEARCH_QUERY_TIMEOUT = "30"
    MEDIAFUSION_PROWLARR_IMMEDIATE_MAX_PROCESS = "10"
    MEDIAFUSION_PROWLARR_IMMEDIATE_MAX_PROCESS_TIME = "15"
    MEDIAFUSION_PROWLARR_SEARCH_INTERVAL_HOUR = "72"
    MEDIAFUSION_PROWLARR_FEED_SCRAPE_INTERVAL_HOUR = "3"
    JACKETT_URL = "http://jackett:9117"
    MEDIAFUSION_JACKETT_SEARCH_INTERVAL_HOUR = "72"
    MEDIAFUSION_JACKETT_SEARCH_QUERY_TIMEOUT = "30"
    MEDIAFUSION_JACKETT_IMMEDIATE_MAX_PROCESS = "10"
    MEDIAFUSION_JACKETT_IMMEDIATE_MAX_PROCESS_TIME = "15"
    MEDIAFUSION_JACKETT_LIVE_TITLE_SEARCH = "False"
    MEDIAFUSION_JACKETT_BACKGROUND_TITLE_SEARCH = "True"
    MEDIAFUSION_JACKETT_FEED_SCRAPE_INTERVAL_HOUR = "3"
    MEDIAFUSION_ZILEAN_SEARCH_INTERVAL_HOUR = "24"
    ZILEAN_URL = "https://zilean.elfhosted.com"
    MEDIAFUSION_TORRENTIO_SEARCH_INTERVAL_DAYS = "3"
    TORRENTIO_URL = "https://torrentio.strem.fun"
    MEDIAFUSION_MEDIAFUSION_SEARCH_INTERVAL_DAYS = "3"
    MEDIAFUSION_URL = "https://mediafusion.elfhosted.com"
    MEDIAFUSION_SYNC_DEBRID_CACHE_STREAMS = "True"
    BT4G_URL = "https://bt4gprx.com"
    MEDIAFUSION_BT4G_SEARCH_INTERVAL_HOUR = "72"
    MEDIAFUSION_BT4G_SEARCH_TIMEOUT = "10"
    MEDIAFUSION_BT4G_IMMEDIATE_MAX_PROCESS = "15"
    MEDIAFUSION_BT4G_IMMEDIATE_MAX_PROCESS_TIME = "15"
    TELEGRAM_BOT_TOKEN = ""
    TELEGRAM_CHAT_ID = ""
    MEDIAFUSION_ADULT_CONTENT_REGEX_KEYWORDS = "\\b(porn|xxx|sex|nude|naked|erotic|fetish|bdsm|milf|anal|oral|gangbang|threesome|masturbat|orgasm|cumshot|blowjob|handjob|footjob|creampie|facial|bukkake|hentai|yaoi|yuri|ecchi|doujin|camgirl|webcam|stripper|escort|prostitut|brothel|redlight|peepshow|voyeur|exhibitionist|swinger|orgy|hardcore|softcore|playboy|penthouse|hustler|brazzers|bangbros|realitykings|naughtyamerica|digitalplayground|wickedpictures|evilangel|kink|publicagent|fakehub|teamskeet|mofos|twistys|metart|sexart|x-art|joymii|nubiles|18eighteen|lolita|incest|taboo|kinky|slutty|horny|sexy|sensual|seductive|raw|perverted|depraved)\\b"
    MEDIAFUSION_ADULT_CONTENT_FILTER_IN_TORRENT_TITLE = "True"
    MEDIAFUSION_ENABLE_RATE_LIMIT = "False"
    MEDIAFUSION_VALIDATE_M3U8_URLS_LIVENESS = "True"
    MEDIAFUSION_STORE_STREMTHRU_MAGNET_CACHE = "False"
    MEDIAFUSION_SCRAPE_WITH_AKA_TITLES = "True"
    MEDIAFUSION_ENABLE_FETCHING_TORRENT_METADATA_FROM_P2P = "True"
    MEDIAFUSION_META_CACHE_TTL = "1800"
    MEDIAFUSION_WORKER_MAX_TASKS_PER_CHILD = "20"
    MEDIAFUSION_DISABLE_ALL_SCHEDULER = "False"
    MEDIAFUSION_BACKGROUND_SEARCH_INTERVAL_HOURS = "72"
    MEDIAFUSION_BACKGROUND_SEARCH_CRONTAB = "*/5 * * * *"
    MEDIAFUSION_TAMILMV_SCHEDULER_CRONTAB = "0 */3 * * *"
    MEDIAFUSION_TAMIL_BLASTERS_SCHEDULER_CRONTAB = "0 */6 * * *"
    MEDIAFUSION_FORMULA_TGX_SCHEDULER_CRONTAB = "*/30 * * * *"
    MEDIAFUSION_NOWMETV_SCHEDULER_CRONTAB = "0 0 * * *"
    MEDIAFUSION_NOWSPORTS_SCHEDULER_CRONTAB = "0 10 * * *"
    MEDIAFUSION_TAMILULTRA_SCHEDULER_CRONTAB = "0 8 * * *"
    MEDIAFUSION_VALIDATE_TV_STREAMS_IN_DB_CRONTAB = "0 */6 * * *"
    MEDIAFUSION_SPORT_VIDEO_SCHEDULER_CRONTAB = "*/20 * * * *"
    MEDIAFUSION_DLHD_SCHEDULER_CRONTAB = "25 * * * *"
    MEDIAFUSION_MOTOGP_TGX_SCHEDULER_CRONTAB = "0 5 * * *"
    MEDIAFUSION_UPDATE_SEEDERS_CRONTAB = "0 0 * * *"
    MEDIAFUSION_ARAB_TORRENTS_SCHEDULER_CRONTAB = "0 0 * * *"
    MEDIAFUSION_WWE_TGX_SCHEDULER_CRONTAB = "10 */3 * * *"
    MEDIAFUSION_UFC_TGX_SCHEDULER_CRONTAB = "30 */3 * * *"
    MEDIAFUSION_MOVIES_TV_TGX_SCHEDULER_CRONTAB = "0 * * * *"
    MEDIAFUSION_PROWLARR_FEED_SCRAPER_CRONTAB = "0 */3 * * *"
    MEDIAFUSION_JACKETT_FEED_SCRAPER_CRONTAB = "0 */3 * * *"
    MEDIAFUSION_CLEANUP_EXPIRED_SCRAPER_TASK_CRONTAB = "0 * * * *"
    MEDIAFUSION_CLEANUP_EXPIRED_CACHE_TASK_CRONTAB = "0 0 * * *"
  }
} 