# Configuration CLI Tool

A command-line tool for managing and validating infrastructure configuration.

## Installation

```bash
go build -o config-tool ./cmd/config
```

## Usage

### Validate Configuration

```bash
# Validate configuration file
./config-tool -config config.yaml -validate

# Validate using environment variable
CONFIG_FILE=config.yaml ./config-tool -validate
```

### Show Configuration Summary

```bash
# Show full summary
./config-tool -config config.yaml

# Show specific section
./config-tool -config config.yaml -show traefik
./config-tool -config config.yaml -show dns
./config-tool -config config.yaml -show cluster
./config-tool -config config.yaml -show registry
./config-tool -config config.yaml -show domain
```

### Export Configuration

```bash
# Export as JSON
./config-tool -config config.yaml -export

# Save to file
./config-tool -config config.yaml -export > config.json
```

### Compare Configurations

```bash
# Compare two configuration files
./config-tool -config config1.yaml -diff config2.yaml
```

## Examples

### Validate and Show Summary

```bash
$ ./config-tool -config production.yaml -validate
✓ Configuration is valid

$ ./config-tool -config production.yaml
Configuration Summary
====================
Domain:        example.com
Stack Name:    production
Node Name:     node1
Config Path:   /opt/infra/volumes
Secrets Path:  /opt/infra/secrets
Data Dir:      /opt/infra/data

Traefik:
  Web Port:        80
  WebSecure Port:  443
  HTTP Provider:   8081
  Cert Resolver:   letsencrypt
  Middlewares:     error-pages@file,crowdsec@file,strip-www@file

Cluster:
  Bind Port:  7946
  Raft Port:  8300
  API Port:   8080
  Priority:   100

Registry:
  Image Prefix:     docker.io/myorg
  Default Registry: docker.io
```

### Show Specific Section

```bash
$ ./config-tool -config production.yaml -show traefik
Traefik Configuration:
  Web Port:        80
  WebSecure Port:  443
  HTTP Provider:   8081
  Cert Resolver:   letsencrypt
  Error Pages:     error-pages@file
  Crowdsec:        crowdsec@file
  Strip WWW:       strip-www@file
  Middlewares:     error-pages@file,crowdsec@file,strip-www@file
```

### Export Configuration

```bash
$ ./config-tool -config production.yaml -export | jq .
{
  "Domain": "example.com",
  "StackName": "production",
  "NodeName": "node1",
  ...
}
```

### Compare Configurations

```bash
$ ./config-tool -config dev.yaml -diff prod.yaml
Configuration Differences
=========================
Domain: localhost -> example.com
Stack Name: dev -> production
Traefik Web Port: 8080 -> 80
Traefik WebSecure Port: 8443 -> 443
Cluster Priority: 100 -> 50
```

## Command-Line Options

- `-config <file>`: Path to configuration YAML file (or use CONFIG_FILE env var)
- `-validate`: Validate configuration and exit
- `-export`: Export configuration as JSON
- `-show <section>`: Show specific config section (domain, traefik, dns, cluster, registry)
- `-diff <file>`: Compare with another config file

## Integration

The CLI tool can be integrated into CI/CD pipelines:

```bash
#!/bin/bash
# Validate configuration before deployment
if ! ./config-tool -config config.yaml -validate; then
    echo "Configuration validation failed!"
    exit 1
fi
```
