# Docker Compose Schema & Syntax Reference

## Overview
Docker Compose is a tool for defining and running multi-container Docker applications. This document provides comprehensive schema and syntax information for Docker Compose files.

## Basic Command Syntax
```bash
docker compose [-f <arg>...] [options] [COMMAND] [ARGS...]
```

## Core Configuration Structure

### Basic Service Definition
```yaml
services:
  webapp:
    image: examples/web
    ports:
      - "8000:8000"
    volumes:
      - "/data"
```

### Complete Service Example
```yaml
services:
  db:
    image: postgres
  web:
    build: .
    command: bundle exec rails s -p 3000 -b '0.0.0.0'
    volumes:
      - .:/myapp
    ports:
      - "3000:3000"
    depends_on:
      - db
```

## Service Configuration Options

### Image Configuration
```yaml
services:
  web:
    image: nginx:latest
    # or build from Dockerfile
    build: .
    # or build with context and dockerfile
    build:
      context: ./dir
      dockerfile: Dockerfile.dev
```

### Port Mapping
```yaml
services:
  web:
    ports:
      - "3000:3000"        # host:container
      - "127.0.0.1:8001:8001"  # bind to specific interface
      - "8002"             # random host port
```

### Volume Mounts
```yaml
services:
  web:
    volumes:
      - /var/lib/mysql                    # anonymous volume
      - /opt/data:/var/lib/mysql          # bind mount
      - ./cache:/tmp/cache                # relative path
      - ~/configs:/etc/configs/:ro        # read-only
      - datavolume:/var/lib/mysql         # named volume
```

### Environment Variables
```yaml
services:
  web:
    environment:
      - DEBUG=1
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    # or use env_file
    env_file:
      - ./common.env
      - ./apps/web.env
```

### Dependencies
```yaml
services:
  web:
    depends_on:
      - db
      - redis
```

### Resource Limits
```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 50M
        reservations:
          cpus: '0.25'
          memory: 20M
```

## Network Configuration

### Custom Networks
```yaml
services:
  web:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: backend
```

## Volume Configuration

### Named Volumes
```yaml
services:
  db:
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/on/host
```

## Advanced Features

### Health Checks
```yaml
services:
  web:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Restart Policies
```yaml
services:
  web:
    restart: unless-stopped
    # Options: no, always, on-failure, unless-stopped
```

### Logging Configuration
```yaml
services:
  web:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Profiles

### Profile Definition
```yaml
services:
  frontend:
    profiles:
      - frontend
  backend:
    profiles:
      - backend
  debug:
    profiles:
      - debug
```

### Using Profiles
```bash
docker compose --profile frontend up
docker compose --profile frontend --profile debug up
```

## Extension Fields

### Custom Fields
```yaml
services:
  web:
    x-custom-field: value
    x-other-field:
      nested: value
```

## External Provider Integration

### Provider Configuration
```yaml
services:
  database:
    provider:
      type: awesomecloud
      options:
        type: mysql
        size: 256
        name: myAwesomeCloudDB
```

### Provider Communication
```json
{"type": "info", "message": "preparing mysql ..."}
{"type": "setenv", "message": "URL=https://awesomecloud.com/db:1234"}
```

## Command-Line Options

### Global Options
- `--all-resources`: Include all resources, even those not used by services
- `--ansi`: Control when to print ANSI control characters ("never"|"always"|"auto")
- `--compatibility`: Run compose in backward compatibility mode
- `--dry-run`: Execute command in dry run mode
- `--env-file`: Specify an alternate environment file
- `-f, --file`: Compose configuration files
- `--parallel`: Control max parallelism, -1 for unlimited
- `--profile`: Specify a profile to enable
- `--progress`: Set type of progress output (auto, tty, plain, json, quiet)
- `--project-directory`: Specify an alternate working directory
- `-p, --project-name`: Project name

## Subcommands

### Core Commands
- `attach`: Attach local standard input, output, and error streams to a service's running container
- `build`: Build or rebuild services
- `config`: Parse, resolve and render compose file in canonical format
- `create`: Creates containers for a service
- `down`: Stop and remove containers, networks
- `exec`: Execute a command in a running container
- `images`: List images used by the created containers
- `logs`: View output from containers
- `ls`: List running compose projects
- `pause`: Pause services
- `port`: Print the public port for a port binding
- `ps`: List containers
- `pull`: Pull service images
- `push`: Push service images
- `restart`: Restart service containers
- `rm`: Removes stopped service containers
- `run`: Run a one-off command on a service
- `scale`: Scale services
- `start`: Start services
- `stop`: Stop services
- `top`: Display the running processes
- `unpause`: Unpause services
- `up`: Create and start containers
- `version`: Show the Docker Compose version information
- `volumes`: List volumes
- `wait`: Block until containers of all (or specified) services stop
- `watch`: Watch build context for service and rebuild/refresh containers when files are updated

### Advanced Commands
- `alpha generate`: EXPERIMENTAL - Generate a Compose file from existing containers
- `alpha publish`: EXPERIMENTAL - Publish compose application
- `alpha viz`: EXPERIMENTAL - Generate a graphviz graph from your compose file
- `bridge`: Convert compose files to Kubernetes manifests, Helm charts, or another model
- `bridge convert`: Convert compose files to Kubernetes manifests, Helm charts, or another model
- `bridge transformations`: Manage transformation images

## File Formats

### YAML Format
Docker Compose files are typically written in YAML format with the following structure:
- `services`: Define the containers that make up your application
- `networks`: Define the networks your services use
- `volumes`: Define the volumes your services use
- `configs`: Define configuration files (Docker Swarm mode)
- `secrets`: Define secrets (Docker Swarm mode)

### JSON Format
Compose files can also be written in JSON format, though YAML is more commonly used due to its readability.

## Version Compatibility

### Compose File Versions
- `version: "3.8"`: Latest stable version
- `version: "3.7"`: Previous version
- `version: "3.6"`: Older version
- `version: "3.5"`: Legacy version

### Docker Engine Compatibility
- Compose file version 3.8 requires Docker Engine 19.03.0+
- Compose file version 3.7 requires Docker Engine 18.06.0+
- Compose file version 3.6 requires Docker Engine 18.02.0+
- Compose file version 3.5 requires Docker Engine 17.12.0+

## Best Practices

### Service Naming
- Use lowercase letters, numbers, and hyphens
- Avoid underscores and special characters
- Use descriptive names that indicate the service's purpose

### Configuration Organization
- Use environment variables for configuration
- Separate development and production configurations
- Use `.env` files for sensitive information
- Use profiles for different deployment scenarios

### Resource Management
- Set appropriate resource limits
- Use health checks for service monitoring
- Configure proper restart policies
- Use named volumes for persistent data

### Security
- Don't run containers as root
- Use read-only file systems where possible
- Limit container capabilities
- Use secrets for sensitive data

## Examples

### Multi-Service Application
```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    depends_on:
      - db
    volumes:
      - .:/app
      - /app/node_modules

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

### Development Environment
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    command: npm run dev

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=devdb
      - POSTGRES_USER=devuser
      - POSTGRES_PASSWORD=devpass
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data

volumes:
  postgres_dev_data:
```

This reference covers the essential aspects of Docker Compose configuration. For more detailed information, refer to the official Docker Compose documentation. 