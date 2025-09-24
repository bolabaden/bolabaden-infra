#!/bin/bash

OUTPUT_FILE_PATH=${1:-./iptables-rules.txt}
(for table in filter nat mangle raw security; do
    echo "=== Table: $table ==="
    sudo iptables -t "$table" -vnL --line-numbers
    echo
done) > $OUTPUT_FILE_PATH
