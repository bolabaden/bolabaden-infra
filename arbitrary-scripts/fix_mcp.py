#!/usr/bin/env python3

import argparse
import json
import os

def transform_mcp_servers(data):
    """Transform cmd /c npx commands to direct npx commands."""
    modified_count = 0
    
    for server_name, server_config in data.get("mcpServers", {}).items():
        command = server_config.get("command")
        args = server_config.get("args", [])
        
        # Check for cmd /c npx pattern
        if (command == "cmd" and len(args) >= 3 and 
            args[0] == "/c" and args[1] == "npx" and args[2] == "-y"):
            
            # Update to direct npx command
            server_config["command"] = "npx"
            server_config["args"] = args[1:]  # Remove the "/c" argument
            modified_count += 1
    
    return modified_count

def main():
    parser = argparse.ArgumentParser(description="Transform cmd /c npx commands to direct npx commands in MCP server configuration")
    parser.add_argument("file_path", help="Path to the JSON file containing MCP server configuration")
    parser.add_argument("--output", "-o", help="Output file path (default: overwrite input file)")
    parser.add_argument("--backup", "-b", action="store_true", help="Create a backup of the original file")
    
    args = parser.parse_args()
    
    # Ensure file exists
    if not os.path.isfile(args.file_path):
        print(f"Error: File not found: {args.file_path}")
        return 1
    
    # Create backup if requested
    if args.backup:
        backup_path = f"{args.file_path}.bak"
        with open(args.file_path, 'r', encoding='utf-8') as src, open(backup_path, 'w', encoding='utf-8') as dst:
            dst.write(src.read())
        print(f"Created backup at: {backup_path}")
    
    # Read and parse the JSON file
    with open(args.file_path, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON format in {args.file_path}: {e}")
            return 1
    
    # Transform the data
    modified_count = transform_mcp_servers(data)
    
    # Write the modified data
    output_path = args.output or args.file_path
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    
    print(f"Modified {modified_count} server configurations")
    print(f"Updated configuration saved to: {output_path}")
    
    return 0

if __name__ == "__main__":
    exit(main())