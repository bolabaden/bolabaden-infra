FROM docker:cli AS dockercli

FROM node:slim

# Install Docker CLI for exec-ing into sibling CrowdSec container
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

WORKDIR /app

# Copy application
COPY server.js .
COPY public/ public/

ARG PORT=3000
ENV PORT=${PORT}
EXPOSE ${PORT}

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${PORT}/api/status >/dev/null || exit 1

CMD ["node", "server.js"]
