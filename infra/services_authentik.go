package main

import (
	"fmt"
)

// defineServicesAuthentik returns all services from compose/docker-compose.authentik.yml
func defineServicesAuthentik(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")
	authentikTag := getEnv("AUTHENTIK_TAG", "2025.8.3")

	services := []Service{}

	// authentik-postgresql
	services = append(services, Service{
		Name:          "authentik-postgresql",
		Image:         "docker.io/postgres:16-alpine",
		ContainerName: "authentik-postgresql",
		Hostname:      "authentik-postgresql",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/authentik/postgresql", configPath), Target: "/var/lib/postgresql/data", Type: "bind"},
		},
		Environment: map[string]string{
			"POSTGRES_PASSWORD": "authentik",
			"POSTGRES_USER":     "authentik",
			"POSTGRES_DB":       "authentik",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "pg_isready -d $POSTGRES_DB -U $POSTGRES_USER"},
			Interval:    "2s",
			Timeout:     "10s",
			Retries:     15,
			StartPeriod: "30s",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// authentik
	services = append(services, Service{
		Name:          "authentik",
		Image:         fmt.Sprintf("ghcr.io/goauthentik/server:%s", authentikTag),
		ContainerName: "authentik",
		Hostname:      "authentik",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/authentik/media", configPath), Target: "/media", Type: "bind"},
			{Source: fmt.Sprintf("%s/authentik/custom-templates", configPath), Target: "/templates", Type: "bind"},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/authentik-secret-key.txt", secretsPath), Target: "/run/secrets/authentik-secret-key", Mode: "0400"},
			{Source: fmt.Sprintf("%s/gmail-app-password.txt", secretsPath), Target: "/run/secrets/gmail-app-password", Mode: "0400"},
			{Source: fmt.Sprintf("%s/sudo-password.txt", secretsPath), Target: "/run/secrets/sudo-password", Mode: "0400"},
		},
		Environment: map[string]string{
			"AUTHENTIK_REDIS__HOST":              "redis",
			"AUTHENTIK_POSTGRESQL__HOST":         "authentik-postgresql",
			"AUTHENTIK_POSTGRESQL__USER":         "authentik",
			"AUTHENTIK_POSTGRESQL__NAME":         "authentik",
			"AUTHENTIK_POSTGRESQL__PASSWORD":     "authentik",
			"AUTHENTIK_SECRET_KEY":               "/run/secrets/authentik-secret-key",
			"AUTHENTIK_ERROR_REPORTING__ENABLED": "true",
			"AUTHENTIK_EMAIL__HOST":              "smtp.gmail.com",
			"AUTHENTIK_EMAIL__PORT":              "587",
			"AUTHENTIK_EMAIL__USERNAME":          "boden.crouch@gmail.com",
			"AUTHENTIK_EMAIL__PASSWORD":          "/run/secrets/gmail-app-password",
			"AUTHENTIK_EMAIL__USE_TLS":           "true",
			"AUTHENTIK_EMAIL__USE_SSL":           "false",
			"AUTHENTIK_EMAIL__TIMEOUT":           "10",
			"AUTHENTIK_EMAIL__FROM":              "boden.crouch@gmail.com",
			"AUTHENTIK_BOOTSTRAP__EMAIL":         "boden.crouch@gmail.com",
			"AUTHENTIK_BOOTSTRAP__PASSWORD":      "/run/secrets/sudo-password",
		},
		Command: []string{"server"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":        "true",
			"traefik.enable":                         "true",
			"traefik.http.middlewares.gzip.compress": "true",
			"traefik.http.middlewares.authentik-server-redirect.redirectRegex.regex":       fmt.Sprintf("^https?://authentik-server\\.((?:%s|%s\\.%s))(.*)$", domain, tsHostname, domain),
			"traefik.http.middlewares.authentik-server-redirect.redirectRegex.replacement": fmt.Sprintf("https://authentik.$1$2"),
			"traefik.http.middlewares.authentik-server-redirect.redirectRegex.permanent":   "false",
			"traefik.http.middlewares.authentikserver-redirect.redirectRegex.regex":        fmt.Sprintf("^https?://authentikserver\\.((?:%s|%s\\.%s))(.*)$", domain, tsHostname, domain),
			"traefik.http.middlewares.authentikserver-redirect.redirectRegex.replacement":  "https://authentik.$1$2",
			"traefik.http.middlewares.authentikserver-redirect.redirectRegex.permanent":    "false",
			"traefik.http.routers.authentik-server-redirect.service":                       "authentik@docker",
			"traefik.http.routers.authentik-server-redirect.rule":                          fmt.Sprintf("Host(`authentik-server.%s`) || Host(`authentik-server.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.routers.authentik-server-redirect.middlewares":                   "authentik-server-redirect@docker",
			"traefik.http.routers.authentikserver-redirect.service":                        "authentik@docker",
			"traefik.http.routers.authentikserver-redirect.rule":                           fmt.Sprintf("Host(`authentikserver.%s`) || Host(`authentikserver.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.routers.authentikserver-redirect.middlewares":                    "authentikserver-redirect@docker",
			"traefik.http.routers.authentik.service":                                       "authentik",
			"traefik.http.routers.authentik.rule":                                          fmt.Sprintf("Host(`authentik.%s`) || Host(`authentik.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.routers.authentik.middlewares":                                   "gzip",
			"traefik.http.services.authentik.loadbalancer.server.port":                     "9000",
			"kuma.authentik.http.name":                                                     fmt.Sprintf("authentik.%s.%s", tsHostname, domain),
			"kuma.authentik.http.url":                                                      fmt.Sprintf("https://authentik.%s", domain),
			"kuma.authentik.http.interval":                                                 "60",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "python3 -c 'import socket; s=socket.socket(); s.settimeout(5); s.connect((\"127.0.0.1\", 9000)); s.close()' || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     10,
			StartPeriod: "60s",
		},
		DependsOn:  []string{"authentik-postgresql", "redis"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// authentik-worker
	services = append(services, Service{
		Name:          "authentik-worker",
		Image:         fmt.Sprintf("ghcr.io/goauthentik/server:%s", authentikTag),
		ContainerName: "authentik-worker",
		Hostname:      "authentik-worker",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: getEnv("DOCKER_SOCKET", "/var/run/docker.sock"), Target: "/var/run/docker.sock", Type: "bind"},
			{Source: fmt.Sprintf("%s/authentik/media", configPath), Target: "/media", Type: "bind"},
			{Source: fmt.Sprintf("%s/authentik/certs", configPath), Target: "/certs", Type: "bind"},
			{Source: fmt.Sprintf("%s/authentik/custom-templates", configPath), Target: "/templates", Type: "bind"},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/authentik-secret-key.txt", secretsPath), Target: "/run/secrets/authentik-secret-key", Mode: "0400"},
			{Source: fmt.Sprintf("%s/gmail-app-password.txt", secretsPath), Target: "/run/secrets/gmail-app-password", Mode: "0400"},
			{Source: fmt.Sprintf("%s/sudo-password.txt", secretsPath), Target: "/run/secrets/sudo-password", Mode: "0400"},
		},
		Environment: map[string]string{
			"AUTHENTIK_REDIS__HOST":              "redis",
			"AUTHENTIK_POSTGRESQL__HOST":         "authentik-postgresql",
			"AUTHENTIK_POSTGRESQL__USER":         "authentik",
			"AUTHENTIK_POSTGRESQL__NAME":         "authentik",
			"AUTHENTIK_POSTGRESQL__PASSWORD":     "authentik",
			"AUTHENTIK_SECRET_KEY":               "/run/secrets/authentik-secret-key",
			"AUTHENTIK_ERROR_REPORTING__ENABLED": "true",
			"AUTHENTIK_EMAIL__HOST":              "smtp.gmail.com",
			"AUTHENTIK_EMAIL__PORT":              "587",
			"AUTHENTIK_EMAIL__USERNAME":          "boden.crouch@gmail.com",
			"AUTHENTIK_EMAIL__PASSWORD":          "/run/secrets/gmail-app-password",
			"AUTHENTIK_EMAIL__USE_TLS":           "true",
			"AUTHENTIK_EMAIL__USE_SSL":           "false",
			"AUTHENTIK_EMAIL__TIMEOUT":           "10",
			"AUTHENTIK_EMAIL__FROM":              "boden.crouch@gmail.com",
			"AUTHENTIK_BOOTSTRAP__EMAIL":         "boden.crouch@gmail.com",
			"AUTHENTIK_BOOTSTRAP__PASSWORD":      "/run/secrets/sudo-password",
		},
		Command: []string{"worker"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		DependsOn:  []string{"authentik-postgresql", "redis"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
