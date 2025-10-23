#!/bin/bash

set -o allexport
source ${ROOT_DIR:-.}/.env
set +o allexport

mkdir -p ${ROOT_DIR:-.}/configs/alertmanager/config
touch ${ROOT_DIR:-.}/configs/alertmanager/config/alertmanager.yml

mkdir -p ${ROOT_DIR:-.}/configs/authelia/config
touch ${ROOT_DIR:-.}/configs/authelia/configuration.yml

mkdir -p ${ROOT_DIR:-.}/configs/autobrr/config
touch ${ROOT_DIR:-.}/configs/autobrr/config/config.toml

mkdir -p ${ROOT_DIR:-.}/configs/buildarr
touch ${ROOT_DIR:-.}/configs/buildarr/buildarr.yml

mkdir -p ${ROOT_DIR:-.}/configs/checkrr/config
touch ${ROOT_DIR:-.}/configs/checkrr/config/checkrr.db
touch ${ROOT_DIR:-.}/configs/checkrr/config/checkrr.yaml

mkdir -p ${ROOT_DIR:-.}/configs/dashy
touch ${ROOT_DIR:-.}/configs/dashy/conf.yml

mkdir -p ${ROOT_DIR:-.}/configs/gluetun
touch ${ROOT_DIR:-.}/configs/gluetun/client.crt
touch ${ROOT_DIR:-.}/configs/gluetun/client.key

mkdir -p ${ROOT_DIR:-.}/configs/janitorr/config
touch ${ROOT_DIR:-.}/configs/janitorr/config/application.yml

mkdir -p ${ROOT_DIR:-.}/certs
touch ${ROOT_DIR:-.}/certs/acme.json
chmod ${ROOT_DIR:-.}/certs/acme.json 600

mkdir -p ${ROOT_DIR:-.}/configs/librechat
touch ${ROOT_DIR:-.}/configs/librechat/.env

mkdir -p ${ROOT_DIR:-.}/configs/managarr
touch ${ROOT_DIR:-.}/configs/managarr/config.yml

mkdir -p ${ROOT_DIR:-.}/configs/mosquitto/config
touch ${ROOT_DIR:-.}/configs/mosquitto/config/mosquitto.conf

mkdir -p ${ROOT_DIR:-.}/configs/notifiarr
touch ${ROOT_DIR:-.}/configs/notifiarr/notifiarr.conf

mkdir -p ${ROOT_DIR:-.}/configs/grafana
touch ${ROOT_DIR:-.}/configs/grafana/datasource.yaml

docker node update --label-add node.type=leader bolabaden-the-fourth
docker node update --label-add storage=true bolabaden-the-fourth
docker node update --label-add manager_priority=1 bolabaden-the-fourth

docker node update --label-add node.type=manager micklethefickle3
docker node update --label-add storage=true micklethefickle3
docker node update --label-add worker_priority=2 micklethefickle3

docker node update --label-add node.type=worker docker-desktop
docker node update --label-add worker_priority=1 docker-desktop

docker network create \
--driver overlay \
  portainer_agent_network

docker service create \
  --name portainer_agent \
  --network portainer_agent_network \
  -p 9001:9001/tcp \
  --mode global \
  --constraint 'node.platform.os == linux' \
  --mount type=bind,src=//var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=//var/lib/docker/volumes,dst=/var/lib/docker/volumes \
  --mount type=bind,src=//,dst=/host \
  portainer/agent:2.27.2


mkdir -p ${SECRETS_DIR:-./secrets}

# Install required packages
if ! command -v apache2-utils &>/dev/null || ! command -v fuse3 &>/dev/null; then
  sudo apt-get install apache2-utils fuse3 -y
fi

# Create secrets directory if it doesn't exist
mkdir -p ${SECRETS_DIR:-./secrets}

# Helper function to generate random password
generate_password() {
  local length=$1
  openssl rand -base64 $length | tr -d '/+=' | cut -c1-$length
}

# Create htpasswd files if they don't exist
if [ "${STACK_INTERACTIVE:-false}" = "true" ]; then
  if [ ! -f "${SECRETS_DIR:-./secrets}/traefik_forward_auth.txt" ]; then
    htpasswd -B -C 10 -c .htpasswd your_traefik_username
    cat .htpasswd | sed -e s/\\$/\\$\\$/g >${SECRETS_DIR:-./secrets}/traefik_forward_auth.txt
  fi
else
  # Traefik auth
  [ ! -f "${SECRETS_DIR:-./secrets}/traefik_forward_auth.txt" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/traefik_forward_auth.txt

  # Authelia secrets
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-jwt_secret" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia-jwt_secret
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-session_secret" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia-session_secret
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-storage_encryption_key" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia-storage_encryption_key
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-storage_mysql_password" ] && generate_password 16 >${SECRETS_DIR:-./secrets}/authelia-storage_mysql_password
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-notifier_smtp_password" ] && generate_password 16 >${SECRETS_DIR:-./secrets}/authelia-notifier_smtp_password
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-duo_api_secret_key" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia-duo_api_secret_key
  [ ! -f "${SECRETS_DIR:-./secrets}/authelia-session_redis_password" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia-session_redis_password

  # Authentik secrets
  [ ! -f "${SECRETS_DIR:-./secrets}/authentik/postgresql_password" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authentik/postgresql_password
  [ ! -f "${SECRETS_DIR:-./secrets}/authentik/token" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authentik/token
  [ ! -f "${SECRETS_DIR:-./secrets}/authentik/secret_key" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authentik/secret_key

  # Khoj secrets
  [ ! -f "${SECRETS_DIR:-./secrets}/khoj_django_secret_key" ] && generate_password 64 >${SECRETS_DIR:-./secrets}/khoj_django_secret_key
fi
[ ! -f "${SECRETS_DIR:-./secrets}/authelia_session_secret" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia_session_secret
[ ! -f "${SECRETS_DIR:-./secrets}/authelia_storage_encryption_key" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia_storage_encryption_key
[ ! -f "${SECRETS_DIR:-./secrets}/authelia_storage_mysql_password" ] && generate_password 16 >${SECRETS_DIR:-./secrets}/authelia_storage_mysql_password
[ ! -f "${SECRETS_DIR:-./secrets}/authelia_storage_redis_password" ] && generate_password 32 >${SECRETS_DIR:-./secrets}/authelia_storage_redis_password
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_api_key" ] && generate_password 8 > ${SECRETS_DIR:-./secrets}/librechat_api_key
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_creds_iv" ] && generate_password 8 > ${SECRETS_DIR:-./secrets}/librechat_creds_iv
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_creds_key" ] && generate_password 8 > ${SECRETS_DIR:-./secrets}/librechat_creds_key
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_jwt_refresh_secret" ] && generate_password 32 > ${SECRETS_DIR:-./secrets}/librechat_jwt_refresh_secret
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_jwt_secret" ] && generate_password 32 > ${SECRETS_DIR:-./secrets}/librechat_jwt_secret
[ ! -f "${SECRETS_DIR:-./secrets}/librechat_session_secret" ] && generate_password 32 > ${SECRETS_DIR:-./secrets}/librechat_session_secret
[ ! -f "${SECRETS_DIR:-./secrets}/jellystat_jwt_secret" ] && generate_password 32 > ${SECRETS_DIR:-./secrets}/jellystat_jwt_secret
[ ! -f "${SECRETS_DIR:-./secrets}/umami_app_secret" ] && generate_password 32 > ${SECRETS_DIR:-./secrets}/umami_app_secret
[ ! -f "${SECRETS_DIR:-./secrets}/umami_db_password" ] && generate_password 8 > ${SECRETS_DIR:-./secrets}/umami_db_password

if [ -n "$USE_DOCKER_SWARM" ]; then # not tested, leave for future use
  docker stack deploy --compose-file ${ROOT_DIR:-.}/docker-compose.yml ${STACK_NAME:-my-bolabaden-stack}

else
  HOST_ARCH=$(uname -m)
  echo "Host architecture: '$HOST_ARCH'"
  case $HOST_ARCH in
  arm* | aarch64)
    docker compose --profile main --profile arm -f ${ROOT_DIR:-.}/docker-compose.yml up --build -d -y --remove-orphans "$@"
    ;;
  x86_64 | amd64 | x86)
    docker compose --profile main --profile x86_64 -f ${ROOT_DIR:-.}/docker-compose.yml up --build -d -y --remove-orphans "$@"
    ;;
  ppc64le | ppc64)
    docker compose --profile main --profile ppc64le -f ${ROOT_DIR:-.}/docker-compose.yml up --build -d -y --remove-orphans "$@"
    ;;
  riscv64)
    docker compose --profile main --profile riscv64 -f ${ROOT_DIR:-.}/docker-compose.yml up --build -d -y --remove-orphans "$@"
    ;;
  *)
    echo "Unsupported architecture: '$HOST_ARCH'"
    exit 1
    ;;
  esac
fi
