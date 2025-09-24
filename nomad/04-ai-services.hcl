# AI Services
# This job handles AI-related services including Open WebUI, LiteLLM, and GPTR

job "ai-services" {
  datacenters = ["dc1"]
  type        = "service"

  # LiteLLM PostgreSQL database
  group "litellm-postgres" {
    count = 1

    network {
      mode = "bridge"
      port "postgres" {
        static = 5432
      }
    }

    service {
      name = "litellm-postgres"
      port = "postgres"

      tags = ["internal", "database"]

      check {
        type     = "script"
        command  = "/usr/bin/pg_isready"
        args     = ["-h", "localhost", "-U", var.litellm_postgres_user, "-d", var.litellm_postgres_db]
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "litellm-postgres" {
      driver = "docker"

      config {
        image = "postgres:16.3-alpine3.20"
        ports = ["postgres"]
        volumes = [
          "${var.config_path}/litellm/pgdata:/var/lib/postgresql/data:rw"
        ]
      }

      env {
        POSTGRES_DB       = var.litellm_postgres_db
        POSTGRES_PASSWORD = var.litellm_postgres_password
        POSTGRES_USER     = var.litellm_postgres_user
        TZ                = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # LiteLLM API gateway
  group "litellm" {
    count = 1

    network {
      mode = "bridge"
      port "litellm" {
        static = 4000
      }
    }

    service {
      name = "litellm"
      port = "litellm"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.litellm.rule=Host(`litellm.${var.domain}`)",
        "traefik.http.services.litellm.loadbalancer.server.port=4000"
      ]

      check {
        type     = "http"
        path     = "/health/liveliness"
        interval = "30s"
        timeout  = "15s"
      }
    }

    task "litellm" {
      driver = "docker"

      config {
        image = "ghcr.io/berriai/litellm-database:main-stable"
        ports = ["litellm"]
        volumes = [
          "${var.config_path}/litellm:/app/config:ro"
        ]
        command = [
          "--config", "/app/config/litellm_config.yaml",
          "--port", "4000",
          "--host", "0.0.0.0"
        ]
      }

      env {
        LITELLM_LOG                        = var.litellm_log
        LITELLM_MODE                       = var.litellm_mode
        UI_USERNAME                        = var.litellm_ui_username
        UI_PASSWORD                        = var.litellm_master_key
        DATABASE_URL                       = "postgresql://${var.litellm_postgres_user}:${var.litellm_postgres_password}@${var.litellm_postgres_hostname}:5432/${var.litellm_postgres_db}"
        REDIS_HOST                         = var.redis_hostname
        REDIS_PORT                         = var.redis_port
        POSTGRES_USER                      = var.litellm_postgres_user
        POSTGRES_PASSWORD                  = var.litellm_postgres_password
        POSTGRES_DB                        = var.litellm_postgres_db
        VOYAGE_API_KEY                     = var.voyage_api_key
        AI21_API_KEY                       = var.ai21_api_key
        ANTHROPIC_API_KEY                  = var.anthropic_api_key
        APIFY_API_TOKEN                    = var.apify_api_token
        APIPIE_API_KEY                     = var.apipie_api_key
        ARLIAI_API_KEY                     = var.arliai_api_key
        AWANLLM_API_KEY                    = var.awanllm_api_key
        BASETEN_API_KEY                    = var.baseten_api_key
        BITO_ACCESS_KEY                    = var.bito_access_key
        BRAVE_API_KEY                      = var.brave_api_key
        CEREBRIUMAI_API_KEY                = var.cerebriumai_api_key
        DEEPINFRA_API_KEY                  = var.deepinfra_api_key
        DEEPGRAM_API_KEY                   = var.deepgram_api_key
        DEEPSEEK_API_KEY                   = var.deepseek_api_key
        DOCKER_TOKEN                       = var.docker_token
        DOCKERHUB_TOKEN                    = var.dockerhub_token
        EVERART_API_KEY                    = var.everart_api_key
        EXA_API_KEY                        = var.exa_api_key
        FOREFRONTAI_API_KEY                = var.forefrontai_api_key
        GEMINI_API_KEY                     = var.gemini_api_key
        GLAMA_API_KEY                      = var.glama_api_key
        GROK_API_KEY                       = var.grok_api_key
        GROQ_API_KEY                       = var.groq_api_key
        HF_TOKEN                           = var.hf_token
        HUGGINGFACE_ACCESS_TOKEN           = var.huggingface_access_token
        HUGGINGFACE_API_TOKEN              = var.huggingface_api_token
        JINA_API_KEY                       = var.jina_api_key
        KAGI_API_KEY                       = var.kagi_api_key
        KLUSTER_API_KEY                    = var.kluster_api_key
        LANGCHAIN_API_KEY                  = var.langchain_api_key
        LANGSMITH_API_KEY                  = var.langsmith_api_key
        LITELLM_MASTER_KEY                 = var.litellm_master_key
        MISTRAL_API_KEY                    = var.mistral_api_key
        MISTRALAI_API_KEY                  = var.mistralai_api_key
        OPENAI_API_KEY                     = var.openai_api_key
        OPENROUTER_API_KEY                 = var.openrouter_api_key
        PERPLEXITY_API_KEY                 = var.perplexity_api_key
        PERPLEXITYAI_API_KEY               = var.perplexityai_api_key
        REPLICATE_API_KEY                  = var.replicate_api_key
        SAMBANOVA_API_KEY                  = var.sambanova_api_key
        SEARCH1API_KEY                     = var.search1api_key
        SERPAPI_API_KEY                    = var.serpapi_api_key
        SMITHERY_API_KEY                   = var.smithery_api_key
        TANDOOR_SECRET_KEY                 = var.tandoor_secret_key
        TODOIST_API_KEY                    = var.todoist_api_key
        TOGETHERAI_API_KEY                 = var.togetherai_api_key
        UNIFY_API_KEY                      = var.unify_api_key
        UPSTAGE_API_KEY                    = var.upstage_api_key
        UPSTAGEAI_API_KEY                  = var.upstageai_api_key
        VEYRAX_API_KEY                     = var.veyrax_api_key
        YANDEX_API_KEY                     = var.yandex_api_key
        YOU_API_KEY                        = var.you_api_key
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # MCPO (Model Context Protocol Orchestrator)
  group "mcpo" {
    count = 1

    network {
      mode = "bridge"
      port "mcpo" {
        static = 8000
      }
    }

    service {
      name = "mcpo"
      port = "mcpo"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.mcpo.middlewares=nginx-auth@file",
        "traefik.http.routers.mcpo.rule=Host(`mcpo.${var.domain}`)",
        "traefik.http.services.mcpo.loadbalancer.server.port=8000"
      ]

      check {
        type     = "http"
        path     = "/openapi.json"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "mcpo" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/mcpo:main"
        ports = ["mcpo"]
        volumes = [
          "${var.config_path}/mcpo/mcp_servers.json:/app/config/mcp_servers.json:ro"
        ]
        command = [
          "--api-key", var.mcpo_api_key,
          "--host", "0.0.0.0",
          "--port", "8000",
          "--cors-allow-origins", "*",
          "--config", "/app/config/mcp_servers.json"
        ]
      }

      env {
        MCPO_API_KEY = var.mcpo_api_key
        TZ           = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # Open WebUI interface
  group "open-webui" {
    count = 1

    network {
      mode = "bridge"
      port "webui" {
        static = 8080
      }
    }

    service {
      name = "open-webui"
      port = "webui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.open-webui.rule=Host(`open-webui.${var.domain}`)",
        "traefik.http.services.open-webui.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "30s"
      }
    }

    task "open-webui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["webui"]
        volumes = [
          "${var.config_path}/open-webui/uploads:/app/backend/data/uploads:rw",
          "${var.config_path}/open-webui/vector_db:/app/backend/data/vector_db:rw",
          "${var.config_path}/open-webui/webui.db:/app/backend/data/webui.db:rw"
        ]
        command = ["bash", "start.sh"]
        working_dir = "/app/backend"
      }

      env {
        ENABLE_ADMIN_EXPORT                   = "True"
        ENABLE_ADMIN_CHAT_ACCESS              = "True"
        BYPASS_MODEL_ACCESS_CONTROL           = "True"
        ENV                                   = "prod"
        ENABLE_PERSISTENT_CONFIG              = "True"
        PORT                                  = var.open_webui_port
        ENABLE_REALTIME_CHAT_SAVE             = "True"
        WEBUI_BUILD_HASH                      = "dev-build"
        AIOHTTP_CLIENT_TIMEOUT                = "300"
        AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST     = "10"
        AIOHTTP_CLIENT_TIMEOUT_OPENAI_MODEL_LIST = "10"
        DATA_DIR                              = "./data"
        FRONTEND_BUILD_DIR                    = "../build"
        STATIC_DIR                            = "./static"
        OLLAMA_BASE_URL                       = "/ollama"
        USE_OLLAMA_DOCKER                     = "false"
        K8S_FLAG                              = "False"
        ENABLE_FORWARD_USER_INFO_HEADERS      = "False"
        WEBUI_SESSION_COOKIE_SAME_SITE        = "lax"
        WEBUI_SESSION_COOKIE_SECURE           = "False"
        WEBUI_AUTH_COOKIE_SAME_SITE           = "lax"
        WEBUI_AUTH_COOKIE_SECURE              = "False"
        WEBUI_AUTH                            = var.webui_auth
        WEBUI_SECRET_KEY                      = var.open_webui_secret_key
        ENABLE_VERSION_UPDATE_CHECK           = "True"
        OFFLINE_MODE                          = "False"
        RESET_CONFIG_ON_START                 = "False"
        SAFE_MODE                             = "False"
        CORS_ALLOW_ORIGIN                     = var.open_webui_cors_allowed_origin
        RAG_EMBEDDING_MODEL_TRUST_REMOTE_CODE = "True"
        RAG_RERANKING_MODEL_TRUST_REMOTE_CODE = "True"
        RAG_EMBEDDING_MODEL_AUTO_UPDATE       = "True"
        RAG_RERANKING_MODEL_AUTO_UPDATE       = "True"
        VECTOR_DB                             = "chroma"
        TIKTOKEN_CACHE_DIR                    = "/app/backend/data/cache/tiktoken"
        RAG_EMBEDDING_OPENAI_BATCH_SIZE       = "1"
        DOCKER                                = "true"
        HOME                                  = "/root"
        HF_HOME                               = "/app/backend/data/cache/embedding/models"
        SENTENCE_TRANSFORMERS_HOME            = "/app/backend/data/cache/embedding/models"
        USE_CUDA_DOCKER_VER                   = "cu128"
        USE_EMBEDDING_MODEL_DOCKER            = "sentence-transformers/all-MiniLM-L6-v2"
        ANONYMIZED_TELEMETRY                  = "false"
        DO_NOT_TRACK                          = "true"
        SCARF_NO_ANALYTICS                    = "true"
        TZ                                    = var.tz
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # GPTR (AI Research Wizard)
  group "gptr" {
    count = 1

    network {
      mode = "bridge"
      port "gptr-nextjs" {
        static = 3000
      }
      port "gptr-legacy" {
        static = 8000
      }
      port "gptr-mcp" {
        static = 8080
      }
    }

    service {
      name = "gptr"
      port = "gptr-legacy"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.gptr-nextjs.service=gptr-nextjs@docker",
        "traefik.http.routers.gptr-nextjs.rule=Host(`gptr-nextjs.${var.domain}`)",
        "traefik.http.services.gptr-nextjs.loadbalancer.server.port=3000",
        "traefik.http.routers.gptr-legacy.service=gptr-legacy@docker",
        "traefik.http.routers.gptr-legacy.rule=Host(`gptr.${var.domain}`)",
        "traefik.http.services.gptr-legacy.loadbalancer.server.port=8000",
        "traefik.http.routers.gptr-mcp.service=gptr-mcp@docker",
        "traefik.http.routers.gptr-mcp.rule=Host(`gptr-mcp.${var.domain}`)",
        "traefik.http.services.gptr-mcp.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "gptr" {
      driver = "docker"

      config {
        image = "docker.io/bolabaden/ai-researchwizard-aio-fullstack:master"
        ports = ["gptr-nextjs", "gptr-legacy", "gptr-mcp"]
        volumes = [
          "${var.config_path}/gptr/logs:/usr/src/app/logs:rw",
          "${var.config_path}/gptr/outputs:/usr/src/app/outputs:rw",
          "${var.config_path}/gptr/reports:/usr/src/app/reports:rw"
        ]
        stdin_open = true
      }

      env {
        ANTHROPIC_API_KEY            = var.anthropic_api_key
        BRAVE_API_KEY                = var.brave_api_key
        DEEPSEEK_API_KEY             = var.deepseek_api_key
        EXA_API_KEY                  = var.exa_api_key
        FIRECRAWL_API_KEY            = var.firecrawl_api_key
        FIRE_CRAWL_API_KEY           = var.fire_crawl_api_key
        GEMINI_API_KEY               = var.gemini_api_key
        GLAMA_API_KEY                = var.glama_api_key
        GROQ_API_KEY                 = var.groq_api_key
        HF_TOKEN                     = var.hf_token
        HUGGINGFACE_ACCESS_TOKEN     = var.huggingface_access_token
        HUGGINGFACE_API_TOKEN        = var.huggingface_api_token
        LANGCHAIN_API_KEY            = var.langchain_api_key
        MISTRAL_API_KEY              = var.mistral_api_key
        MISTRALAI_API_KEY            = var.mistralai_api_key
        OPENAI_API_KEY               = var.openai_api_key
        OPENROUTER_API_KEY           = var.openrouter_api_key
        PERPLEXITY_API_KEY           = var.perplexity_api_key
        PERPLEXITYAI_API_KEY         = var.perplexityai_api_key
        REPLICATE_API_KEY            = var.replicate_api_key
        REVID_API_KEY                = var.revid_api_key
        SAMBANOVA_API_KEY            = var.sambanova_api_key
        SEARCH1API_KEY               = var.search1api_key
        SERPAPI_API_KEY              = var.serpapi_api_key
        TAVILY_API_KEY               = var.tavily_api_key
        TOGETHERAI_API_KEY           = var.togetherai_api_key
        UNIFY_API_KEY                = var.unify_api_key
        UPSTAGE_API_KEY              = var.upstage_api_key
        UPSTAGEAI_API_KEY            = var.upstageai_api_key
        YOU_API_KEY                  = var.you_api_key
        CHOKIDAR_USEPOLLING          = var.chokidar_usepolling
        LOGGING_LEVEL                = var.gptr_logging_level
        NEXT_PUBLIC_GA_MEASUREMENT_ID = var.next_public_ga_measurement_id
        NEXT_PUBLIC_GPTR_API_URL     = "https://gptr.${var.domain}"
        LANGSMITH_TRACING            = var.langsmith_tracing
        LANGSMITH_ENDPOINT           = var.langsmith_endpoint
        LANGSMITH_API_KEY            = var.langsmith_api_key
        TZ                           = var.tz
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # Model Updater Service (runs on-demand)
  group "model-updater" {
    count = 0  # Disabled by default, run manually when needed

    network {
      mode = "bridge"
      port "model-updater" {
        static = 8080
      }
    }

    task "model-updater" {
      driver = "docker"

      config {
        image = "python:3.13-slim"
        command = ["python", "src/llm_fallbacks/generate_configs.py"]
        volumes = [
          "${var.config_path}/litellm:/app/config:rw"
        ]
      }

      env {
        OPENROUTER_API_KEY    = var.openrouter_api_key
        POSTGRES_PASSWORD     = var.litellm_postgres_password
        TZ                   = var.tz
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
