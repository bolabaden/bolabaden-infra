#!/usr/bin/env python3
"""
Script to restructure Nomad HCL file to avoid port conflicts.
Splits large task groups into smaller groups where each service gets its own group.
"""

import re
import sys

def extract_task(content, task_name, start_idx):
    """Extract a complete task block starting from start_idx."""
    lines = content[start_idx:]
    task_lines = []
    brace_count = 0
    in_task = False
    
    for i, line in enumerate(lines):
        if not in_task and re.match(r'\s*task\s+"' + task_name + '"', line):
            in_task = True
            task_lines.append(line)
            continue
        
        if in_task:
            task_lines.append(line)
            # Count braces to find end of task
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0 and len(task_lines) > 1:
                return task_lines, start_idx + i + 1
    
    return task_lines, len(content)

def main():
    # Read the Nomad file
    with open('/home/ubuntu/my-media-stack/nomad/docker-compose.nomad.hcl', 'r') as f:
        content = f.readlines()
    
    # Find the coolify-proxy-services group
    group_start = None
    for i, line in enumerate(content):
        if 'group "coolify-proxy-services"' in line:
            group_start = i
            break
    
    if group_start is None:
        print("Could not find coolify-proxy-services group")
        sys.exit(1)
    
    print(f"Found coolify-proxy-services at line {group_start + 1}")
    
    # Extract traefik task
    traefik_start = None
    for i in range(group_start, len(content)):
        if re.match(r'\s*task\s+"traefik"', content[i]):
            traefik_start = i
            break
    
    if traefik_start:
        print(f"Found traefik task at line {traefik_start + 1}")
        traefik_lines, traefik_end = extract_task(content, "traefik", traefik_start)
        print(f"Traefik task is {len(traefik_lines)} lines long")
        print(f"First line: {traefik_lines[0].strip()}")
        print(f"Last line: {traefik_lines[-1].strip()}")

if __name__ == "__main__":
    main()

