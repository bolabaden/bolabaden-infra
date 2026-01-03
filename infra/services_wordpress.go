package main

import (
	"fmt"
)

// defineServicesWordpress returns all services from compose/docker-compose.wordpress.yml
func defineServicesWordpress(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// mariadb
	services = append(services, Service{
		Name:          "mariadb",
		Image:         "docker.io/mariadb:latest",
		ContainerName: "mariadb",
		Hostname:      "mariadb",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/wordpress/mariadb-data", configPath), Target: "/var/lib/mysql", Type: "bind"},
		},
		Environment: map[string]string{
			"MYSQL_ROOT_PASSWORD": getEnv("WORDPRESS_DB_ROOT_PASSWORD", ""),
			"MYSQL_DATABASE":      getEnv("WORDPRESS_DB_NAME", "wordpress"),
			"MYSQL_USER":          getEnv("WORDPRESS_DB_USER", ""),
			"MYSQL_PASSWORD":      getEnv("WORDPRESS_DB_PASSWORD", ""),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// wordpress
	wordpressFQDN := getEnv("WORDPRESS_FQDN", fmt.Sprintf("wordpress.%s.%s", tsHostname, domain))
	wordpressURL := getEnv("WORDPRESS_URL", fmt.Sprintf("https://wordpress.%s", domain))
	services = append(services, Service{
		Name:          "wordpress",
		Image:         "docker.io/wordpress:latest",
		ContainerName: "wordpress",
		Hostname:      "wordpress",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/wordpress/wordpress-files", configPath), Target: "/var/www/html", Type: "bind"},
		},
		Environment: map[string]string{
			"WORDPRESS_DB_HOST":     "mariadb:3306",
			"WORDPRESS_DB_USER":     getEnv("WORDPRESS_DB_USER", ""),
			"WORDPRESS_DB_PASSWORD": getEnv("WORDPRESS_DB_PASSWORD", ""),
			"WORDPRESS_DB_NAME":     getEnv("WORDPRESS_DB_NAME", "wordpress"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                          "true",
			"traefik.enable":                                           "true",
			"traefik.http.middlewares.gzip.compress":                   "true",
			"traefik.http.routers.wordpress.middlewares":               "gzip",
			"traefik.http.routers.wordpress.rule":                      fmt.Sprintf("(Host(`wordpress.%s`) || Host(`wordpress.%s.%s`)) && PathPrefix(`/`)", domain, tsHostname, domain),
			"traefik.http.services.wordpress.loadbalancer.server.port": "80",
			"kuma.wordpress.http.name":                                 wordpressFQDN,
			"kuma.wordpress.http.url":                                  wordpressURL,
			"kuma.wordpress.http.interval":                             "10",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "curl -f http://127.0.0.1:80 > /dev/null 2>&1 || exit 1"},
			Interval:    "2s",
			Timeout:     "10s",
			Retries:     10,
			StartPeriod: "30s",
		},
		DependsOn:  []string{"mariadb"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
