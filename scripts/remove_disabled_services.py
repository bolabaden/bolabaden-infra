#!/usr/bin/env python3
"""Remove services with profiles (disabled) from Nomad HCL file."""

import re
import sys

# Services to remove (have profiles set in docker-compose)
DISABLED_SERVICES = [
    "code-server",
    "dns-server",
    "model-updater",
    "qdrant",
    "mcp-proxy",
    "comet",
    "mediafusion",
    "mediaflow-proxy"
]

def find_task_block(lines, task_name):
    """Find the start and end line numbers for a task block."""
    task_start = None
    task_end = None
    
    # Find task start
    for i, line in enumerate(lines):
        if re.search(rf'task\s+"{task_name}"\s*{{', line):
            task_start = i
            break
    
    if task_start is None:
        return None, None
    
    # Find task end by counting braces
    brace_count = 0
    for i in range(task_start, len(lines)):
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0 and i > task_start:
            task_end = i
            break
    
    return task_start, task_end

def main():
    nomad_file = '/home/ubuntu/my-media-stack/nomad/docker-compose.nomad.hcl'
    
    # Read file
    with open(nomad_file, 'r') as f:
        lines = f.readlines()
    
    # Track all lines to remove
    lines_to_remove = set()
    
    for service in DISABLED_SERVICES:
        start, end = find_task_block(lines, service)
        if start is not None and end is not None:
            print(f"Found {service}: lines {start+1}-{end+1}")
            # Mark all lines in this task for removal
            for i in range(start, end + 1):
                lines_to_remove.add(i)
        else:
            print(f"Service {service} not found in Nomad file")
    
    # Create new content without removed lines
    new_lines = [line for i, line in enumerate(lines) if i not in lines_to_remove]
    
    # Write back
    with open(nomad_file, 'w') as f:
        f.writelines(new_lines)
    
    print(f"\nRemoved {len(lines_to_remove)} lines from {nomad_file}")
    print(f"New file size: {len(new_lines)} lines (was {len(lines)} lines)")

if __name__ == '__main__':
    main()

