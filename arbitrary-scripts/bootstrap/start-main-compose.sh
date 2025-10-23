#!/bin/bash

# Load dotenv if FIRST_TIME_COMPOSE is set
if [ "${FIRST_TIME_COMPOSE}" ]; then
  # Touch files for container volume mounts:
  mkdir -p ./configs/alertmanager/config
  touch ./configs/alertmanager/config/alertmanager.yml
  mkdir -p ./configs/authelia/config
  touch ./configs/authelia/configuration.yml
  mkdir -p ./configs/autobrr/config
  touch ./configs/autobrr/config/config.toml
  mkdir -p ./configs/buildarr/
  touch ./configs/buildarr/buildarr.yml
  mkdir -p ./configs/checkrr/config
  touch ./configs/checkrr/config/checkrr.db
  touch ./configs/checkrr/config/checkrr.yaml
  mkdir -p ./configs/dashy
  touch ./configs/dashy/conf.yml
  mkdir -p ./configs/gluetun
  touch ./configs/gluetun/client.crt
  touch ./configs/gluetun/client.key
  mkdir -p ./configs/janitorr/config
  touch ./configs/janitorr/config/application.yml
  mkdir -p ./configs/letsencrypt
  touch ./configs/letsencrypt/acme.json
  chmod ./configs/letsencrypt/acme.json 600
  mkdir -p ./configs/librechat
  touch ./configs/librechat/.env
  mkdir -p ./configs/managarr
  touch ./configs/managarr/config.yml
  mkdir -p ./configs/mosquitto/config
  touch ./configs/mosquitto/config/mosquitto.conf
  mkdir -p ./configs/notifiarr
  touch ./configs/notifiarr/notifiarr.conf
  mkdir -p ./configs/grafana
  touch ./configs/grafana/datasource.yaml

  # Generate HASHED_ADMIN_USER_PASS using below command
  htpasswd -B -C 10 -c .htpasswd user1
  cat .htpasswd | sed -e s/\\$/\\$\\$/g

  # Generate secrets:
  mkdir -p ./secrets
  openssl rand -base64 48 | tr -d '/+=' | cut -c1-64 > ./secrets/authelia_encryption_key.txt
  openssl rand -base64 48 | tr -d '/+=' | cut -c1-64 > ./secrets/jwt_secret.txt
  openssl rand -base64 48 | tr -d '/+=' | cut -c1-64 > ./secrets/session_secret.txt
fi

# Load environment variables from .env file
set -o allexport; source ./.env; set +o allexport

if [ -n "$USE_DOCKER_SWARM" ]; then  # not tested, leave for future use
  docker stack deploy --compose-file docker-compose.yml my-stack
else
  # Detect system architecture
  HOST_ARCH=$(uname -m)

  echo "Host architecture: '$HOST_ARCH'"
  # Map common architectures to profiles
  case $HOST_ARCH in
    arm*|aarch64)
      docker compose --profile main --profile arm -f docker-compose.yml up --build -d --remove-orphans "$@"
      ;;
    x86_64|amd64|x86)
      docker compose --profile main --profile x86_64 -f docker-compose.yml up --build -d --remove-orphans "$@"
      ;;
    ppc64le|ppc64)
      docker compose --profile main --profile ppc64le -f docker-compose.yml up --build -d --remove-orphans "$@"
      ;;
    riscv64)
      docker compose --profile main --profile riscv64 -f docker-compose.yml up --build -d --remove-orphans "$@"
      ;;
    *)
      echo "Unsupported architecture: '$HOST_ARCH'"
      exit 1
      ;;
  esac
fi