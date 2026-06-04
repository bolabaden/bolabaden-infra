package main

import (
	"fmt"

	infraconfig "cluster/infra/config"
)

// defineServicesLLM returns all services from compose/docker-compose.llm.yml
// Note: Some services are profile-based (model-updater, qdrant, mcp-proxy) and are excluded
func defineServicesLLM(config *Config) []Service {
	// Get canonical config for image name resolution
	var cfg *infraconfig.Config
	if config.NewConfig != nil {
		cfg = config.NewConfig
	} else {
		cfg = infraconfig.MigrateFromOldConfig(
			config.Domain,
			config.StackName,
			config.ConfigPath,
			config.SecretsPath,
			config.RootPath,
		)
	}
	
	domain := config.Domain
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// mcpo
	mcpoPort := getEnv("MCPO_PORT", "8000")
	services = append(services, Service{
		Name:          "mcpo",
		Image:         "ghcr.io/open-webui/mcpo:main",
		ContainerName: "mcpo",
		Hostname:      "mcpo",
		Networks:      []string{"backend", "publicnet"},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/llm/mcp_servers.json", configPath), Target: "/app/config/mcp_servers.json", Mode: "0444"},
		},
		Environment: map[string]string{
			"MCPO_API_KEY": getEnv("MCPO_API_KEY", ""),
		},
		Command: []string{
			"--api-key", getEnv("MCPO_API_KEY", ""),
			"--host", "0.0.0.0",
			"--port", mcpoPort,
			"--cors-allow-origins", "*",
			"--config", "/app/config/mcp_servers.json",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                     "true",
			"traefik.enable":                                      "true",
			"traefik.http.routers.mcpo.middlewares":               "nginx-auth@file",
			"traefik.http.routers.mcpo.rule":                      fmt.Sprintf("Host(`mcpo.%s`) || Host(`mcpo.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.mcpo.loadbalancer.server.port": mcpoPort,
			"homepage.group":                                      "MCPO",
			"homepage.name":                                       "MCPO",
			"homepage.icon":                                       "mcpo.png",
			"homepage.href":                                       fmt.Sprintf("https://mcpo.%s/", domain),
			"homepage.description":                                "MCP Orchestrator exposing model/context tools over the MCP protocol",
			"kuma.mcpo.http.name":                                 fmt.Sprintf("mcpo.%s.%s", tsHostname, domain),
			"kuma.mcpo.http.url":                                  fmt.Sprintf("https://mcpo.%s", domain),
			"kuma.mcpo.http.interval":                             "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("curl -f http://127.0.0.1:%s/openapi.json", mcpoPort)},
			Timeout:     "10s",
			StartPeriod: "40s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// litellm-postgres
	litellmPostgresHostname := getEnv("LITELLM_POSTGRES_HOSTNAME", "litellm-postgres")
	services = append(services, Service{
		Name:          "litellm-postgres",
		Image:         "docker.io/postgres:16-alpine",
		ContainerName: "litellm-postgres",
		Hostname:      litellmPostgresHostname,
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/litellm/pgdata", configPath), Target: "/var/lib/postgresql/data", Type: "bind"},
		},
		Environment: map[string]string{
			"POSTGRES_DB":       getEnv("LITELLM_POSTGRES_DB", "litellm"),
			"POSTGRES_PASSWORD": getEnv("LITELLM_POSTGRES_PASSWORD", "litellm"),
			"POSTGRES_USER":     getEnv("LITELLM_POSTGRES_USER", "litellm"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "pg_isready -h localhost -U $POSTGRES_USER -d $POSTGRES_DB"},
			Interval:    "5s",
			Timeout:     "5s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// litellm service (profile-based, included for completeness)
	litellmPort := getEnv("LITELLM_PORT", "4000")
	litellmSecrets := []SecretMount{
		{Source: fmt.Sprintf("%s/litellm-master-key.txt", secretsPath), Target: "/run/secrets/litellm-master-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/anthropic-api-key.txt", secretsPath), Target: "/run/secrets/anthropic-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/openai-api-key.txt", secretsPath), Target: "/run/secrets/openai-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/openrouter-api-key.txt", secretsPath), Target: "/run/secrets/openrouter-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/groq-api-key.txt", secretsPath), Target: "/run/secrets/groq-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/deepseek-api-key.txt", secretsPath), Target: "/run/secrets/deepseek-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/gemini-api-key.txt", secretsPath), Target: "/run/secrets/gemini-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/mistral-api-key.txt", secretsPath), Target: "/run/secrets/mistral-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/perplexity-api-key.txt", secretsPath), Target: "/run/secrets/perplexity-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/replicate-api-key.txt", secretsPath), Target: "/run/secrets/replicate-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/sambanova-api-key.txt", secretsPath), Target: "/run/secrets/sambanova-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/togetherai-api-key.txt", secretsPath), Target: "/run/secrets/togetherai-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/hf-token.txt", secretsPath), Target: "/run/secrets/hf-token", Mode: "0400"},
		{Source: fmt.Sprintf("%s/langchain-api-key.txt", secretsPath), Target: "/run/secrets/langchain-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/serpapi-api-key.txt", secretsPath), Target: "/run/secrets/serpapi-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/search1api-key.txt", secretsPath), Target: "/run/secrets/search1api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/upstage-api-key.txt", secretsPath), Target: "/run/secrets/upstage-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/jina-api-key.txt", secretsPath), Target: "/run/secrets/jina-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/kagi-api-key.txt", secretsPath), Target: "/run/secrets/kagi-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/glama-api-key.txt", secretsPath), Target: "/run/secrets/glama-api-key", Mode: "0400"},
	}
	services = append(services, Service{
		Name:          "litellm",
		Image:         "ghcr.io/berriai/litellm-database:main-stable",
		ContainerName: "litellm",
		Hostname:      "litellm",
		Networks:      []string{"backend", "publicnet"},
		Secrets:       litellmSecrets,
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/litellm", configPath), Target: "/app/config", Type: "bind", ReadOnly: true},
		},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/llm/litellm_config.yaml", configPath), Target: "/app/config/litellm_config.yaml", Mode: "0440"},
		},
		Environment: map[string]string{
			"LITELLM_LOG":             getEnv("LITELLM_LOG", "INFO"),
			"LITELLM_MASTER_KEY_FILE": "/run/secrets/litellm-master-key",
			"LITELLM_MODE":            getEnv("LITELLM_MODE", "PRODUCTION"),
			"UI_USERNAME":             getEnv("LITELLM_UI_USERNAME", "admin"),
			"UI_PASSWORD_FILE":        "/run/secrets/litellm-master-key",
			"DATABASE_URL":            fmt.Sprintf("postgresql://%s:%s@%s:5432/%s", getEnv("LITELLM_POSTGRES_USER", "litellm"), getEnv("LITELLM_POSTGRES_PASSWORD", "litellm"), getEnv("LITELLM_POSTGRES_HOSTNAME", "litellm-postgres"), getEnv("LITELLM_POSTGRES_DB", "litellm")),
			"REDIS_HOST":              getEnv("REDIS_HOSTNAME", "redis"),
			"REDIS_PORT":              getEnv("REDIS_PORT", "6379"),
			"POSTGRES_USER":           getEnv("LITELLM_POSTGRES_USER", "litellm"),
			"POSTGRES_PASSWORD":       getEnv("LITELLM_POSTGRES_PASSWORD", "litellm"),
			"POSTGRES_DB":             getEnv("LITELLM_POSTGRES_DB", "litellm"),
			"ANTHROPIC_API_KEY_FILE":  "/run/secrets/anthropic-api-key",
			"OPENAI_API_KEY_FILE":     "/run/secrets/openai-api-key",
			"OPENROUTER_API_KEY_FILE": "/run/secrets/openrouter-api-key",
			"GROQ_API_KEY_FILE":       "/run/secrets/groq-api-key",
			"DEEPSEEK_API_KEY_FILE":   "/run/secrets/deepseek-api-key",
			"GEMINI_API_KEY_FILE":     "/run/secrets/gemini-api-key",
			"MISTRAL_API_KEY_FILE":    "/run/secrets/mistral-api-key",
			"PERPLEXITY_API_KEY_FILE": "/run/secrets/perplexity-api-key",
			"REPLICATE_API_KEY_FILE":  "/run/secrets/replicate-api-key",
			"SAMBANOVA_API_KEY_FILE":  "/run/secrets/sambanova-api-key",
			"TOGETHERAI_API_KEY_FILE": "/run/secrets/togetherai-api-key",
			"HF_TOKEN_FILE":           "/run/secrets/hf-token",
			"LANGCHAIN_API_KEY_FILE":  "/run/secrets/langchain-api-key",
			"SERPAPI_API_KEY_FILE":    "/run/secrets/serpapi-api-key",
			"SEARCH1API_KEY_FILE":     "/run/secrets/search1api-key",
			"UPSTAGE_API_KEY_FILE":    "/run/secrets/upstage-api-key",
			"JINA_API_KEY_FILE":       "/run/secrets/jina-api-key",
			"KAGI_API_KEY_FILE":       "/run/secrets/kagi-api-key",
			"GLAMA_API_KEY_FILE":      "/run/secrets/glama-api-key",
		},
		Command: []string{
			"--config", "/app/config/litellm_config.yaml",
			"--port", litellmPort,
			"--host", "0.0.0.0",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"traefik.enable":                  "true",
			"homepage.group":                  "AI",
			"homepage.name":                   "Litellm",
			"homepage.icon":                   "litellm.png",
			"homepage.href":                   fmt.Sprintf("https://litellm.%s/", domain),
			"homepage.description":            "LLM gateway/router with provider failover, caching, rate limits, and analytics",
			"kuma.litellm.http.name":          fmt.Sprintf("litellm.%s.%s", tsHostname, domain),
			"kuma.litellm.http.url":           fmt.Sprintf("https://litellm.%s", domain),
			"kuma.litellm.http.interval":      "60",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget -qO- http://127.0.0.1:%s/health/liveliness", litellmPort)},
			Timeout:     "15s",
			Retries:     5,
			StartPeriod: "30s",
		},
		DependsOn:  []string{"litellm-postgres", "redis"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// gptr
	gptrSecrets := []SecretMount{
		{Source: fmt.Sprintf("%s/anthropic-api-key.txt", secretsPath), Target: "/run/secrets/anthropic-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/brave-api-key.txt", secretsPath), Target: "/run/secrets/brave-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/deepseek-api-key.txt", secretsPath), Target: "/run/secrets/deepseek-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/exa-api-key.txt", secretsPath), Target: "/run/secrets/exa-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/firecrawl-api-key.txt", secretsPath), Target: "/run/secrets/firecrawl-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/gemini-api-key.txt", secretsPath), Target: "/run/secrets/gemini-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/glama-api-key.txt", secretsPath), Target: "/run/secrets/glama-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/groq-api-key.txt", secretsPath), Target: "/run/secrets/groq-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/hf-token.txt", secretsPath), Target: "/run/secrets/hf-token", Mode: "0400"},
		{Source: fmt.Sprintf("%s/langchain-api-key.txt", secretsPath), Target: "/run/secrets/langchain-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/mistral-api-key.txt", secretsPath), Target: "/run/secrets/mistral-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/openai-api-key.txt", secretsPath), Target: "/run/secrets/openai-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/openrouter-api-key.txt", secretsPath), Target: "/run/secrets/openrouter-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/perplexity-api-key.txt", secretsPath), Target: "/run/secrets/perplexity-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/replicate-api-key.txt", secretsPath), Target: "/run/secrets/replicate-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/revid-api-key.txt", secretsPath), Target: "/run/secrets/revid-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/sambanova-api-key.txt", secretsPath), Target: "/run/secrets/sambanova-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/search1api-key.txt", secretsPath), Target: "/run/secrets/search1api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/serpapi-api-key.txt", secretsPath), Target: "/run/secrets/serpapi-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/tavily-api-key.txt", secretsPath), Target: "/run/secrets/tavily-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/togetherai-api-key.txt", secretsPath), Target: "/run/secrets/togetherai-api-key", Mode: "0400"},
		{Source: fmt.Sprintf("%s/upstage-api-key.txt", secretsPath), Target: "/run/secrets/upstage-api-key", Mode: "0400"},
	}
	services = append(services, Service{
		Name:          "gptr",
		Image:         cfg.GetImageName("ai-researchwizard-aio-fullstack:master"),
		ContainerName: "gptr",
		Hostname:      "gptr",
		Networks:      []string{"backend", "publicnet"},
		Secrets:       gptrSecrets,
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/gptr/logs", configPath), Target: "/usr/src/app/logs", Type: "bind"},
			{Source: fmt.Sprintf("%s/gptr/outputs", configPath), Target: "/usr/src/app/outputs", Type: "bind"},
			{Source: fmt.Sprintf("%s/gptr/reports", configPath), Target: "/usr/src/app/reports", Type: "bind"},
		},
		Environment: map[string]string{
			"ANTHROPIC_API_KEY_FILE":        "/run/secrets/anthropic-api-key",
			"BRAVE_API_KEY_FILE":            "/run/secrets/brave-api-key",
			"DEEPSEEK_API_KEY_FILE":         "/run/secrets/deepseek-api-key",
			"EXA_API_KEY_FILE":              "/run/secrets/exa-api-key",
			"FIRECRAWL_API_KEY_FILE":        "/run/secrets/firecrawl-api-key",
			"FIRE_CRAWL_API_KEY_FILE":       "/run/secrets/firecrawl-api-key",
			"GEMINI_API_KEY_FILE":           "/run/secrets/gemini-api-key",
			"GLAMA_API_KEY_FILE":            "/run/secrets/glama-api-key",
			"GROQ_API_KEY_FILE":             "/run/secrets/groq-api-key",
			"HF_TOKEN_FILE":                 "/run/secrets/hf-token",
			"HUGGINGFACE_ACCESS_TOKEN_FILE": "/run/secrets/hf-token",
			"HUGGINGFACE_API_TOKEN_FILE":    "/run/secrets/hf-token",
			"LANGCHAIN_API_KEY_FILE":        "/run/secrets/langchain-api-key",
			"MISTRAL_API_KEY_FILE":          "/run/secrets/mistral-api-key",
			"MISTRALAI_API_KEY_FILE":        "/run/secrets/mistral-api-key",
			"OPENAI_API_KEY_FILE":           "/run/secrets/openai-api-key",
			"OPENROUTER_API_KEY_FILE":       "/run/secrets/openrouter-api-key",
			"PERPLEXITY_API_KEY_FILE":       "/run/secrets/perplexity-api-key",
			"PERPLEXITYAI_API_KEY_FILE":     "/run/secrets/perplexity-api-key",
			"REPLICATE_API_KEY_FILE":        "/run/secrets/replicate-api-key",
			"REVID_API_KEY_FILE":            "/run/secrets/revid-api-key",
			"SAMBANOVA_API_KEY_FILE":        "/run/secrets/sambanova-api-key",
			"SEARCH1API_KEY_FILE":           "/run/secrets/search1api-key",
			"SERPAPI_API_KEY_FILE":          "/run/secrets/serpapi-api-key",
			"TAVILY_API_KEY_FILE":           "/run/secrets/tavily-api-key",
			"TOGETHERAI_API_KEY_FILE":       "/run/secrets/togetherai-api-key",
			"UPSTAGE_API_KEY_FILE":          "/run/secrets/upstage-api-key",
			"UPSTAGEAI_API_KEY_FILE":        "/run/secrets/upstage-api-key",
			"CHOKIDAR_USEPOLLING":           getEnv("CHOKIDAR_USEPOLLING", "true"),
			"LOGGING_LEVEL":                 getEnv("GPTR_LOGGING_LEVEL", "DEBUG"),
			"NEXT_PUBLIC_GA_MEASUREMENT_ID": getEnv("NEXT_PUBLIC_GA_MEASUREMENT_ID", ""),
			"NEXT_PUBLIC_GPTR_API_URL":      fmt.Sprintf("https://gptr.%s", domain),
			"LANGSMITH_TRACING":             getEnv("LANGSMITH_TRACING", "true"),
			"LANGSMITH_ENDPOINT":            getEnv("LANGSMITH_ENDPOINT", "https://api.smith.langchain.com"),
			"LANGSMITH_API_KEY_FILE":        "/run/secrets/langchain-api-key",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                            "true",
			"traefik.enable":                                             "true",
			"traefik.http.routers.gptr-nextjs.service":                   "gptr-nextjs@docker",
			"traefik.http.routers.gptr-nextjs.rule":                      fmt.Sprintf("Host(`gptr-nextjs.%s`) || Host(`gptr-nextjs.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.gptr-nextjs.loadbalancer.server.port": "3000",
			"traefik.http.routers.gptr-legacy.service":                   "gptr-legacy@docker",
			"traefik.http.routers.gptr-legacy.rule":                      fmt.Sprintf("Host(`gptr.%s`) || Host(`gptr.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.gptr-legacy.loadbalancer.server.port": "8000",
			"traefik.http.routers.gptr-mcp.service":                      "gptr-mcp@docker",
			"traefik.http.routers.gptr-mcp.rule":                         fmt.Sprintf("Host(`gptr-mcp.%s`) || Host(`gptr-mcp.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.gptr-mcp.loadbalancer.server.port":    "8080",
			"homepage.group":                                             "AI",
			"homepage.name":                                              "AI Research Wizard",
			"homepage.description":                                       "Full-stack AI research and scraping toolkit with Next.js UI is a web scraper and researcher that uses AI to help you find information quickly.",
			"homepage.icon":                                              "gptr.png",
			"homepage.href":                                              fmt.Sprintf("https://gptr.%s/", domain),
			"kuma.gptr.http.name":                                        fmt.Sprintf("gptr.%s.%s", tsHostname, domain),
			"kuma.gptr.http.url":                                         fmt.Sprintf("https://gptr.%s", domain),
			"kuma.gptr.http.interval":                                    "30",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "(wget -qO- http://127.0.0.1:3000 > /dev/null 2>&1 && wget -qO- http://127.0.0.1:8000 > /dev/null 2>&1) || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "2m",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Open WebUI
	openWebUIPort := getEnv("OPEN_WEBUI_PORT", "8080")
	services = append(services, Service{
		Name:          "open-webui",
		Image:         "ghcr.io/open-webui/open-webui:main",
		ContainerName: "open-webui",
		Hostname:      "open-webui",
		Networks:      []string{"backend", "publicnet"},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/open-webui-secret-key.txt", secretsPath), Target: "/run/secrets/open-webui-secret-key", Mode: "0400"},
		},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/open-webui/uploads", configPath), Target: "/app/backend/data/uploads", Type: "bind"},
			{Source: fmt.Sprintf("%s/open-webui/vector_db", configPath), Target: "/app/backend/data/vector_db", Type: "bind"},
			{Source: fmt.Sprintf("%s/open-webui/webui.db", configPath), Target: "/app/backend/data/webui.db", Type: "bind"},
		},
		Environment: map[string]string{
			"ENABLE_ADMIN_EXPORT":                    "True",
			"ENABLE_ADMIN_CHAT_ACCESS":               "True",
			"BYPASS_MODEL_ACCESS_CONTROL":            "True",
			"ENV":                                    "prod",
			"ENABLE_PERSISTENT_CONFIG":               "True",
			"PORT":                                   openWebUIPort,
			"ENABLE_REALTIME_CHAT_SAVE":              "True",
			"WEBUI_BUILD_HASH":                       "dev-build",
			"AIOHTTP_CLIENT_TIMEOUT":                 "300",
			"AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST":      "10",
			"AIOHTTP_CLIENT_TIMEOUT_OPENAI_MODEL_LIST": "10",
			"DATA_DIR":                              "./data",
			"FRONTEND_BUILD_DIR":                     "../build",
			"STATIC_DIR":                             "./static",
			"OLLAMA_BASE_URL":                        "/ollama",
			"USE_OLLAMA_DOCKER":                      "false",
			"K8S_FLAG":                              "False",
			"ENABLE_FORWARD_USER_INFO_HEADERS":      "False",
			"WEBUI_SESSION_COOKIE_SAME_SITE":         "lax",
			"WEBUI_SESSION_COOKIE_SECURE":            "False",
			"WEBUI_AUTH_COOKIE_SAME_SITE":            "lax",
			"WEBUI_AUTH_COOKIE_SECURE":               "False",
			"WEBUI_AUTH":                             getEnv("WEBUI_AUTH", "True"),
			"WEBUI_SECRET_KEY_FILE":                  "/run/secrets/open-webui-secret-key",
			"ENABLE_VERSION_UPDATE_CHECK":            "True",
			"OFFLINE_MODE":                           "False",
			"RESET_CONFIG_ON_START":                  "False",
			"SAFE_MODE":                              "False",
			"CORS_ALLOW_ORIGIN":                      getEnv("OPEN_WEBUI_CORS_ALLOWED_ORIGIN", "*"),
			"RAG_EMBEDDING_MODEL_TRUST_REMOTE_CODE":  "True",
			"RAG_RERANKING_MODEL_TRUST_REMOTE_CODE":  "True",
			"RAG_EMBEDDING_MODEL_AUTO_UPDATE":        "True",
			"RAG_RERANKING_MODEL_AUTO_UPDATE":        "True",
			"VECTOR_DB":                              "chroma",
			"TIKTOKEN_CACHE_DIR":                     "/app/backend/data/cache/tiktoken",
			"RAG_EMBEDDING_OPENAI_BATCH_SIZE":        "1",
			"DOCKER":                                 "true",
			"HOME":                                   "/root",
			"HF_HOME":                                "/app/backend/data/cache/embedding/models",
			"SENTENCE_TRANSFORMERS_HOME":             "/app/backend/data/cache/embedding/models",
			"USE_CUDA_DOCKER_VER":                    "cu128",
			"USE_EMBEDDING_MODEL_DOCKER":             "sentence-transformers/all-MiniLM-L6-v2",
			"ANONYMIZED_TELEMETRY":                   "false",
			"DO_NOT_TRACK":                           "true",
			"SCARF_NO_ANALYTICS":                     "true",
		},
		Command: []string{"bash", "start.sh"},
		Labels: map[string]string{
			"traefik.enable":                                         "true",
			"traefik.http.routers.open-webui.rule":                   fmt.Sprintf("Host(`open-webui.%s`) || Host(`open-webui.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.open-webui.loadbalancer.server.port": openWebUIPort,
			"homepage.group":                                        "AI",
			"homepage.name":                                         "Open WebUI",
			"homepage.icon":                                         "open-webui.png",
			"homepage.href":                                         fmt.Sprintf("https://open-webui.%s/", domain),
			"homepage.description":                                 "Web interface for chatting with local/remote LLMs, tools, and knowledge bases",
			"kuma.open-webui.http.name":                             fmt.Sprintf("open-webui.%s.%s", tsHostname, domain),
			"kuma.open-webui.http.url":                              fmt.Sprintf("https://open-webui.%s", domain),
			"kuma.open-webui.http.interval":                         "20",
		},
		Healthcheck: &Healthcheck{
			Test:     []string{"CMD-SHELL", fmt.Sprintf("curl -f http://127.0.0.1:%s", openWebUIPort)},
			Interval: "5s",
			Timeout:  "30s",
			Retries:  10,
		},
		DependsOn:  []string{"mcpo", "litellm"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Qdrant
	services = append(services, Service{
		Name:          "qdrant",
		Image:         "qdrant/qdrant",
		ContainerName: "qdrant",
		Hostname:      "qdrant",
		Networks:      []string{"publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/qdrant/storage", configPath), Target: "/qdrant/storage", Type: "bind"},
		},
		Environment: map[string]string{
			"QDRANT_STORAGE_PATH":   "/qdrant/storage",
			"QDRANT_STORAGE_TYPE":   "disk",
			"QDRANT_STORAGE_DISK_PATH": "/qdrant/storage",
			"QDRANT_STORAGE_DISK_TYPE": "disk",
		},
		Labels: map[string]string{
			"traefik.enable":                                         "true",
			"traefik.http.services.qdrant.loadbalancer.server.port": "6333",
			"homepage.group":                                        "AI",
			"homepage.name":                                         "Qdrant",
			"homepage.icon":                                         "qdrant.png",
			"homepage.href":                                         fmt.Sprintf("https://qdrant.%s", domain),
			"homepage.description":                                 "Qdrant is a vector database for storing and querying vectors.",
		},
		Restart: "always",
	})

	// MCP Proxy
	mcpProxyPort := getEnv("MCP_PROXY_PORT", "9090")
	services = append(services, Service{
		Name:          "mcp-proxy",
		Image:         "ghcr.io/tbxark/mcp-proxy",
		ContainerName: "mcp-proxy",
		Hostname:      "mcp",
		Networks:      []string{"publicnet"},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/llm/mcpProxy.json", configPath), Target: "/config.json", Mode: "0777"},
		},
		Labels: map[string]string{
			"traefik.enable":                                         "true",
			"traefik.http.routers.mcp-proxy.rule":                    fmt.Sprintf("Host(`mcp.%s`) || Host(`mcp.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.mcp-proxy.loadbalancer.server.port": mcpProxyPort,
			"homepage.group":                                        "MCP",
			"homepage.name":                                         "MCP Proxy",
			"homepage.icon":                                         "mcp-proxy.png",
			"homepage.href":                                         fmt.Sprintf("https://mcp.%s", domain),
			"homepage.description":                                 "MCP Proxy is a tool for proxying MCP servers.",
		},
		Command: []string{
			"--config", "config.json",
			"-expand-env",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// Model Updater
	services = append(services, Service{
		Name:          "model-updater",
		Image:         "th3w1zard1/llm_fallbacks:latest",
		ContainerName: "model-updater",
		Hostname:      "model-updater",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/litellm", configPath), Target: "/app/config", Type: "bind"},
		},
		Environment: map[string]string{
			"OPENROUTER_API_KEY":      getEnv("OPENROUTER_API_KEY", ""),
			"POSTGRES_PASSWORD":       getEnv("LITELLM_POSTGRES_PASSWORD", "postgres"),
			"TZ":                      getEnv("TZ", "America/Chicago"),
		},
		Restart: "no",
	})

	return services
}
