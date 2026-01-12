package main

import (
	"fmt"
)

// defineServicesFirecrawl returns all services from compose/docker-compose.firecrawl.yml
// Note: Build configs from GitHub are replaced with pre-built images
func defineServicesFirecrawl(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// playwright-service
	services = append(services, Service{
		Name:          "playwright-service",
		Image:         "ghcr.io/firecrawl/playwright-service",
		ContainerName: "playwright-service",
		Hostname:      "playwright-service",
		Networks:      []string{"backend"},
		Environment: map[string]string{
			"PORT":           getEnv("FIRECRAWL_PLAYWRIGHT_SERVICE_PORT", "3000"),
			"PROXY_SERVER":   getEnv("FIRECRAWL_PROXY_SERVER", ""),
			"PROXY_USERNAME": getEnv("FIRECRAWL_PROXY_USERNAME", ""),
			"PROXY_PASSWORD": getEnv("FIRECRAWL_PROXY_PASSWORD", ""),
			"BLOCK_MEDIA":    getEnv("FIRECRAWL_BLOCK_MEDIA", "false"),
		},
		Labels: map[string]string{
			"kuma.playwright-service.http.name":     fmt.Sprintf("playwright-service.%s.%s", tsHostname, domain),
			"kuma.playwright-service.http.url":      fmt.Sprintf("https://playwright-service.%s", domain),
			"kuma.playwright-service.http.interval": "60",
		},
		Healthcheck: &Healthcheck{
			Test:     []string{"CMD-SHELL", "apt update && apt install curl -y && apt autoremove -y && curl -f http://127.0.0.1:3000/health >/dev/null 2>&1 || exit 1"},
			Interval: "2s",
			Timeout:  "10s",
			Retries:  10,
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// firecrawl
	firecrawlInternalPort := getEnv("FIRECRAWL_INTERNAL_PORT", "3002")
	firecrawlExtractWorkerPort := getEnv("FIRECRAWL_EXTRACT_WORKER_PORT", "3004")
	firecrawlWorkerPort := getEnv("FIRECRAWL_WORKER_PORT", "3005")
	services = append(services, Service{
		Name:          "firecrawl",
		Image:         "ghcr.io/firecrawl/firecrawl",
		ContainerName: "firecrawl",
		Hostname:      "api",
		Networks:      []string{"backend", "publicnet"},
		PullPolicy:    "build", // pull_policy: build
		Expose: []ExposePort{
			{Port: firecrawlInternalPort, Protocol: "tcp"},
			{Port: firecrawlExtractWorkerPort, Protocol: "tcp"},
			{Port: firecrawlWorkerPort, Protocol: "tcp"},
		},
		Ulimits: &Ulimits{
			Nofile: &NofileLimit{
				Soft: 65535,
				Hard: 65535,
			},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/openai-api-key.txt", secretsPath), Target: "/run/secrets/openai-api-key", Mode: "0400"},
			{Source: fmt.Sprintf("%s/firecrawl-api-key.txt", secretsPath), Target: "/run/secrets/firecrawl-api-key", Mode: "0400"},
		},
		Environment: map[string]string{
			"REDIS_URL":                   getEnv("FIRECRAWL_REDIS_URL", fmt.Sprintf("redis://%s:%s", getEnv("REDIS_HOSTNAME", "redis"), getEnv("REDIS_PORT", "6379"))),
			"REDIS_RATE_LIMIT_URL":        getEnv("FIRECRAWL_REDIS_RATE_LIMIT_URL", fmt.Sprintf("redis://%s:%s", getEnv("REDIS_HOSTNAME", "redis"), getEnv("REDIS_PORT", "6379"))),
			"PLAYWRIGHT_MICROSERVICE_URL": getEnv("PLAYWRIGHT_HOST", "http://playwright-service:3000/scrape"),
			"NUQ_DATABASE_URL":            getEnv("FIRECRAWL_NUQ_DATABASE_URL", fmt.Sprintf("postgres://%s:%s@%s:%s/%s", getEnv("FIRECRAWL_POSTGRES_USERNAME", "postgres"), getEnv("FIRECRAWL_POSTGRES_PASSWORD", "postgres"), getEnv("FIRECRAWL_POSTGRES_HOSTNAME", "nuq-postgres"), getEnv("FIRECRAWL_POSTGRES_PORT", "5432"), getEnv("FIRECRAWL_POSTGRES_DB", "postgres"))),
			"NUQ_RABBITMQ_URL":            getEnv("FIRECRAWL_NUQ_RABBITMQ_URL", fmt.Sprintf("amqp://%s:%s@%s:%s", getEnv("RABBITMQ_USERNAME", "rabbitmq"), getEnv("RABBITMQ_PASSWORD", "rabbitmq"), getEnv("RABBITMQ_HOSTNAME", "rabbitmq"), getEnv("RABBITMQ_PORT", "5672"))),
			"EXTRACT_WORKER_PORT":         getEnv("FIRECRAWL_EXTRACT_WORKER_PORT", "3004"),
			"USE_DB_AUTHENTICATION":       getEnv("FIRECRAWL_USE_DB_AUTHENTICATION", ""),
			"OPENAI_API_KEY_FILE":         "/run/secrets/openai-api-key",
			"OPENAI_BASE_URL":             getEnv("OPENAI_BASE_URL", ""),
			"MODEL_NAME":                  getEnv("FIRECRAWL_MODEL_NAME", ""),
			"MODEL_EMBEDDING_NAME":        getEnv("FIRECRAWL_MODEL_EMBEDDING_NAME", ""),
			"OLLAMA_BASE_URL":             getEnv("FIRECRAWL_OLLAMA_BASE_URL", ""),
			"SLACK_WEBHOOK_URL":           getEnv("SLACK_WEBHOOK_URL", ""),
			"BULL_AUTH_KEY_FILE":          "/run/secrets/firecrawl-api-key",
			"TEST_API_KEY_FILE":           "/run/secrets/firecrawl-api-key",
			"POSTHOG_API_KEY":             getEnv("POSTHOG_API_KEY", ""),
			"POSTHOG_HOST":                getEnv("POSTHOG_HOST", ""),
			"SUPABASE_ANON_TOKEN":         getEnv("SUPABASE_ANON_TOKEN", ""),
			"SUPABASE_URL":                getEnv("SUPABASE_URL", ""), // Required but may be empty
			"SUPABASE_SERVICE_TOKEN":      getEnv("SUPABASE_SERVICE_TOKEN", ""),
			"SELF_HOSTED_WEBHOOK_URL":     getEnv("FIRECRAWL_SELF_HOSTED_WEBHOOK_URL", ""),
			"SERPER_API_KEY":              getEnv("SERPER_API_KEY", ""),
			"SEARCHAPI_API_KEY":           getEnv("SEARCHAPI_API_KEY", ""),
			"SEARXNG_ENDPOINT":            getEnv("SEARXNG_ENDPOINT", fmt.Sprintf("https://searxng.%s", domain)),
			"HOST":                        getEnv("FIRECRAWL_HOST", "0.0.0.0"),
			"PORT":                        firecrawlInternalPort,
			"WORKER_PORT":                 getEnv("FIRECRAWL_WORKER_PORT", "3005"),
			"ENV":                         getEnv("FIRECRAWL_ENV", "local"),
		},
		Command: []string{"node", "dist/src/harness.js", "--start-docker"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":     "true",
			"traefik.enable":                      "true",
			"homepage.group":                      "AI",
			"homepage.name":                       "Firecrawl",
			"homepage.icon":                       "firecrawl.png",
			"homepage.href":                       fmt.Sprintf("https://firecrawl.%s", domain),
			"homepage.description":                "Firecrawl is a tool for crawling and indexing web pages.",
			"traefik.http.routers.firecrawl.rule": fmt.Sprintf("Host(`firecrawl-api.%s`) || Host(`firecrawl-api.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.firecrawl.loadbalancer.server.port": firecrawlInternalPort,
			"kuma.firecrawl.http.name":                                 fmt.Sprintf("firecrawl.%s.%s", tsHostname, domain),
			"kuma.firecrawl.http.url":                                  fmt.Sprintf("https://firecrawl.%s", domain),
			"kuma.firecrawl.http.interval":                             "60",
		},
		MemReservation: "4G",
		CPUs:           "4.0",
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("node -e \"require('http').get('http://127.0.0.1:%s/v0/health/liveness', (r) => { let d=''; r.on('data',c=>d+=c); r.on('end',()=>process.exit(r.statusCode===200?0:1)); }).on('error',()=>process.exit(1));\" >/dev/null 2>&1 || exit 1", firecrawlInternalPort)},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		DependsOn: []string{"redis", "playwright-service", "nuq-postgres", "rabbitmq"},
		DependsOnConditions: map[string]string{
			"redis":              "service_healthy",
			"playwright-service": "service_started",
			"nuq-postgres":       "service_healthy",
			"rabbitmq":           "service_healthy",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// nuq-postgres
	nuqPostgresHostname := getEnv("NUQ_POSTGRES_HOSTNAME", "nuq-postgres")
	services = append(services, Service{
		Name:          "nuq-postgres",
		Image:         "docker.io/postgres:16-alpine", // Using standard postgres image instead of build
		ContainerName: "nuq-postgres",
		Hostname:      nuqPostgresHostname,
		Networks:      []string{"backend"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/nuq-postgres/data", configPath), Target: "/var/lib/postgresql/data", Type: "bind"},
		},
		Environment: map[string]string{
			"POSTGRES_USER":     getEnv("FIRECRAWL_POSTGRES_USER", "postgres"),
			"POSTGRES_PASSWORD": getEnv("FIRECRAWL_POSTGRES_PASSWORD", "postgres"),
			"POSTGRES_DB":       getEnv("FIRECRAWL_POSTGRES_DB", "postgres"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"kuma.nuq-postgres.http.name":     fmt.Sprintf("nuq-postgres.%s.%s", tsHostname, domain),
			"kuma.nuq-postgres.http.url":      fmt.Sprintf("https://nuq-postgres.%s", domain),
			"kuma.nuq-postgres.http.interval": "60",
		},
		Healthcheck: &Healthcheck{
			Test:     []string{"CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB >/dev/null 2>&1 || exit 1"},
			Interval: "10s",
			Timeout:  "5s",
			Retries:  5,
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// rabbitmq
	services = append(services, Service{
		Name:          "rabbitmq",
		Image:         "docker.io/rabbitmq:3-management",
		ContainerName: "rabbitmq",
		Hostname:      "rabbitmq",
		Networks:      []string{"backend"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/rabbitmq-init.sh", getEnv("ROOT_PATH", ".")), Target: "/rabbitmq-init.sh", Type: "bind", ReadOnly: true},
		},
		Environment: map[string]string{
			"RABBITMQ_DEFAULT_USER": getEnv("RABBITMQ_USERNAME", "rabbitmq"),
			"RABBITMQ_DEFAULT_PASS": getEnv("RABBITMQ_PASSWORD", "rabbitmq"),
		},
		Command: []string{"/bin/bash", "/rabbitmq-init.sh"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"kuma.rabbitmq.http.name":         fmt.Sprintf("rabbitmq.%s.%s", tsHostname, domain),
			"kuma.rabbitmq.http.url":          fmt.Sprintf("https://rabbitmq.%s", domain),
			"kuma.rabbitmq.http.interval":     "60",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "rabbitmq-diagnostics -q check_running >/dev/null 2>&1 || exit 1"},
			Interval:    "10s",
			Timeout:     "5s",
			Retries:     5,
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
