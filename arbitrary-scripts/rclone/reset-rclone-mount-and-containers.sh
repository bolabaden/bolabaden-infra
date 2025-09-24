#!/bin/bash

sudo fusermount -u /mnt/remote/realdebrid
docker compose up -d --remove-orphans --force-recreate zurg riven
