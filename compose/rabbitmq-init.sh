#!/bin/bash
set -e

# Start RabbitMQ in background
rabbitmq-server -detached

# Wait for RabbitMQ to be ready (with timeout)
TIMEOUT=60
ELAPSED=0
until rabbitmqctl status > /dev/null 2>&1; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Timeout waiting for RabbitMQ to start"
    exit 1
  fi
  echo "Waiting for RabbitMQ to start..."
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

# Get username and password from environment
RABBITMQ_USER="${RABBITMQ_DEFAULT_USER:-rabbitmq}"
RABBITMQ_PASS="${RABBITMQ_DEFAULT_PASS:-rabbitmq}"

# Check if user exists, create if not
if ! rabbitmqctl list_users 2>/dev/null | grep -q "^${RABBITMQ_USER}[[:space:]]"; then
  echo "Creating RabbitMQ user: ${RABBITMQ_USER}"
  rabbitmqctl add_user "${RABBITMQ_USER}" "${RABBITMQ_PASS}" 2>/dev/null || true
  rabbitmqctl set_permissions -p / "${RABBITMQ_USER}" ".*" ".*" ".*" 2>/dev/null || true
  rabbitmqctl set_user_tags "${RABBITMQ_USER}" administrator 2>/dev/null || true
  echo "User ${RABBITMQ_USER} created successfully"
else
  echo "User ${RABBITMQ_USER} already exists"
fi

# Stop the detached server
rabbitmqctl stop

# Start RabbitMQ in foreground
exec rabbitmq-server
