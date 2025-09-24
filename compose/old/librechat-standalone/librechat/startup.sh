# Start the Docker daemon in the background
/usr/bin/dockerd &

# Wait for the dockerd to come up
sleep 10

# Create networks with the same settings as in docker-compose
# Create librechat_network with IPAM configuration
if ! docker network ls | grep -q librechat_network; then
    docker network create \
        --driver=bridge \
        --subnet=172.20.0.0/16 \
        --ip-range=172.20.4.0/24 \
        --gateway=172.20.0.1 \
        librechat_network
fi

# Launch librechat-mongodb (depends on no other service)
docker run -d \
    --name librechat-mongodb \
    --hostname librechat-mongodb \
    --network librechat_network \
    --add-host host.docker.internal:host-gateway \
    -p ${LIBRECHAT_MONGODB_PORT}:27017 \
    -v ${ROOT_DIR}/configs/librechat/data-node:/data/db \
    -e PGID=${PGID} -e PUID=${PUID} -e TZ=${TZ} \
    --restart=always \
    mongo \
    mongod --noauth

# Launch vectordb
docker run -d \
    --name vectordb \
    --hostname vectordb \
    --network librechat_network \
    --add-host host.docker.internal:host-gateway \
    -v ${ROOT_DIR}/configs/librechat/postgresql_data:/var/lib/postgresql/data \
    -e POSTGRES_DB=${VECTORDB_POSTGRES_DB} \
    -e POSTGRES_USER=${VECTORDB_POSTGRES_USER} \
    -e POSTGRES_PASSWORD=${VECTORDB_POSTGRES_PASSWORD} \
    --restart=always \
    ankane/pgvector

# Launch librechat-rag_api (depends on vectordb)
docker run -d \
    --name librechat-rag_api \
    --hostname librechat-rag_api \
    --network librechat_network \
    --add-host host.docker.internal:host-gateway \
    -v ${ROOT_DIR}/configs/librechat/.env:/app/.env \
    -e PGID=${PGID} -e PUID=${PUID} -e TZ=${TZ} \
    -e DB_HOST=${LIBRECHAT_RAG_DB_HOST} \
    -e OPENAI_API_KEY=${OPENAI_API_KEY} \
    -e RAG_PORT=${LIBRECHAT_RAG_PORT} \
    --restart=always \
    ghcr.io/danny-avila/librechat-rag-api-dev-lite

# Launch librechat (depends on librechat-mongodb and librechat-rag_api)
docker run -d \
    --name librechat \
    --hostname librechat \
    --network librechat_network \
    --add-host host.docker.internal:host-gateway \
    -p ${LIBRECHAT_PORT}:${LIBRECHAT_PORT} \
    -v ${ROOT_DIR}/configs/librechat/.env:/app/.env \
    -v ${ROOT_DIR}/configs/librechat/librechat.yaml:/app/librechat.yaml \
    -v ${ROOT_DIR}/configs/librechat/images:/app/client/public/images \
    -v ${ROOT_DIR}/configs/librechat/logs:/app/api/logs \
    -v ${ROOT_DIR}/configs/librechat/uploads:/app/uploads \
    -e PGID=${PGID} -e PUID=${PUID} -e TZ=${TZ} \
    -e ALLOW_EMAIL_LOGIN=${LIBRECHAT_ALLOW_EMAIL_LOGIN} \
    -e ALLOW_REGISTRATION=${LIBRECHAT_ALLOW_REGISTRATION} \
    -e ALLOW_SOCIAL_LOGIN=${LIBRECHAT_ALLOW_SOCIAL_LOGIN} \
    -e ALLOW_SOCIAL_REGISTRATION=${LIBRECHAT_ALLOW_SOCIAL_REGISTRATION} \
    -e CREDS_KEY=${LIBRECHAT_CREDS_KEY} \
    -e CREDS_IV=${LIBRECHAT_CREDS_IV} \
    -e HOST=${LIBRECHAT_HOST} \
    -e JWT_REFRESH_SECRET=${LIBRECHAT_JWT_REFRESH_SECRET} \
    -e JWT_SECRET=${LIBRECHAT_JWT_SECRET} \
    -e MEILI_HOST=http://${DOMAIN}:${MEILI_PORT} \
    -e MONGO_URI=mongodb://librechat-mongodb:${LIBRECHAT_MONGODB_PORT}/LibreChat \
    -e RAG_API_URL=http://librechat-rag_api:${LIBRECHAT_RAG_PORT} \
    -e RAG_PORT=${LIBRECHAT_RAG_PORT} \
    -e REFRESH_TOKEN_EXPIRY=${LIBRECHAT_REFRESH_TOKEN_EXPIRY} \
    -e SESSION_EXPIRY=${LIBRECHAT_SESSION_EXPIRY} \
    -e SESSION_SECRET=${LIBRECHAT_SESSION_SECRET} \
    --restart=always \
    ghcr.io/danny-avila/librechat-dev

# Launch meilisearch on traefik_public only
docker run -d \
    --name meilisearch \
    --hostname meilisearch \
    --network traefik_public \
    --add-host host.docker.internal:host-gateway \
    -p ${MEILI_PORT}:7700 \
    -v ${ROOT_DIR}/configs/meilisearch:/data.ms \
    -e PGID=${PGID} -e PUID=${PUID} -e TZ=${TZ} \
    -e http_proxy= \
    -e https_proxy= \
    -e MEILI_DB_PATH=${MEILI_DB_PATH} \
    -e MEILI_ENV=${MEILI_ENV} \
    -e MEILI_LOG_LEVEL=${MEILI_LOG_LEVEL} \
    -e MEILI_MASTER_KEY=${MEILI_MASTER_KEY} \
    -e MEILI_NO_ANALYTICS=${MEILI_NO_ANALYTICS} \
    --restart=always \
    getmeili/meilisearch

# End of service startup. Keep the container alive.

tail -f /dev/null
