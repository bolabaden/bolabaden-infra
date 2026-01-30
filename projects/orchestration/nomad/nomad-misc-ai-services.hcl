job "media-stack-misc-ai-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 50

  group "misc-ai" {
    count = 1

    network {
      mode = "bridge"
      port "open_webui" {
        to = 8080
      }
      port "meilisearch" {
        to = 7700
      }
      port "firecrawl_api" {
        to = 3002
      }
      port "firecrawl_worker" {
        to = 3000
      }
      port "firecrawl_playwright" {
        to = 3000
      }
    }

    task "open-webui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        hostname = "open-webui"
        ports = ["open_webui"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/open-webui:/app/backend/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        OLLAMA_BASE_URLS = "http://ollama:${NOMAD_META_OLLAMA_PORT}"
        WEBUI_AUTH = "${NOMAD_META_WEBUI_AUTH}"
        WEBUI_NAME = "${NOMAD_META_WEBUI_NAME}"
        WEBUI_URL = "${NOMAD_META_WEBUI_URL}"
        WEBUI_SECRET_KEY = "${NOMAD_META_WEBUI_SECRET_KEY}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "open-webui"
        port = "open_webui"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.open-webui.middlewares=nginx-auth@file",
          "traefik.http.routers.open-webui.rule=Host(`open-webui.${NOMAD_META_DOMAIN}`) || Host(`open-webui.${NOMAD_META_SECOND_DOMAIN}`) || Host(`open-webui.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`open-webui.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.open-webui.loadbalancer.server.port=8080",
          "homepage.group=AI",
          "homepage.name=Open WebUI",
          "homepage.icon=open-webui.png",
          "homepage.href=https://open-webui.${NOMAD_META_DOMAIN}/",
          "homepage.description=Open WebUI is a feature-rich self-hosted webui for chatting with GenAI."
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "meilisearch" {
      driver = "docker"

      config {
        image = "getmeili/meilisearch:v1.5"
        hostname = "meilisearch"
        ports = ["meilisearch"]
        volumes = [
          "meili_data:/meili_data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        MEILI_MASTER_KEY = "${NOMAD_META_MEILI_MASTER_KEY}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "meilisearch"
        port = "meilisearch"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.meilisearch.middlewares=nginx-auth@file",
          "traefik.http.routers.meilisearch.rule=Host(`meilisearch.${NOMAD_META_DOMAIN}`) || Host(`meilisearch.${NOMAD_META_SECOND_DOMAIN}`) || Host(`meilisearch.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`meilisearch.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.meilisearch.loadbalancer.server.port=7700",
          "homepage.group=Search",
          "homepage.name=Meilisearch",
          "homepage.icon=meilisearch.png",
          "homepage.href=https://meilisearch.${NOMAD_META_DOMAIN}/",
          "homepage.description=Meilisearch is a fast, easy to use, and reliable search engine."
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "firecrawl-api" {
      driver = "docker"

      config {
        image = "mendable/firecrawl:latest"
        hostname = "firecrawl-api"
        ports = ["firecrawl_api"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        PORT = "3002"
        HOST = "0.0.0.0"
        USE_DB_AUTHENTICATION = "${NOMAD_META_FIRECRAWL_USE_DB_AUTHENTICATION}"
        OPENAI_API_KEY = "${NOMAD_META_OPENAI_API_KEY}"
        SEARXNG_ENDPOINT = "http://searxng:8888"
        BULL_AUTH_KEY = "${NOMAD_META_FIRECRAWL_BULL_AUTH_KEY}"
        MAX_CPU = "0"
        MAX_RAM = "0"
        REDIS_URL = "redis:${NOMAD_META_REDIS_IPV4_ADDRESS}:6379"
        REDIS_RATE_LIMIT_URL = "redis:${NOMAD_META_REDIS_IPV4_ADDRESS}:6379"
        PLAYWRIGHT_MICROSERVICE_URL = "${NOMAD_META_FIRECRAWL_PLAYWRIGHT_MICROSERVICE_URL}"
        NUM_WORKERS_PER_QUEUE = "${NOMAD_META_FIRECRAWL_NUM_WORKERS_PER_QUEUE}"
        LOGGING_LEVEL = "${NOMAD_META_FIRECRAWL_LOGGING_LEVEL}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "firecrawl-api"
        port = "firecrawl_api"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.firecrawl-api.middlewares=nginx-auth@file",
          "traefik.http.routers.firecrawl-api.rule=Host(`firecrawl-api.${NOMAD_META_DOMAIN}`) || Host(`firecrawl-api.${NOMAD_META_SECOND_DOMAIN}`) || Host(`firecrawl-api.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`firecrawl-api.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.firecrawl-api.loadbalancer.server.port=3002"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "firecrawl-playwright" {
      driver = "docker"

      config {
        image = "browserless/chrome"
        hostname = "firecrawl-playwright"
        ports = ["firecrawl_playwright"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "firecrawl-playwright"
        port = "firecrawl_playwright"
        
        tags = [
          "utility",
          "headless-browser"
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

    OLLAMA_PORT = "11434"
    WEBUI_AUTH = "False"
    WEBUI_NAME = "BadenAI"
    WEBUI_URL = "https://open-webui.example.com"
    WEBUI_SECRET_KEY = ""

    MEILI_MASTER_KEY = ""

    FIRECRAWL_USE_DB_AUTHENTICATION = "false"
    FIRECRAWL_BULL_AUTH_KEY = ""
    FIRECRAWL_PLAYWRIGHT_MICROSERVICE_URL = "http://firecrawl-playwright:3000/html"
    FIRECRAWL_NUM_WORKERS_PER_QUEUE = "8"
    FIRECRAWL_LOGGING_LEVEL = "DEBUG"

    OPENAI_API_KEY = ""
    REDIS_IPV4_ADDRESS = "10.76.128.87"
  }
} 