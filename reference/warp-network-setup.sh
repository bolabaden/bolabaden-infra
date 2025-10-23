#!/bin/bash

# Start the Warp container
docker-compose up -d warp

# Wait for Warp to be ready
sleep 5

# Example: Run a container that uses Warp's network
# Any container started with --network container:warp will use Warp's network stack
docker run --rm --network container:warp alpine wget -qO- ifconfig.me

# For docker-compose, add this to other services:
# network_mode: "container:warp" 