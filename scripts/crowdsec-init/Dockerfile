FROM node:20-alpine

# Install Docker CLI for exec-ing into sibling CrowdSec container
RUN apk add --no-cache docker-cli openssl

WORKDIR /app

# Copy application
COPY server.js .
COPY public/ public/

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/status || exit 1

CMD ["node", "server.js"]
