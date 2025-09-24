#!/bin/bash

apt update
apt upgrade -y
apt install wget -y

DOCKER_VERSION="28.4.0"  # latest as of now.
wget https://download.docker.com/linux/static/stable/$(uname -m)/docker-$DOCKER_VERSION.tgz
mv docker-$DOCKER_VERSION.tgz docker.tgz
tar xzvf docker.tgz
cp docker/docker /usr/local/bin/
mkdir -p /usr/local/lib/docker/cli-plugins
VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -SL "https://github.com/docker/compose/releases/download/v${VERSION}/docker-compose-linux-$(uname -m)" \
  -o docker-compose
mv docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

docker compose version