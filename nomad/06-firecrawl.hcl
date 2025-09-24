# Firecrawl Web Scraping Services
# This job handles Firecrawl API and related web scraping services

job "firecrawl" {
  datacenters = ["dc1"]
  type        = "service"

  # Playwright service for browser automation
  group "playwright-service" {
    count = 1

    network {
      mode = "bridge"
      port "playwright" {
        static = 3000
      }
    }

    service {
      name = "playwright-service"
      port = "playwright"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "playwright-service" {
      driver = "docker"

      config {
        image = "mendableai/playwright-service:latest"
        ports = ["playwright"]
        volumes = [
          "/tmp/.X11-unix:/tmp/.X11-unix:rw"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # Firecrawl API service
  group "firecrawl-api" {
    count = 1

    network {
      mode = "bridge"
      port "firecrawl-api" {
        static = 8080
      }
    }

    service {
      name = "firecrawl-api"
      port = "firecrawl-api"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.firecrawl-api.rule=Host(`firecrawl-api.${var.domain}`)",
        "traefik.http.services.firecrawl-api.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "firecrawl-api" {
      driver = "docker"

      config {
        image = "mendableai/firecrawl:latest"
        ports = ["firecrawl-api"]
        volumes = [
          "${var.config_path}/firecrawl:/app/config:rw"
        ]
      }

      env {
        LOAD_SHEDDING_ENABLED        = "false"
        DISABLE_RESOURCE_GUARD       = "1"
        CPU_LOAD_THRESHOLD          = "0.9"
        MEM_USAGE_THRESHOLD         = "0.9"
        NODE_OPTIONS                = "--max-old-space-size=16384"
        PLAYWRIGHT_MICROSERVICE_URL = var.playwright_host
        REDIS_URL                   = "redis://${var.redis_hostname}:${var.redis_port}"
        REDIS_RATE_LIMIT_URL        = "redis://${var.redis_hostname}:${var.redis_port}"
        USE_DB_AUTHENTICATION       = var.firecrawl_use_db_authentication
        SUPABASE_ANON_TOKEN         = var.firecrawl_supabase_anon_token
        SUPABASE_URL                = var.firecrawl_supabase_url
        SUPABASE_SERVICE_TOKEN      = var.firecrawl_supabase_service_token
        OPENAI_API_KEY              = var.litellm_master_key
        OPENAI_BASE_URL             = var.litellm_host
        MODEL_NAME                  = var.firecrawl_model_name
        MODEL_EMBEDDING_NAME        = var.firecrawl_model_embedding_name
        OLLAMA_BASE_URL             = var.firecrawl_ollama_base_url
        PROXY_USERNAME              = var.firecrawl_proxy_username
        PROXY_PASSWORD              = var.firecrawl_proxy_password
        SLACK_WEBHOOK_URL           = var.slack_webhook_url
        POSTHOG_API_KEY             = var.posthog_api_key
        POSTHOG_HOST                = var.posthog_host
        SELF_HOSTED_WEBHOOK_URL     = var.firecrawl_self_hosted_webhook_url
        SERPER_API_KEY              = var.firecrawl_serper_api_key
        SEARCHAPI_API_KEY           = var.firecrawl_searchapi_api_key
        SEARXNG_ENDPOINT            = var.firecrawl_searxng_endpoint
        SEARXNG_ENGINES             = var.firecrawl_searxng_engines
        SEARXNG_CATEGORIES          = var.firecrawl_searxng_categories
        BULL_AUTH_KEY               = var.firecrawl_bull_auth_key
        TEST_API_KEY                = var.firecrawl_test_api_key
        LOGGING_LEVEL               = var.firecrawl_logging_level
        PROXY_SERVER                = var.firecrawl_proxy_server
        TZ                          = var.tz
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # Firecrawl worker service
  group "firecrawl-worker" {
    count = 2

    network {
      mode = "bridge"
      port "firecrawl-worker" {
        static = 8081
      }
    }

    service {
      name = "firecrawl-worker"
      port = "firecrawl-worker"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "firecrawl-worker" {
      driver = "docker"

      config {
        image = "mendableai/firecrawl:latest"
        ports = ["firecrawl-worker"]
        volumes = [
          "${var.config_path}/firecrawl:/app/config:rw"
        ]
        command = ["npm", "run", "worker"]
      }

      env {
        LOAD_SHEDDING_ENABLED        = "false"
        DISABLE_RESOURCE_GUARD       = "1"
        CPU_LOAD_THRESHOLD          = "0.9"
        MEM_USAGE_THRESHOLD         = "0.9"
        NODE_OPTIONS                = "--max-old-space-size=16384"
        PLAYWRIGHT_MICROSERVICE_URL = var.playwright_host
        REDIS_URL                   = "redis://${var.redis_hostname}:${var.redis_port}"
        REDIS_RATE_LIMIT_URL        = "redis://${var.redis_hostname}:${var.redis_port}"
        USE_DB_AUTHENTICATION       = var.firecrawl_use_db_authentication
        SUPABASE_ANON_TOKEN         = var.firecrawl_supabase_anon_token
        SUPABASE_URL                = var.firecrawl_supabase_url
        SUPABASE_SERVICE_TOKEN      = var.firecrawl_supabase_service_token
        OPENAI_API_KEY              = var.litellm_master_key
        OPENAI_BASE_URL             = var.litellm_host
        MODEL_NAME                  = var.firecrawl_model_name
        MODEL_EMBEDDING_NAME        = var.firecrawl_model_embedding_name
        OLLAMA_BASE_URL             = var.firecrawl_ollama_base_url
        PROXY_USERNAME              = var.firecrawl_proxy_username
        PROXY_PASSWORD              = var.firecrawl_proxy_password
        SLACK_WEBHOOK_URL           = var.slack_webhook_url
        POSTHOG_API_KEY             = var.posthog_api_key
        POSTHOG_HOST                = var.posthog_host
        SELF_HOSTED_WEBHOOK_URL     = var.firecrawl_self_hosted_webhook_url
        SERPER_API_KEY              = var.firecrawl_serper_api_key
        SEARCHAPI_API_KEY           = var.firecrawl_searchapi_api_key
        SEARXNG_ENDPOINT            = var.firecrawl_searxng_endpoint
        SEARXNG_ENGINES             = var.firecrawl_searxng_engines
        SEARXNG_CATEGORIES          = var.firecrawl_searxng_categories
        BULL_AUTH_KEY               = var.firecrawl_bull_auth_key
        TEST_API_KEY                = var.firecrawl_test_api_key
        LOGGING_LEVEL               = var.firecrawl_logging_level
        PROXY_SERVER                = var.firecrawl_proxy_server
        TZ                          = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }
}
