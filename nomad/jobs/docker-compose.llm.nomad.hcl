# Nomad job equivalent to compose/docker-compose.llm.yml
# Extracted from docker-compose.nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "docker-compose.llm" {
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

  group "litellm-group" {
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
      
      port "litellm" { to = 4000 }
    }

    # LiteLLM
    task "litellm" {
      driver = "docker"

      config {
        image = "ghcr.io/berriai/litellm-database:main-stable"
        ports = ["litellm"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/litellm:/app/config:ro",
          "${var.root_path}/secrets:/run/secrets-src:ro"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /run/secrets && for f in /run/secrets-src/*.txt; do ln -sf \"$$f\" \"/run/secrets/$$(basename \"$$f\" .txt)\" 2>/dev/null || true; done && exec litellm --config /app/config/litellm_config.yaml --port 4000 --host 0.0.0.0"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "litellm"
          "traefik.enable" = "true"
          "homepage.group" = "AI"
          "homepage.name" = "Litellm"
          "homepage.icon" = "litellm.png"
          "homepage.href" = "https://litellm.${var.domain}/"
          "homepage.description" = "LLM gateway/router with provider failover, caching, rate limits, and analytics"
          "kuma.litellm.http.name" = "litellm.${node.unique.name}.${var.domain}"
          "kuma.litellm.http.url" = "https://litellm.${var.domain}"
          "kuma.litellm.http.interval" = "60"
        }
      }

      template {
        data = <<EOF
{{ range service "litellm-postgres" -}}
DATABASE_URL=postgresql://litellm:litellm@{{ .Address }}:{{ .Port }}/litellm
{{ end -}}
REDIS_HOST=redis
REDIS_PORT=6379
LITELLM_LOG={{ env "LITELLM_LOG" | or "INFO" }}
LITELLM_MASTER_KEY_FILE=/run/secrets/litellm-master-key
LITELLM_MODE={{ env "LITELLM_MODE" | or "PRODUCTION" }}
UI_USERNAME={{ env "LITELLM_UI_USERNAME" | or "admin" }}
UI_PASSWORD_FILE=/run/secrets/litellm-master-key
POSTGRES_USER=litellm
POSTGRES_PASSWORD=litellm
POSTGRES_DB=litellm
ANTHROPIC_API_KEY_FILE=/run/secrets/anthropic-api-key
OPENAI_API_KEY_FILE=/run/secrets/openai-api-key
OPENROUTER_API_KEY_FILE=/run/secrets/openrouter-api-key
GROQ_API_KEY_FILE=/run/secrets/groq-api-key
DEEPSEEK_API_KEY_FILE=/run/secrets/deepseek-api-key
GEMINI_API_KEY_FILE=/run/secrets/gemini-api-key
MISTRAL_API_KEY_FILE=/run/secrets/mistral-api-key
PERPLEXITY_API_KEY_FILE=/run/secrets/perplexity-api-key
REPLICATE_API_KEY_FILE=/run/secrets/replicate-api-key
SAMBANOVA_API_KEY_FILE=/run/secrets/sambanova-api-key
TOGETHERAI_API_KEY_FILE=/run/secrets/togetherai-api-key
HF_TOKEN_FILE=/run/secrets/hf-token
LANGCHAIN_API_KEY_FILE=/run/secrets/langchain-api-key
SERPAPI_API_KEY_FILE=/run/secrets/serpapi-api-key
SEARCH1API_KEY_FILE=/run/secrets/search1api-key
UPSTAGE_API_KEY_FILE=/run/secrets/upstage-api-key
JINA_API_KEY_FILE=/run/secrets/jina-api-key
KAGI_API_KEY_FILE=/run/secrets/kagi-api-key
GLAMA_API_KEY_FILE=/run/secrets/glama-api-key
EOF
        destination = "secrets/litellm.env"
        env         = true
      }

      resources {
        cpu        = 1000
        memory     = 2048
        memory_max = 4096
      
      }

      service {

        name = "litellm"
        port = "litellm"
        tags = [
          "litellm",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.litellm.rule=Host(`litellm.${var.domain}`) || Host(`litellm.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.litellm.loadbalancer.server.port=4000"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget -qO- http://127.0.0.1:4000/health/liveliness > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }
  group "litellm-postgres-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "litellm_postgres" { to = 5432 }
    }

    # LiteLLM PostgreSQL
    task "litellm-postgres" {
      driver = "docker"

      config {
        image = "docker.io/postgres:16.3-alpine3.20"
        ports = ["litellm_postgres"]
        volumes = [
          "${var.config_path}/litellm/pgdata:/var/lib/postgresql/data"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "litellm-postgres"
        }
      }

      env {
        TZ                = var.tz
        POSTGRES_DB       = "litellm"
        POSTGRES_PASSWORD = "litellm"
        POSTGRES_USER     = "litellm"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "litellm-postgres"
        port = "litellm_postgres"
        tags = [
          "litellm-postgres",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/pg_isready"
          args     = ["-h", "localhost", "-U", "litellm", "-d", "litellm"]
          interval = "5s"
          timeout  = "5s"
        }
      }
    }
  }
  group "mcpo-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "mcpo" { to = 8000 }
    }

    # MCPO
    task "mcpo" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/mcpo:main"
        ports = ["mcpo"]
        args = [
          "--api-key", "${var.mcpo_api_key}",
          "--host", "0.0.0.0",
          "--port", "8000",
          "--cors-allow-origins", "*",
          "--config", "/local/mcp_servers.json"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "mcpo"
        }
      }

      # MCP servers configuration
      template {
        data = <<EOF
{
  "mcpServers": {
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "${var.firecrawl_api_key}",
        "FIRECRAWL_API_URL": "https://firecrawl-api.${var.domain}"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "{{ env "GITHUB_TOKEN" | or "" }}"
      }
    }
  }
}
EOF
        destination = "local/mcp_servers.json"
      }

      env {
        TZ           = var.tz
        MCPO_API_KEY = var.mcpo_api_key
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 0
      
      }

      service {

        name = "mcpo"
        port = "mcpo"
        tags = [
          "mcpo",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.mcpo.middlewares=nginx-auth@file",
          "traefik.http.routers.mcpo.rule=Host(`mcpo.${var.domain}`) || Host(`mcpo.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.mcpo.loadbalancer.server.port=8000"
        ]

        check {
          type     = "http"
          path     = "/openapi.json"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "open-webui-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "open_webui" { to = 8080 }
    }

    # Open WebUI
    task "open-webui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["open_webui"]
        command = "bash"
        args    = ["start.sh"]
        work_dir = "/app/backend"
        volumes = [
          "${var.config_path}/open-webui/uploads:/app/backend/data/uploads",
          "${var.config_path}/open-webui/vector_db:/app/backend/data/vector_db:rw",
          "${var.config_path}/open-webui/webui.db:/app/backend/data/webui.db:rw"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "open-webui"
        }
      }

      env {
        TZ                                      = var.tz
        ENABLE_ADMIN_EXPORT                     = "True"
        ENABLE_ADMIN_CHAT_ACCESS                = "True"
        BYPASS_MODEL_ACCESS_CONTROL             = "True"
        ENV                                     = "prod"
        ENABLE_PERSISTENT_CONFIG                = "True"
        PORT                                    = "8080"
        ENABLE_REALTIME_CHAT_SAVE               = "True"
        WEBUI_BUILD_HASH                        = "dev-build"
        AIOHTTP_CLIENT_TIMEOUT                  = "300"
        AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST       = "10"
        AIOHTTP_CLIENT_TIMEOUT_OPENAI_MODEL_LIST = "10"
        DATA_DIR                                = "./data"
        FRONTEND_BUILD_DIR                      = "../build"
        STATIC_DIR                              = "./static"
        OLLAMA_BASE_URL                         = "/ollama"
        USE_OLLAMA_DOCKER                       = "false"
        K8S_FLAG                                = "False"
        ENABLE_FORWARD_USER_INFO_HEADERS        = "False"
        WEBUI_SESSION_COOKIE_SAME_SITE          = "lax"
        WEBUI_SESSION_COOKIE_SECURE             = "False"
        WEBUI_AUTH_COOKIE_SAME_SITE             = "lax"
        WEBUI_AUTH_COOKIE_SECURE                = "False"
        WEBUI_AUTH                              = "True"
        WEBUI_SECRET_KEY                        = var.open_webui_secret_key
        ENABLE_VERSION_UPDATE_CHECK             = "True"
        OFFLINE_MODE                            = "False"
        RESET_CONFIG_ON_START                   = "False"
        SAFE_MODE                               = "False"
        CORS_ALLOW_ORIGIN                       = "*"
        RAG_EMBEDDING_MODEL_TRUST_REMOTE_CODE   = "True"
        RAG_RERANKING_MODEL_TRUST_REMOTE_CODE   = "True"
        RAG_EMBEDDING_MODEL_AUTO_UPDATE         = "True"
        RAG_RERANKING_MODEL_AUTO_UPDATE         = "True"
        VECTOR_DB                               = "chroma"
        TIKTOKEN_CACHE_DIR                      = "/app/backend/data/cache/tiktoken"
        RAG_EMBEDDING_OPENAI_BATCH_SIZE         = "1"
        DOCKER                                  = "true"
        HOME                                    = "/root"
        HF_HOME                                 = "/app/backend/data/cache/embedding/models"
        SENTENCE_TRANSFORMERS_HOME              = "/app/backend/data/cache/embedding/models"
        USE_CUDA_DOCKER_VER                     = "cu128"
        USE_EMBEDDING_MODEL_DOCKER              = "sentence-transformers/all-MiniLM-L6-v2"
        ANONYMIZED_TELEMETRY                    = "false"
        DO_NOT_TRACK                            = "true"
        SCARF_NO_ANALYTICS                      = "true"
      }

      resources {
        cpu        = 400
        memory     = 1024
        memory_max = 1536
      
      }

      service {

        name = "open-webui"
        port = "open_webui"
        tags = [
          "open-webui",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.open-webui.rule=Host(`open-webui.${var.domain}`) || Host(`open-webui.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.open-webui.loadbalancer.server.port=8080"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "5s"
          timeout  = "30s"
        }
      }
    }
  }
  group "gptr-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "gptr_nginx" { to = 3000 }
      port "gptr_nextjs" { to = 3001 }
      port "gptr_static" { to = 8000 }
      port "gptr_mcp" { to = 8080 }
    }

    # GPTR (AI Research Wizard)
    task "gptr" {
      driver = "docker"

      config {
        image = "docker.io/bolabaden/ai-researchwizard-aio-fullstack:master"
        ports = ["gptr_nginx", "gptr_nextjs", "gptr_static", "gptr_mcp"]
        tty = true
        interactive = true
        volumes = [
          "${var.config_path}/gptr/logs:/usr/src/app/logs",
          "${var.config_path}/gptr/outputs:/usr/src/app/outputs",
          "${var.config_path}/gptr/reports:/usr/src/app/reports"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "gptr"
        }
      }

      template {
        data = <<EOF
ANTHROPIC_API_KEY=${var.anthropic_api_key}
BRAVE_API_KEY={{ env "BRAVE_API_KEY" | or "" }}
DEEPSEEK_API_KEY={{ env "DEEPSEEK_API_KEY" | or "" }}
EXA_API_KEY={{ env "EXA_API_KEY" | or "" }}
FIRECRAWL_API_KEY=${var.firecrawl_api_key}
FIRE_CRAWL_API_KEY=${var.firecrawl_api_key}
GEMINI_API_KEY={{ env "GEMINI_API_KEY" | or "" }}
GLAMA_API_KEY={{ env "GLAMA_API_KEY" | or "" }}
GROQ_API_KEY={{ env "GROQ_API_KEY" | or "" }}
HF_TOKEN={{ env "HF_TOKEN" | or "" }}
HUGGINGFACE_ACCESS_TOKEN={{ env "HUGGINGFACE_ACCESS_TOKEN" | or "" }}
HUGGINGFACE_API_TOKEN={{ env "HF_TOKEN" | or "" }}
LANGCHAIN_API_KEY={{ env "LANGCHAIN_API_KEY" | or "" }}
LANGSMITH_API_KEY={{ env "LANGCHAIN_API_KEY" | or "" }}
MISTRAL_API_KEY={{ env "MISTRAL_API_KEY" | or "" }}
MISTRALAI_API_KEY={{ env "MISTRAL_API_KEY" | or "" }}
OPENAI_API_KEY=${var.openai_api_key}
OPENROUTER_API_KEY={{ env "OPENROUTER_API_KEY" | or "" }}
PERPLEXITY_API_KEY={{ env "PERPLEXITY_API_KEY" | or "" }}
PERPLEXITYAI_API_KEY={{ env "PERPLEXITY_API_KEY" | or "" }}
REPLICATE_API_KEY={{ env "REPLICATE_API_KEY" | or "" }}
REVID_API_KEY={{ env "REVID_API_KEY" | or "" }}
SAMBANOVA_API_KEY={{ env "SAMBANOVA_API_KEY" | or "" }}
SEARCH1API_KEY={{ env "SEARCH1API_KEY" | or "" }}
SERPAPI_API_KEY={{ env "SERPAPI_API_KEY" | or "" }}
TAVILY_API_KEY={{ env "TAVILY_API_KEY" | or "" }}
TOGETHERAI_API_KEY={{ env "TOGETHERAI_API_KEY" | or "" }}
UNIFY_API_KEY={{ env "UNIFY_API_KEY" | or "" }}
UPSTAGE_API_KEY={{ env "UPSTAGE_API_KEY" | or "" }}
UPSTAGEAI_API_KEY={{ env "UPSTAGE_API_KEY" | or "" }}
YOU_API_KEY={{ env "YOU_API_KEY" | or "" }}
CHOKIDAR_USEPOLLING=true
LOGGING_LEVEL=DEBUG
NEXT_PUBLIC_GPTR_API_URL=https://gptr.${var.domain}
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
EOF
        destination = "secrets/gptr.env"
        env         = true
      }

      resources {
        cpu        = 400
        memory     = 1024
        memory_max = 1536
      
      }

      service {

        name = "gptr"
        port = "gptr_static"
        tags = [
          "gptr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.gptr-legacy.service=gptr-legacy@consulcatalog",
          "traefik.http.routers.gptr-legacy.rule=Host(`gptr.${var.domain}`) || Host(`gptr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.gptr-legacy.loadbalancer.server.port=8000"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "(wget -qO- http://127.0.0.1:3000 && wget -qO- http://127.0.0.1:8000) || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "qdrant-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "qdrant" { to = 6333 }
    }

    # 🔹🔹 Qdrant 🔹🔹
    task "qdrant" {
      driver = "docker"

      config {
        image = "docker.io/qdrant/qdrant"
        ports = ["qdrant"]
        volumes = [
          "${var.config_path}/qdrant/storage:/qdrant/storage"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "qdrant"
        }
      }

      env {
        QDRANT_STORAGE_PATH      = "/qdrant/storage"
        QDRANT_STORAGE_TYPE      = "disk"
        QDRANT_STORAGE_DISK_PATH = "/qdrant/storage"
        QDRANT_STORAGE_DISK_TYPE = "disk"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      }

      service {
        name = "qdrant"
        port = "qdrant"
        tags = [
          "traefik.enable=true",
          "traefik.http.services.qdrant.loadbalancer.server.port=6333",
          "homepage.group=AI",
          "homepage.name=Qdrant",
          "homepage.icon=qdrant.png",
          "homepage.href=https://qdrant.${var.domain}",
          "homepage.description=Qdrant is a vector database for storing and querying vectors."
        ]
      }
    }
  }
  group "mcp-proxy-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "mcp_proxy" { to = 9090 }
    }

    # MCP Proxy
    task "mcp-proxy" {
      driver = "docker"

      config {
        image = "ghcr.io/tbxark/mcp-proxy"
        ports = ["mcp_proxy"]
        args = [
          "--config", "/local/config.json",
          "-expand-env"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "mcp-proxy"
        }
      }

      template {
        data = <<EOF
{
  "mcpProxy": {
    "baseURL": "https://mcp.${var.domain}",
    "addr": ":9090",
    "name": "MCP Proxy",
    "version": "1.0.0",
    "type": "streamable-http",
    "options": {
      "panicIfInvalid": false,
      "logEnabled": true,
      "authTokens": []
    }
  },
  "mcpServers": {}
}
EOF
        destination = "local/config.json"
      }

      resources {
        cpu        = 250
        memory     = 512
        memory_max = 0
      }

      service {
        name = "mcp-proxy"
        port = "mcp_proxy"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.mcp-proxy.rule=Host(`mcp.${var.domain}`) || Host(`mcp.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.mcp-proxy.loadbalancer.server.port=9090",
          "homepage.group=MCP",
          "homepage.name=MCP Proxy",
          "homepage.icon=mcp-proxy.png",
          "homepage.href=https://mcp.${var.domain}",
          "homepage.description=MCP Proxy is a tool for proxying MCP servers."
        ]
      }
    }
  }
}
