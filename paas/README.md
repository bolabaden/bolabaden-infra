# PaaS - Platform as a Service Converter

A comprehensive platform-as-a-service system that enables seamless conversion between different container orchestration formats including Docker Compose, Nomad HCL, and Kubernetes manifests.

## Features

- **Multi-format Support**: Load and convert between Docker Compose YAML, Nomad HCL, and Kubernetes YAML
- **Helm Chart Support**: Parse and generate Helm charts for Kubernetes deployments
- **Roundtrip Testing**: Comprehensive tests ensure fidelity across format conversions
- **Infra Integration**: Direct deployment to Go-based infrastructure code
- **CLI Tool**: Command-line interface for all operations
- **Application Merging**: Combine multiple applications into unified deployments
- **Validation**: Built-in validation for all supported formats

## Supported Formats

- **Docker Compose**: `docker-compose.yml` files with full service, network, volume, config, and secret support
- **Nomad HCL**: HashiCorp Nomad job specifications
- **Kubernetes YAML**: Standard Kubernetes manifests and resource definitions
- **Helm Charts**: Kubernetes packages with templating support

## Installation

```bash
cd paas
go build -o paas cmd/paas/main.go
```

## Usage

### Basic Conversion

```bash
# Convert Docker Compose to Nomad HCL
./paas -input docker-compose.yml -output nomad.hcl -from docker-compose -to nomad

# Convert Nomad HCL to Kubernetes YAML
./paas -input nomad.hcl -output k8s.yaml -from nomad -to kubernetes

# Convert Kubernetes to Docker Compose
./paas -input k8s.yaml -output docker-compose.yml -from kubernetes -to docker-compose
```

### Validation and Analysis

```bash
# Validate a Docker Compose file
./paas -input docker-compose.yml -validate

# List all services in an application
./paas -input nomad.hcl -list-services
```

### Application Merging

```bash
# Merge multiple compose files
./paas -merge app.yml,db.yml,monitoring.yml -output merged.yml
```

### Infra Deployment

```bash
# Deploy Docker Compose to Go infra code
./paas -input docker-compose.yml -deploy -infra-path ../infra
```

## Architecture

### Core Components

- **`model.go`**: Unified data model representing services, networks, volumes, configs, and secrets
- **`paas.go`**: Main PaaS engine with conversion and validation logic
- **`docker_compose.go`**: Docker Compose parser and serializer
- **`nomad.go`**: Nomad HCL parser and serializer
- **`kubernetes.go`**: Kubernetes YAML parser and serializer
- **`helm.go`**: Helm chart support
- **`infra_integration.go`**: Integration with existing Go infrastructure

### Data Model

The unified `Application` struct supports:

```go
type Application struct {
    Version   string
    Platform  Platform
    Services  map[string]*Service
    Networks  map[string]*Network
    Volumes   map[string]*Volume
    Configs   map[string]*Config
    Secrets   map[string]*Secret
    Extensions map[string]interface{} // Platform-specific extensions
}
```

### Roundtrip Testing

The system includes comprehensive roundtrip tests that verify:

1. **Docker Compose → Nomad → Docker Compose**
2. **Docker Compose → Kubernetes → Docker Compose**
3. **Nomad → Kubernetes → Nomad**
4. **Serialize/Deserialize fidelity**

Run tests with:

```bash
go test -v
```

## API Usage

### Programmatic Usage

```go
package main

import (
    "github.com/your-org/my-media-stack/paas"
)

func main() {
    // Create PaaS instance
    paas := paas.New(&paas.PaaSConfig{
        WorkDir: "/tmp/paas",
    })

    // Load application
    app, err := paas.LoadFile("docker-compose.yml")
    if err != nil {
        panic(err)
    }

    // Convert to different format
    nomadApp, err := paas.Convert(app, paas.PlatformDockerCompose, paas.PlatformNomad)
    if err != nil {
        panic(err)
    }

    // Save converted application
    err = paas.SaveFile(nomadApp, "nomad.hcl")
    if err != nil {
        panic(err)
    }
}
```

### Infra Integration

```go
// Deploy application to Go infrastructure
integration, err := paas.NewInfraIntegration("../infra")
if err != nil {
    panic(err)
}

err = integration.DeployToInfra(app, "services_generated")
if err != nil {
    panic(err)
}
```

## Limitations

### Current Limitations

1. **Nomad HCL**: Basic parsing, full HCL AST parsing would require extensive work
2. **Kubernetes**: Basic YAML parsing, complex resource relationships not fully modeled
3. **Helm**: Directory-based charts, inline chart generation limited
4. **Advanced Features**: Some platform-specific features may not be fully supported

### Future Enhancements

- Complete HCL AST parsing for Nomad
- Full Kubernetes resource model with relationships
- Advanced Helm templating support
- Service mesh integration
- CI/CD pipeline integration
- Multi-cluster deployment support

## Testing

### Unit Tests

```bash
go test ./...
```

### Roundtrip Tests

```bash
go test -run TestRoundTrip
```

### Benchmarking

```bash
go test -bench=.
```

## Contributing

1. Follow Go best practices and conventions
2. Add tests for new functionality
3. Ensure roundtrip tests pass
4. Update documentation
5. Use conventional commit messages

## License

This project is part of the my-media-stack infrastructure and follows the same licensing terms.