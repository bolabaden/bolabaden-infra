#!/usr/bin/env python3
"""
Split Nomad task groups so each service gets its own group.
This fixes port conflicts where multiple tasks in a group share the same network namespace.
"""

import re
import sys

def find_task_blocks(lines, group_start, group_end):
    """Find all task blocks within a group."""
    tasks = []
    i = group_start
    while i < group_end:
        line = lines[i]
        task_match = re.match(r'(\s*)task\s+"([^"]+)"\s*{', line)
        if task_match:
            indent = task_match.group(1)
            task_name = task_match.group(2)
            task_start = i
            
            # Find the end of this task by counting braces
            brace_count = 1
            j = i + 1
            while j < group_end and brace_count > 0:
                brace_count += lines[j].count('{') - lines[j].count('}')
                if brace_count == 0:
                    break
                j += 1
            
            task_end = j
            tasks.append({
                'name': task_name,
                'start': task_start,
                'end': task_end,
                'indent': indent,
                'lines': lines[task_start:task_end+1]
            })
            i = task_end + 1
        else:
            i += 1
    
    return tasks

def extract_network_block(lines, group_start):
    """Extract the network block from a group."""
    # Find network block start
    network_start = None
    for i in range(group_start, min(group_start + 100, len(lines))):
        if re.match(r'\s*network\s*{', lines[i]):
            network_start = i
            break
    
    if network_start is None:
        return None, []
    
    # Find network block end
    brace_count = 1
    i = network_start + 1
    while i < len(lines) and brace_count > 0:
        brace_count += lines[i].count('{') - lines[i].count('}')
        if brace_count == 0:
            break
        i += 1
    
    network_end = i
    return (network_start, network_end), lines[network_start:network_end+1]

def main():
    with open('/home/ubuntu/my-media-stack/nomad/docker-compose.nomad.hcl', 'r') as f:
        lines = f.readlines()
    
    #  Find coolify-proxy-services group
    group_start = None
    for i, line in enumerate(lines):
        if 'group "traefik-services"' in line:
            group_start = i
            break
    
    if not group_start:
        print("Could not find traefik-services group")
        return 1
    
    print(f"Found group at line {group_start + 1}")
    
    # Find group end
    brace_count = 0
    group_end = None
    started = False
    for i in range(group_start, len(lines)):
        if '{' in lines[i]:
            started = True
        if started:
            brace_count += lines[i].count('{') - lines[i].count('}')
            if brace_count == 0 and i > group_start:
                group_end = i
                break
    
    print(f"Group ends at line {group_end + 1}")
    
    # Extract tasks
    tasks = find_task_blocks(lines, group_start, group_end)
    print(f"\nFound {len(tasks)} tasks:")
    for task in tasks:
        print(f"  - {task['name']}: lines {task['start']+1} to {task['end']+1} ({task['end'] - task['start'] + 1} lines)")
    
    # Extract network block
    network_info, network_lines = extract_network_block(lines, group_start)
    if network_info:
        print(f"\nNetwork block: lines {network_info[0]+1} to {network_info[1]+1}")

if __name__ == "__main__":
    sys.exit(main() or 0)
PYTHON

