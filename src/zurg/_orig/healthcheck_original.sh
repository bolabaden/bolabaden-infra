#!/bin/sh
response=$(curl -o /dev/null -s -w "%{http_code}" "http://localhost:9999/http/version.txt")
if [ "$response" -eq 200 ]; then
    exit 0
else
    exit 1
fi
