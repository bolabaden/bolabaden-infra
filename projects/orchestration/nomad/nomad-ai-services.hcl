job "media-stack-ai-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 60

  variable "tz" {
    type    = string
    default = "America/Chicago"
  }

  variable "config_path" {
    type    = string
    default = "./configs"
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

  variable "gpt_researcher_hostname" {
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

  variable "dash_ipv4_address" {
    type = string
  }

  variable "gpt_researcher_ipv4_address" {
    type = string
  }

  variable "lobechat_ipv4_address" {
    type = string
  }

  variable "code_demo_ipv4_address" {
    type = string
  }

  variable "whoami_ipv4_address" {
    type = string
  }

  variable "tinyauth_ipv4_address" {
    type = string
  }

  variable "watchtower_ipv4_address" {
    type = string
  }

  variable "traefik_error_pages_ipv4_address" {
    type = string
  }

  variable "speedtest_ipv4_address" {
    type = string
  }

  variable "homepage_ipv4_address" {
    type = string
  }

  variable "dozzle_ipv4_address" {
    type = string
  }

  variable "searxng_ipv4_address" {
    type = string
  }

  variable "code_dev_ipv4_address" {
    type = string
  }

  variable "flaresolverr_ipv4_address" {
    type = string
  }

  variable "nginx_auth_ipv4_address" {
    type = string
  }

  variable "puid" {
    type = string
  }

  variable "pgid" {
    type = string
  }

  variable "umask" {
    type = string
  }

  variable "lobechat_access_code" {
    type = string
  }

  group "ai-services" {
    count = 1

    network {
      mode = "bridge"
      port "gptr_frontend" {
        to = 3000
      }
      port "gptr_backend" {
        static = 8000
        to = 8000
      }
      port "lobechat" {
        to = 3210
      }
    }

    task "gpt-researcher" {
      driver = "docker"

      config {
        image = "th3w1zard1/ai-researchwizard:latest"
        hostname = "${NOMAD_META_GPT_RESEARCHER_HOSTNAME}"
        ports = ["gptr_frontend", "gptr_backend"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/gptr/logs:/usr/src/app/logs",
          "${NOMAD_META_CONFIG_PATH}/gptr/outputs:/usr/src/app/outputs",
          "${NOMAD_META_CONFIG_PATH}/gptr/reports:/usr/src/app/reports"
        ]
      }

      env {
        # AI API Keys
        ANTHROPIC_API_KEY = "${NOMAD_META_ANTHROPIC_API_KEY}"
        BRAVE_API_KEY = "${NOMAD_META_BRAVE_API_KEY}"
        DEEPSEEK_API_KEY = "${NOMAD_META_DEEPSEEK_API_KEY}"
        EXA_API_KEY = "${NOMAD_META_EXA_API_KEY}"
        FIRECRAWL_API_KEY = "${NOMAD_META_FIRECRAWL_API_KEY}"
        FIRE_CRAWL_API_KEY = "${NOMAD_META_FIRE_CRAWL_API_KEY}"
        GEMINI_API_KEY = "${NOMAD_META_GEMINI_API_KEY}"
        GLAMA_API_KEY = "${NOMAD_META_GLAMA_API_KEY}"
        GROQ_API_KEY = "${NOMAD_META_GROQ_API_KEY}"
        HF_TOKEN = "${NOMAD_META_HF_TOKEN}"
        HUGGINGFACE_ACCESS_TOKEN = "${NOMAD_META_HUGGINGFACE_ACCESS_TOKEN}"
        HUGGINGFACE_API_TOKEN = "${NOMAD_META_HUGGINGFACE_API_TOKEN}"
        LANGCHAIN_API_KEY = "${NOMAD_META_LANGCHAIN_API_KEY}"
        MISTRAL_API_KEY = "${NOMAD_META_MISTRAL_API_KEY}"
        MISTRALAI_API_KEY = "${NOMAD_META_MISTRALAI_API_KEY}"
        OPENAI_API_KEY = "${NOMAD_META_OPENAI_API_KEY}"
        OPENROUTER_API_KEY = "${NOMAD_META_OPENROUTER_API_KEY}"
        PERPLEXITY_API_KEY = "${NOMAD_META_PERPLEXITY_API_KEY}"
        PERPLEXITYAI_API_KEY = "${NOMAD_META_PERPLEXITYAI_API_KEY}"
        REPLICATE_API_KEY = "${NOMAD_META_REPLICATE_API_KEY}"
        REVID_API_KEY = "${NOMAD_META_REVID_API_KEY}"
        SAMBANOVA_API_KEY = "${NOMAD_META_SAMBANOVA_API_KEY}"
        SEARCH1API_KEY = "${NOMAD_META_SEARCH1API_KEY}"
        SERPAPI_API_KEY = "${NOMAD_META_SERPAPI_API_KEY}"
        TAVILY_API_KEY = "${NOMAD_META_TAVILY_API_KEY}"
        TOGETHERAI_API_KEY = "${NOMAD_META_TOGETHERAI_API_KEY}"
        UNIFY_API_KEY = "${NOMAD_META_UNIFY_API_KEY}"
        UPSTAGE_API_KEY = "${NOMAD_META_UPSTAGE_API_KEY}"
        UPSTAGEAI_API_KEY = "${NOMAD_META_UPSTAGEAI_API_KEY}"
        YOU_API_KEY = "${NOMAD_META_YOU_API_KEY}"
        
        # Application configuration
        CHOKIDAR_USEPOLLING = "true"
        LOGGING_LEVEL = "DEBUG"
        NEXT_PUBLIC_GA_MEASUREMENT_ID = "${NOMAD_META_NEXT_PUBLIC_GA_MEASUREMENT_ID}"
        NEXT_PUBLIC_GPTR_API_URL = "https://gptr.${NOMAD_META_DOMAIN}"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "gpt-researcher"
        port = "gptr_frontend"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.gptr.service=gptr",
          "traefik.http.routers.gptr.rule=Host(`gptr.${NOMAD_META_DOMAIN}`) || Host(`gptr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`gptr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.gptr.loadbalancer.server.port=3000",
          "traefik.http.routers.gptr-legacy.service=gptr-legacy",
          "traefik.http.routers.gptr-legacy.rule=Host(`gptr-legacy.${NOMAD_META_DOMAIN}`) || Host(`gptr-legacy.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`gptr-legacy.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.gptr-legacy.loadbalancer.server.port=8000"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "lobechat" {
      driver = "docker"

      config {
        image = "lobehub/lobe-chat:latest"
        hostname = "${NOMAD_META_LOBECHAT_HOSTNAME}"
        ports = ["lobechat"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/lobechat/host_config:/configs/lobechat/host_config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        ACCESS_CODE = "${NOMAD_META_LOBECHAT_ACCESS_CODE}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "lobechat"
        port = "lobechat"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.lobechat.middlewares=nginx-auth@file",
          "traefik.http.routers.lobechat.rule=Host(`lobechat.${NOMAD_META_DOMAIN}`) || Host(`lobechat.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`lobechat.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.lobechat.loadbalancer.server.port=3210",
          "homepage.group=AI",
          "homepage.name=Lobe Chat",
          "homepage.icon=lobechat.png",
          "homepage.href=https://lobechat.${NOMAD_META_DOMAIN}/",
          "homepage.description=A chatbot for your applications."
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
    
    # Service hostnames
    GPT_RESEARCHER_HOSTNAME = "gptr"
    LOBECHAT_HOSTNAME = "lobechat"
    
    # AI API Keys (set these in your environment or Nomad variables)
    ANTHROPIC_API_KEY = ""
    BRAVE_API_KEY = ""
    DEEPSEEK_API_KEY = ""
    EXA_API_KEY = ""
    FIRECRAWL_API_KEY = ""
    FIRE_CRAWL_API_KEY = ""
    GEMINI_API_KEY = ""
    GLAMA_API_KEY = ""
    GROQ_API_KEY = ""
    HF_TOKEN = ""
    HUGGINGFACE_ACCESS_TOKEN = ""
    HUGGINGFACE_API_TOKEN = ""
    LANGCHAIN_API_KEY = ""
    MISTRAL_API_KEY = ""
    MISTRALAI_API_KEY = ""
    OPENAI_API_KEY = ""
    OPENROUTER_API_KEY = ""
    PERPLEXITY_API_KEY = ""
    PERPLEXITYAI_API_KEY = ""
    REPLICATE_API_KEY = ""
    REVID_API_KEY = ""
    SAMBANOVA_API_KEY = ""
    SEARCH1API_KEY = ""
    SERPAPI_API_KEY = ""
    TAVILY_API_KEY = ""
    TOGETHERAI_API_KEY = ""
    UNIFY_API_KEY = ""
    UPSTAGE_API_KEY = ""
    UPSTAGEAI_API_KEY = ""
    YOU_API_KEY = ""
    
    # Application configuration
    NEXT_PUBLIC_GA_MEASUREMENT_ID = ""
    
    # LobeChat configuration
    LOBECHAT_ACCESS_CODE = "brunner56"
  }
} 