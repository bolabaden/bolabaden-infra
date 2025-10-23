#!/bin/bash
# Container management script for media stack

CONTAINERS="plex riven-frontend riven blackhole"

case "$1" in
  start)
    echo "Starting media stack containers..."
    for container in $CONTAINERS; do
      if docker ps -a --format "table {{.Names}}" | grep -q "^$container$"; then
        echo "Starting $container..."
        docker start $container
      fi
    done
    ;;
  stop)
    echo "Stopping media stack containers..."
    for container in $CONTAINERS; do
      if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        echo "Stopping $container..."
        docker stop $container
      fi
    done
    ;;
  restart)
    echo "Restarting media stack containers..."
    $0 stop
    sleep 5
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac