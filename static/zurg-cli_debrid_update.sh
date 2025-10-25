#!/bin/bash
webhook_url="http://cli-debrid:5000/webhook/rclone"  # Replace with your actual webhook URL
# First notify our webhook for each file
for arg in "$@"
do
    arg_clean=$(echo "$arg" | sed 's/\\//g')
    echo "Notifying webhook for: $arg_clean"
    encoded_webhook_arg=$(echo -n "$arg_clean" | python3 -c "import sys, urllib.parse as ul; print(ul.quote(sys.stdin.read()))")
    curl -s -X GET "$webhook_url?file=$encoded_webhook_arg"
done
echo "Updates completed!"