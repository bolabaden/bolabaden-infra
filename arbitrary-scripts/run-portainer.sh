#! /bin/bash

# Load environment variables from .env file
set -o allexport; source ./.env; set +o allexport

docker stop portainer
docker rm portainer

docker run -d \
  --name portainer \
  --hostname portainer \
  --add-host host.docker.internal:host-gateway \
  -p ${PORTAINER_PORT:-9443}:9443 \
  -p ${PORTAINER_PORT2:-8000}:8000 \
  -v portainer_data:/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TZ=${TZ:-America/Chicago} \
  --label homepage.group="System Monitoring" \
  --label homepage.name="Portainer" \
  --label homepage.icon="portainer.png" \
  --label homepage.href="https://portainer.${DOMAIN}/" \
  --label homepage.description="Portainer is a tool that allows you to manage your Docker containers and images." \
  --label traefik.enable="true" \
  --label traefik.http.services.portainer.loadbalancer.server.port=9443 \
  portainer/portainer-ce:lts