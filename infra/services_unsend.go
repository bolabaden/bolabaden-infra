package main

import (
	"fmt"
)

// defineServicesUnsend returns all services from compose/docker-compose.unsend.yml
func defineServicesUnsend(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// unsend-postgres
	services = append(services, Service{
		Name:          "unsend-postgres",
		Image:         "docker.io/postgres:16-alpine",
		ContainerName: "unsend-postgres",
		Hostname:      "unsend-postgres",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/unsend/postgres", configPath), Target: "/var/lib/postgresql/data", Type: "bind"},
		},
		Environment: map[string]string{
			"POSTGRES_USER":     "postgres",
			"POSTGRES_PASSWORD": "postgres",
			"POSTGRES_DB":       "unsend",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"},
			Interval:    "5s",
			Timeout:     "20s",
			Retries:     10,
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// unsend
	unsendFQDN := getEnv("UNSEND_FQDN", fmt.Sprintf("unsend.%s.%s", tsHostname, domain))
	unsendURL := getEnv("UNSEND_URL", fmt.Sprintf("https://unsend.%s", domain))
	services = append(services, Service{
		Name:          "unsend",
		Image:         "docker.io/unsend/unsend",
		ContainerName: "unsend",
		Hostname:      "unsend",
		Networks:      []string{"backend", "publicnet"},
		Environment: map[string]string{
			"API_RATE_LIMIT":       getEnv("API_RATE_LIMIT", "1"),
			"AWS_ACCESS_KEY":       getEnv("AWS_ACCESS_KEY", ""),
			"AWS_DEFAULT_REGION":   getEnv("AWS_DEFAULT_REGION", "us-east-1"),
			"AWS_SECRET_KEY":       getEnv("AWS_SECRET_KEY", ""),
			"DATABASE_URL":         getEnv("UNSEND_POSTGRES_URL", fmt.Sprintf("postgresql://postgres:postgres@unsend-postgres:5432/unsend")),
			"GITHUB_ID":            getEnv("UNSEND_GITHUB_ID", ""),
			"GITHUB_SECRET":        getEnv("UNSEND_GITHUB_SECRET", ""),
			"HOSTNAME":             "0.0.0.0",
			"NEXT_PUBLIC_IS_CLOUD": getEnv("NEXT_PUBLIC_IS_CLOUD", "false"),
			"NEXTAUTH_SECRET":      getEnv("NEXTAUTH_SECRET", ""),
			"REDIS_URL":            getEnv("REDIS_HOST", "redis://redis:6379"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                       "true",
			"traefik.enable":                                        "true",
			"traefik.http.middlewares.gzip.compress":                "true",
			"traefik.http.routers.unsend.middlewares":               "gzip",
			"traefik.http.routers.unsend.service":                   "unsend",
			"traefik.http.routers.unsend.rule":                      fmt.Sprintf("(Host(`unsend.%s`) || Host(`unsend.%s.%s`)) && PathPrefix(`/`)", domain, tsHostname, domain),
			"traefik.http.services.unsend.loadbalancer.server.port": "3000",
			"kuma.unsend.http.name":                                 unsendFQDN,
			"kuma.unsend.http.url":                                  unsendURL,
			"kuma.unsend.http.interval":                             "5",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget -qO- http://unsend:3000 > /dev/null 2>&1 || exit 1"},
			Interval:    "5s",
			Timeout:     "2s",
			Retries:     10,
			StartPeriod: "30s",
		},
		DependsOn:  []string{"unsend-postgres", "redis"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
