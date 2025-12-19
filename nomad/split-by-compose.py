#!/usr/bin/env python3
"""
Split Nomad job file to match docker-compose.yml include structure exactly.
Each include file maps to a Nomad job file with matching groups.
"""
import re
from pathlib import Path

# Map compose include files to their group names (exact match from docker-compose.nomad.hcl)
COMPOSE_MAPPING = {
    # docker-compose.yml main file (services not in includes) -> core.nomad.hcl
    'core': [
        'mongodb-group', 'redis-group', 'searxng-group', 'homepage-group',
        'bolabaden-nextjs-group', 'session-manager-group', 'dozzle-group',
        'portainer-group', 'telemetry-auth-group', 'authentik-services'
    ],
    # compose/docker-compose.coolify-proxy.yml -> coolify-proxy.nomad.hcl
    'coolify-proxy': [
        'traefik-group', 'nginx-traefik-extensions-group', 'tinyauth-group',
        'crowdsec-group', 'whoami-group', 'autokuma-group', 'docker-gen-failover-group',
        'logrotate-traefik-group', 'infrastructure-services'
    ],
    # compose/docker-compose.firecrawl.yml -> firecrawl.nomad.hcl
    'firecrawl': [
        'firecrawl-group', 'playwright-service-group', 'nuq-postgres-group'
    ],
    # compose/docker-compose.headscale.yml -> headscale.nomad.hcl
    'headscale': [
        'headscale-server-group', 'headscale-group'
    ],
    # compose/docker-compose.llm.yml -> llm.nomad.hcl
    'llm': [
        'litellm-group', 'litellm-postgres-group', 'mcpo-group', 'open-webui-group',
        'gptr-group', 'qdrant-group', 'mcp-proxy-group'
    ],
    # compose/docker-compose.stremio-group.yml -> stremio-group.nomad.hcl
    'stremio-group': [
        'stremio-group', 'aiostreams-group', 'stremthru-group', 'flaresolverr-group',
        'jackett-group', 'prowlarr-group', 'rclone-group', 'rclone-init-group'
    ],
    # compose/docker-compose.warp-nat-routing.yml -> warp-nat-routing.nomad.hcl
    'warp-nat-routing': [
        'warp-nat-routing-group', 'warp-nat-routing'
    ],
}

def extract_group_manual(content, group_name):
    """Manually extract group by finding start and matching braces."""
    # Find the group definition - try multiple patterns
    patterns = [
        rf'^\s+group\s+"{re.escape(group_name)}"\s*\{{',
        rf'\s+group\s+"{re.escape(group_name)}"\s*\{{',
        rf'group\s+"{re.escape(group_name)}"\s*\{{',
    ]
    
    match = None
    for pattern in patterns:
        match = re.search(pattern, content, re.MULTILINE)
        if match:
            break
    
    if not match:
        return None
    
    # Start from the opening brace
    start_pos = match.start()
    # Find the opening brace
    pos = start_pos
    while pos < len(content) and content[pos] != '{':
        pos += 1
    if pos >= len(content):
        return None
    start_pos = pos
    
    # Now match braces
    brace_count = 0
    in_string = False
    string_char = None
    i = start_pos
    
    brace_count = 1
    i += 1
    
    while i < len(content):
        char = content[i]
        
        # Handle escaped characters
        if char == '\\' and i + 1 < len(content):
            i += 2
            continue
        
        # Handle string literals
        if char in ('"', "'"):
            if not in_string:
                in_string = True
                string_char = char
            elif char == string_char:
                in_string = False
                string_char = None
        
        if not in_string:
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    return content[match.start():i+1]
        i += 1
    
    return None

def create_job_file(job_name, compose_file, group_names, all_content, output_dir):
    """Create a Nomad job file for a compose include file."""
    if compose_file == 'core':
        compose_file_ref = 'docker-compose.yml (main file services)'
    else:
        compose_file_ref = f'compose/docker-compose.{compose_file}.yml'
    
    job_header = f'''# Nomad job equivalent to {compose_file_ref}
# Extracted from docker-compose.nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "{job_name}" {{
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

'''
    
    job_footer = '\n}\n'
    
    # Extract all groups for this job
    groups_content = []
    for group_name in group_names:
        group_content = extract_group_manual(all_content, group_name)
        if group_content:
            groups_content.append(group_content)
        else:
            print(f"Warning: Group {group_name} not found in source file")
    
    if not groups_content:
        print(f"Warning: No groups found for {job_name}, skipping")
        return None
    
    full_content = job_header + '\n'.join(groups_content) + job_footer
    
    # Write to file
    output_file = output_dir / f"{job_name}.nomad.hcl"
    with open(output_file, 'w') as f:
        f.write(full_content)
    
    print(f"Created: {output_file} ({len(groups_content)} groups)")
    return output_file

def main():
    script_dir = Path(__file__).parent
    input_file = script_dir / "docker-compose.nomad.hcl"
    output_dir = script_dir / "jobs"
    
    output_dir.mkdir(exist_ok=True)
    
    print(f"Reading {input_file}...")
    with open(input_file, 'r') as f:
        content = f.read()
    
    print(f"Creating job files to match docker-compose.yml include structure...\n")
    
    created_files = []
    for job_name, group_names in COMPOSE_MAPPING.items():
        file_path = create_job_file(job_name, job_name, group_names, content, output_dir)
        if file_path:
            created_files.append(file_path)
    
    print(f"\nCreated {len(created_files)} job files matching docker-compose.yml includes")
    print("\nTo run a specific job:")
    print(f"  nomad job run -var-file=variables.auto.tfvars.hcl -var-file=secrets.auto.tfvars.hcl jobs/<job-name>.nomad.hcl")

if __name__ == "__main__":
    main()
