#!/usr/bin/env python3
"""
Split large Nomad job file into multiple smaller job files.
Each group becomes its own job file in the jobs/ directory.
"""
import re
import os
from pathlib import Path

def extract_groups(file_path):
    """Extract all groups from the Nomad HCL file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find job header
    job_match = re.search(r'job\s+"([^"]+)"\s*\{', content)
    if not job_match:
        raise ValueError("Could not find job definition")
    
    job_name = job_match.group(1)
    job_start = job_match.start()
    
    # Extract variables section (everything before the job)
    variables_section = content[:job_start]
    
    # Find all group definitions
    group_pattern = r'group\s+"([^"]+)"\s*\{'
    groups = []
    
    for match in re.finditer(group_pattern, content):
        group_name = match.group(1)
        group_start = match.start()
        
        # Find the end of this group (matching braces)
        brace_count = 0
        in_string = False
        string_char = None
        i = group_start
        
        while i < len(content):
            char = content[i]
            
            # Handle string literals
            if char in ('"', "'") and (i == 0 or content[i-1] != '\\'):
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
                        group_end = i + 1
                        groups.append({
                            'name': group_name,
                            'start': group_start,
                            'end': group_end,
                            'content': content[group_start:group_end]
                        })
                        break
            i += 1
    
    return job_name, variables_section, groups

def create_job_file(job_name, group_name, variables_section, group_content, output_dir):
    """Create a separate job file for a group."""
    # Create job header
    job_header = f'''# Nomad job for {group_name}
# Extracted from docker-compose.nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file

job "{job_name}-{group_name}" {{
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

'''
    
    # Create job footer
    job_footer = '\n}\n'
    
    # Combine everything
    full_content = job_header + group_content + job_footer
    
    # Write to file
    output_file = output_dir / f"{group_name.replace('-group', '')}.nomad.hcl"
    with open(output_file, 'w') as f:
        f.write(full_content)
    
    print(f"Created: {output_file}")
    return output_file

def main():
    script_dir = Path(__file__).parent
    input_file = script_dir / "docker-compose.nomad.hcl"
    output_dir = script_dir / "jobs"
    
    output_dir.mkdir(exist_ok=True)
    
    print(f"Reading {input_file}...")
    job_name, variables_section, groups = extract_groups(input_file)
    
    print(f"Found {len(groups)} groups")
    print(f"Creating separate job files in {output_dir}...")
    
    created_files = []
    for group in groups:
        group_name = group['name']
        file_path = create_job_file(
            job_name,
            group_name,
            variables_section,
            group['content'],
            output_dir
        )
        created_files.append(file_path)
    
    print(f"\nCreated {len(created_files)} job files")
    print("\nTo run a specific job:")
    print(f"  nomad job run -var-file=variables.auto.tfvars.hcl -var-file=secrets.auto.tfvars.hcl jobs/<job-name>.nomad.hcl")
    print("\nOr use the run-job.sh script:")
    print(f"  ./nomad/run-job.sh <job-name>")

if __name__ == "__main__":
    main()
