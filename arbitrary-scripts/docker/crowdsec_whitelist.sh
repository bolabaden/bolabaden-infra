#!/bin/bash

set -xe

# Whitelist the IP address
docker exec -it crowdsec cscli allowlist create my_allowlist -d "my allowlist" || true > /dev/null 2>&1
docker exec -it crowdsec cscli allowlist add my_allowlist $(curl -s ifconfig.me)