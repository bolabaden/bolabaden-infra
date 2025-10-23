#!/usr/bin/env python3
"""Restructure Nomad file to separate traefik into its own group."""

def main():
    # Read the file
    with open('/home/ubuntu/my-media-stack/nomad/docker-compose.nomad.hcl', 'r') as f:
        lines = f.readlines()
    
    # Find key line numbers
    traefik_services_group_start = None
    traefik_task_start = None
    traefik_task_end = None
    whoami_task_start = None
    
    for i, line in enumerate(lines):
        if 'group "traefik-services"' in line:
            traefik_services_group_start = i
        elif 'task "traefik"' in line and traefik_task_start is None:
            traefik_task_start = i
        elif 'task "whoami"' in line:
            whoami_task_start = i
            traefik_task_end = i - 1  # Line before whoami is end of traefik
            break
    
    print(f"traefik-services group starts at line {traefik_services_group_start + 1}")
    print(f"traefik task: lines {traefik_task_start + 1} to {traefik_task_end + 1}")
    print(f"whoami starts at line {whoami_task_start + 1}")
    
    # Extract traefik task
    traefik_task_lines = lines[traefik_task_start:traefik_task_end + 1]
    print(f"Extracted {len(traefik_task_lines)} lines for traefik task")
    
    # Find where to insert traefik task (after the network block in traefik-services group)
    insert_pos = None
    for i in range(traefik_services_group_start, len(lines)):
        if lines[i].strip() == '}' and i > traefik_services_group_start + 10:
            # This should be the end of the network block
            insert_pos = i + 1
            break
    
    print(f"Will insert traefik task at line {insert_pos + 1}")
    
    # Build new content
    new_lines = (
        lines[:insert_pos] +  # Everything up to insertion point
        ['\n'] +
        traefik_task_lines +  # Traefik task
        ['\n', '  }\n', '\n'] +  # Close traefik-services group
        ['  # Coolify Support Services\n'] +
        ['  group "coolify-support-services" {\n'] +
        ['    count = 1\n', '\n'] +
        ['    network {\n'] +
        ['      mode = "bridge"\n', '\n'] +
        ['      port "cloudflare_ddns" {}\n'] +
        ['      port "nginx_extensions" { to = 80 }\n'] +
        ['      port "tinyauth" { to = 3000 }\n'] +
        ['      port "crowdsec_lapi" { to = 8080 }\n'] +
        ['      port "crowdsec_appsec" { to = 7422 }\n'] +
        ['      port "crowdsec_metrics" { to = 6060 }\n'] +
        ['      port "whoami" { to = 80 }\n'] +
        ['      port "autokuma" {}\n'] +
        ['      port "logrotate_traefik" {}\n'] +
        ['    }\n', '\n'] +
        lines[traefik_task_start - 100:traefik_task_start] +  # Tasks before traefik (cloudflare, nginx, tinyauth, crowdsec)
        lines[whoami_task_start:]  # Tasks after traefik (whoami onwards)
    )
    
    # Write the new file
    with open('/home/ubuntu/my-media-stack/nomad/docker-compose.nomad.hcl.new', 'w') as f:
        f.writelines(new_lines)
    
    print("\nNew file written to docker-compose.nomad.hcl.new")
    print("Please review and rename if correct")

if __name__ == "__main__":
    main()

