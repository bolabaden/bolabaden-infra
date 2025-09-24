# Use Ubuntu as the base image
FROM ubuntu:20.04

# Set noninteractive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages including docker.io and curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      docker.io \
      curl \
      iproute2 \
      net-tools \
      ca-certificates \
      sudo \
      bash && \
    rm -rf /var/lib/apt/lists/*

# Expose the necessary ports for the services
# LibreChat port (default 3080), MongoDB (default 27017), Meilisearch (default 7700)
EXPOSE 3080 27017 7700

# Set environment variables for common settings (defaults as per docker-compose)
# These may be overridden at runtime
ENV PGID=112 \
    PUID=1000 \
    TZ=America/Chicago \
    DOMAIN=localhost \
    ROOT_DIR=. \
    LIBRECHAT_PORT=3080 \
    LIBRECHAT_ALLOW_EMAIL_LOGIN=true \
    LIBRECHAT_ALLOW_REGISTRATION=true \
    LIBRECHAT_ALLOW_SOCIAL_LOGIN=true \
    LIBRECHAT_ALLOW_SOCIAL_REGISTRATION=true \
    LIBRECHAT_CREDS_KEY=your_creds_key \
    LIBRECHAT_CREDS_IV=your_creds_iv \
    LIBRECHAT_HOST=0.0.0.0 \
    LIBRECHAT_JWT_REFRESH_SECRET=your_jwt_refresh_secret \
    LIBRECHAT_JWT_SECRET=your_jwt_secret \
    MEILI_PORT=7700 \
    LIBRECHAT_MONGODB_PORT=27017 \
    LIBRECHAT_RAG_PORT=8005 \
    LIBRECHAT_REFRESH_TOKEN_EXPIRY=54000000 \
    LIBRECHAT_SESSION_EXPIRY=604800000 \
    LIBRECHAT_SESSION_SECRET=your_session_secret \
    LIBRECHAT_RAG_DB_HOST=vectordb \
    OPENAI_API_KEY=your_openai_api_key \
    VECTORDB_POSTGRES_DB=librechat \
    VECTORDB_POSTGRES_USER=myuser \
    VECTORDB_POSTGRES_PASSWORD=mypassword \
    MEILI_DB_PATH=/data.ms \
    MEILI_ENV=development \
    MEILI_LOG_LEVEL=info \
    MEILI_MASTER_KEY=your_meili_master_key \
    MEILI_NO_ANALYTICS=true

# The entrypoint script that will start the docker daemon and launch all containers
CMD bash -c startup.sh 