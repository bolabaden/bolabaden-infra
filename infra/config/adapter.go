package config

import (
	"fmt"
	"path/filepath"
)

// Adapter provides compatibility between old Config (from main.go) and new Config
// This allows gradual migration
type Adapter struct {
	OldConfig interface {
		GetDomain() string
		GetStackName() string
		GetConfigPath() string
		GetSecretsPath() string
		GetRootPath() string
	}
	NewConfig *Config
}

// MigrateFromOldConfig creates a new Config from old-style configuration
// This is a helper for migration
func MigrateFromOldConfig(domain, stackName, configPath, secretsPath, rootPath string) *Config {
	cfg := &Config{
		Domain:      domain,
		StackName:   stackName,
		ConfigPath:  configPath,
		SecretsPath: secretsPath,
		RootPath:    rootPath,
		Networks:    make(map[string]NetworkConfig),
		Services:    []ServiceConfig{},
		Traefik: TraefikConfig{
			WebPort:              80,
			WebSecurePort:        443,
			ErrorPagesMiddleware: getEnv("TRAEFIK_ERROR_PAGES_MIDDLEWARE", "error-pages@file"),
			CrowdsecMiddleware:   getEnv("TRAEFIK_CROWDSEC_MIDDLEWARE", "crowdsec@file"),
			StripWWWMiddleware:   getEnv("TRAEFIK_STRIP_WWW_MIDDLEWARE", "strip-www@file"),
			CertResolver:         getEnv("TRAEFIK_CERT_RESOLVER", "letsencrypt"),
			HTTPProviderPort:     getEnvInt("TRAEFIK_HTTP_PROVIDER_PORT", 8081),
			CloudflareTrustedIPs: getCloudflareTrustedIPs(),
		},
		DNS: DNSConfig{
			Provider: getEnv("DNS_PROVIDER", "cloudflare"),
			APIKey:   getEnv("CLOUDFLARE_API_KEY", ""),
			APIEmail: getEnv("CLOUDFLARE_API_EMAIL", ""),
			ZoneID:   getEnv("CLOUDFLARE_ZONE_ID", ""),
		},
		Cluster: ClusterConfig{
			BindPort: getEnvInt("BIND_PORT", 7946),
			RaftPort: getEnvInt("RAFT_PORT", 8300),
			APIPort:  getEnvInt("API_PORT", 8080),
			Priority: getEnvInt("NODE_PRIORITY", 100),
		},
		Middlewares: MiddlewareConfig{
			ErrorPagesEnabled: true,
			ErrorPagesName:    "error-pages",
			CrowdsecEnabled:   true,
			CrowdsecName:      "crowdsec",
			StripWWWEnabled:   true,
			StripWWWName:      "strip-www",
		},
		Registry: RegistryConfig{
			ImagePrefix:    getEnv("IMAGE_PREFIX", ""),
			DefaultRegistry: getEnv("DEFAULT_REGISTRY", "docker.io"),
		},
	}
	
	// Resolve relative paths
	if !filepath.IsAbs(cfg.ConfigPath) && cfg.RootPath != "." {
		cfg.ConfigPath = filepath.Join(cfg.RootPath, cfg.ConfigPath)
	}
	if !filepath.IsAbs(cfg.SecretsPath) && cfg.RootPath != "." {
		cfg.SecretsPath = filepath.Join(cfg.RootPath, cfg.SecretsPath)
	}
	
	// DNS domain inherits from top-level domain
	if cfg.DNS.Domain == "" {
		cfg.DNS.Domain = cfg.Domain
	}
	
	return cfg
}

// BuildTraefikCommand builds Traefik command arguments using the new config system
// This replaces the old buildTraefikCommand function
func BuildTraefikCommand(cfg *Config, tsHostname string) []string {
	domain := cfg.Domain
	
	cmd := []string{
		"--accessLog=true",
		"--accessLog.bufferingSize=0",
		"--accessLog.fields.headers.defaultMode=drop",
		"--accessLog.fields.headers.names.User-Agent=keep",
		"--accessLog.fields.names.StartUTC=drop",
		"--accessLog.filePath=/var/log/traefik/traefik.log",
		"--accessLog.filters.statusCodes=100-999",
		"--accessLog.format=json",
		"--metrics.prometheus.buckets=0.1,0.3,1.2,5.0",
		"--api.dashboard=true",
		"--api.debug=true",
		"--api.disableDashboardAd=true",
		"--api.insecure=true",
		"--api=true",
		fmt.Sprintf("--certificatesResolvers.%s.acme.caServer=%s", cfg.Traefik.CertResolver, getEnv("TRAEFIK_CA_SERVER", "https://acme-v02.api.letsencrypt.org/directory")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.dnsChallenge=%s", cfg.Traefik.CertResolver, getEnv("TRAEFIK_DNS_CHALLENGE", "true")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.dnsChallenge.provider=cloudflare", cfg.Traefik.CertResolver),
		fmt.Sprintf("--certificatesResolvers.%s.acme.dnsChallenge.resolvers=%s", cfg.Traefik.CertResolver, getEnv("TRAEFIK_DNS_RESOLVERS", "1.1.1.1,1.0.0.1")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.email=%s", cfg.Traefik.CertResolver, getEnv("ACME_RESOLVER_EMAIL", "")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.httpChallenge=%s", cfg.Traefik.CertResolver, getEnv("TRAEFIK_HTTP_CHALLENGE", "false")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.httpChallenge.entryPoint=web", cfg.Traefik.CertResolver),
		fmt.Sprintf("--certificatesResolvers.%s.acme.tlsChallenge=%s", cfg.Traefik.CertResolver, getEnv("TRAEFIK_TLS_CHALLENGE", "false")),
		fmt.Sprintf("--certificatesResolvers.%s.acme.storage=/certs/acme.json", cfg.Traefik.CertResolver),
		fmt.Sprintf("--entryPoints.web.address=:%d", cfg.Traefik.WebPort),
		"--entryPoints.web.http.redirections.entryPoint.scheme=https",
		"--entryPoints.web.http.redirections.entryPoint.to=websecure",
		fmt.Sprintf("--entryPoints.websecure.address=:%d", cfg.Traefik.WebSecurePort),
		"--entryPoints.websecure.http.encodeQuerySemiColons=true",
		fmt.Sprintf("--entryPoints.websecure.http.middlewares=%s", cfg.GetTraefikMiddlewares()),
		"--entryPoints.websecure.http.tls=true",
		fmt.Sprintf("--entryPoints.websecure.http.tls.certResolver=%s", cfg.Traefik.CertResolver),
		fmt.Sprintf("--entryPoints.websecure.http.tls.domains[0].main=%s", domain),
	}
	
	// Build SANs (Subject Alternative Names) for TLS
	sans := fmt.Sprintf("www.%s,*.%s", domain, domain)
	if tsHostname != "" {
		sans += fmt.Sprintf(",*.%s.%s", tsHostname, domain)
	}
	cmd = append(cmd, fmt.Sprintf("--entryPoints.websecure.http.tls.domains[0].sans=%s", sans))
	
	// Add Cloudflare trusted IPs if configured
	if len(cfg.Traefik.CloudflareTrustedIPs) > 0 {
		trustedIPs := fmt.Sprintf("--entryPoints.web.forwardedHeaders.trustedIPs=%s", joinStrings(cfg.Traefik.CloudflareTrustedIPs, ","))
		cmd = append(cmd, trustedIPs)
		trustedIPsSecure := fmt.Sprintf("--entryPoints.websecure.forwardedHeaders.trustedIPs=%s", joinStrings(cfg.Traefik.CloudflareTrustedIPs, ","))
		cmd = append(cmd, trustedIPsSecure)
	}
	
	cmd = append(cmd,
		"--entryPoints.websecure.http2.maxConcurrentStreams=100",
		"--entryPoints.websecure.http3",
		"--global.checkNewVersion=true",
		"--global.sendAnonymousUsage=false",
		"--log.level=INFO",
		"--ping=true",
		"--providers.docker=true",
		fmt.Sprintf("--providers.docker.endpoint=%s", getEnv("TRAEFIK_DOCKER_HOST", "unix:///var/run/docker.sock")),
		fmt.Sprintf("--providers.docker.network=%s", cfg.GetFullNetworkName("publicnet")),
		fmt.Sprintf("--providers.docker.defaultRule=Host(`{{ normalize .ContainerName }}.%s`) || Host(`{{ normalize .Name }}.%s`)", domain, domain),
		"--providers.docker.exposedByDefault=false",
		"--providers.file.directory=/traefik/dynamic/",
		"--providers.file.watch=true",
		"--experimental.plugins.bouncer.modulename=github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin",
		"--experimental.plugins.bouncer.version=v1.4.6",
		"--experimental.plugins.traefikerrorreplace.modulename=github.com/PseudoResonance/traefikerrorreplace",
		"--experimental.plugins.traefikerrorreplace.version=v1.0.1",
		"--serversTransport.insecureSkipVerify=true",
	)
	
	// Add node-specific rules if hostname is provided
	if tsHostname != "" {
		defaultRule := fmt.Sprintf("--providers.docker.defaultRule=Host(`{{ normalize .ContainerName }}.%s`) || Host(`{{ normalize .Name }}.%s`) || Host(`{{ normalize .ContainerName }}.%s.%s`) || Host(`{{ normalize .Name }}.%s.%s`)", domain, domain, tsHostname, domain, tsHostname, domain)
		cmd[len(cmd)-4] = defaultRule // Replace the defaultRule line
	}
	
	return cmd
}

func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	if len(strs) == 1 {
		return strs[0]
	}
	result := strs[0]
	for _, s := range strs[1:] {
		result += sep + s
	}
	return result
}

