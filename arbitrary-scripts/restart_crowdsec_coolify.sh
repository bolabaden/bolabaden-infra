(docker container stop crowdsec || true) > /dev/null 2>&1 && \
  (docker container rm crowdsec || true) > /dev/null 2>&1 && \
  (docker compose -f /data/coolify/proxy/docker-compose.coolify-proxy.yml up -d --remove-orphans crowdsec) > /dev/null 2>&1