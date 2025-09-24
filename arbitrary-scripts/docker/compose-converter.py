#!/usr/bin/env python3
"""
Docker Compose Converter CLI Tool

Converts between different Docker Compose organizational structures:
1. Modular (app-per-directory) → Monolithic (single AIO file with configs)
2. Monolithic → Modular (split into app directories)
3. Include-based modularization and its inverse
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Any

import yaml


class ComposeConverter:
    """Main converter class for Docker Compose transformations"""
    
    def __init__(self, source_path: Path, target_path: Path, verbose: bool = False):
        self.source_path = source_path
        self.target_path = target_path
        self.verbose = verbose
        self.configs: dict[str, dict[str, Any]] = {}
        self.services: dict[str, dict[str, Any]] = {}
        self.networks: dict[str, Any] = {}
        self.volumes: dict[str, Any] = {}
        self.secrets: dict[str, Any] = {}
        
    def log(self, message: str) -> None:
        """Print verbose logging if enabled"""
        if self.verbose:
            print(f"[INFO] {message}")
    
    def convert_to_monolithic(self, use_configs: bool = True) -> None:
        """Convert modular structure to single AIO compose file"""
        self.log(f"Converting modular structure at {self.source_path} to monolithic")
        
        # Scan for all compose files in subdirectories
        compose_files = self._find_compose_files()
        
        for compose_file in compose_files:
            app_name = compose_file.parent.name
            self.log(f"Processing app: {app_name}")
            
            # Load compose file
            with open(compose_file, 'r') as f:
                compose_data = yaml.safe_load(f) or {}
            
            # Extract services
            if 'services' in compose_data:
                for service_name, service_config in compose_data['services'].items():
                    # Prefix service name with app name if not already
                    if not service_name.startswith(app_name):
                        full_service_name = f"{app_name}-{service_name}"
                    else:
                        full_service_name = service_name
                    
                    # Process configuration files if use_configs is True
                    if use_configs:
                        service_config = self._convert_files_to_configs(
                            service_config, compose_file.parent, app_name
                        )
                    
                    self.services[full_service_name] = service_config
            
            # Merge networks, volumes, secrets
            if 'networks' in compose_data:
                self.networks.update(compose_data['networks'])
            if 'volumes' in compose_data:
                self.volumes.update(compose_data['volumes'])
            if 'secrets' in compose_data:
                self.secrets.update(compose_data['secrets'])
        
        # Write monolithic compose file
        self._write_monolithic_compose()
    
    def convert_to_modular(self) -> None:
        """Convert monolithic compose file to modular structure"""
        self.log(f"Converting monolithic file {self.source_path} to modular structure")
        
        # Load monolithic compose file
        with open(self.source_path, 'r') as f:
            compose_data = yaml.safe_load(f)
        
        services = compose_data.get('services', {})
        configs = compose_data.get('configs', {})
        
        # Group services by app (using naming patterns)
        apps = self._group_services_by_app(services)
        
        # Create directory structure and compose files for each app
        for app_name, app_services in apps.items():
            app_dir = self.target_path / app_name
            app_dir.mkdir(parents=True, exist_ok=True)
            
            # Extract configs for this app
            app_configs = self._extract_app_configs(app_services, configs)
            
            # Write compose.yaml for this app
            app_compose = {
                'services': app_services
            }
            
            # Add networks/volumes if referenced
            app_networks = self._extract_referenced_networks(
                app_services, compose_data.get('networks', {})
            )
            if app_networks:
                app_compose['networks'] = app_networks
            
            app_volumes = self._extract_referenced_volumes(
                app_services, compose_data.get('volumes', {})
            )
            if app_volumes:
                app_compose['volumes'] = app_volumes
            
            # Write compose file
            compose_path = app_dir / 'compose.yaml'
            with open(compose_path, 'w') as f:
                yaml.dump(app_compose, f, default_flow_style=False, sort_keys=False)
            
            self.log(f"Created {compose_path}")
            
            # Write config files
            for config_name, config_data in app_configs.items():
                if 'content' in config_data:
                    config_file = app_dir / config_name
                    config_file.parent.mkdir(parents=True, exist_ok=True)
                    config_file.write_text(config_data['content'])
                    self.log(f"Created config file: {config_file}")
    
    def convert_to_includes(self, group_by: str = 'category') -> None:
        """Convert to include-based modular structure"""
        self.log(f"Converting to include-based structure, grouping by {group_by}")
        
        # Load source compose file(s)
        if self.source_path.is_file():
            with open(self.source_path, 'r') as f:
                compose_data = yaml.safe_load(f)
            services = compose_data.get('services', {})
        else:
            # Load from modular structure
            services = {}
            compose_files = self._find_compose_files()
            for compose_file in compose_files:
                with open(compose_file, 'r') as f:
                    data = yaml.safe_load(f) or {}
                    services.update(data.get('services', {}))
        
        # Group services
        groups = self._group_services(services, group_by)
        
        # Create main compose file with includes
        includes = []
        for group_name, group_services in groups.items():
            # Create group compose file
            group_file = f"docker-compose.{group_name}.yml"
            group_path = self.target_path / group_file
            
            group_compose = {
                'services': group_services
            }
            
            with open(group_path, 'w') as f:
                yaml.dump(group_compose, f, default_flow_style=False, sort_keys=False)
            
            includes.append(group_file)
            self.log(f"Created {group_file} with {len(group_services)} services")
        
        # Create main compose file
        main_compose = {
            'include': includes
        }
        
        main_path = self.target_path / 'docker-compose.yml'
        with open(main_path, 'w') as f:
            yaml.dump(main_compose, f, default_flow_style=False, sort_keys=False)
        
        self.log(f"Created main compose file with {len(includes)} includes")
    
    def convert_from_includes(self) -> None:
        """Convert from include-based structure to monolithic"""
        self.log("Converting from include-based structure to monolithic")
        
        # Load main compose file
        with open(self.source_path, 'r') as f:
            main_compose = yaml.safe_load(f)
        
        includes = main_compose.get('include', [])
        
        # Merge all included files
        merged_compose: dict[str, Any] = {
            'services': {},
            'networks': {},
            'volumes': {},
            'configs': {},
            'secrets': {}
        }
        
        for include_file in includes:
            include_path = self.source_path.parent / include_file
            if include_path.exists():
                with open(include_path, 'r') as f:
                    include_data = yaml.safe_load(f) or {}
                
                # Merge each section
                for section in ['services', 'networks', 'volumes', 'configs', 'secrets']:
                    if section in include_data:
                        merged_compose[section].update(include_data[section])
                
                self.log(f"Merged {include_file}")
        
        # Add any direct definitions from main file
        for section in ['services', 'networks', 'volumes', 'configs', 'secrets']:
            if section in main_compose and section != 'include':
                merged_compose[section].update(main_compose[section])
        
        # Clean up empty sections
        merged_compose = {k: v for k, v in merged_compose.items() if v}
        
        # Write merged compose file
        output_path = self.target_path / 'docker-compose.aio.yml'
        with open(output_path, 'w') as f:
            yaml.dump(merged_compose, f, default_flow_style=False, sort_keys=False)
        
        self.log(f"Created monolithic file: {output_path}")
    
    def _find_compose_files(self) -> list[Path]:
        """Find all compose files in subdirectories"""
        compose_files: list[Path] = []
        for root, dirs, files in os.walk(self.source_path):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            
            for file in files:
                if file in ['compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml']:
                    compose_files.append(Path(root) / file)
        
        return compose_files
    
    def _convert_files_to_configs(
        self,
        service_config: dict[str, Any],
        app_dir: Path,
        app_name: str,
    ) -> dict[str, Any]:
        """Convert external files to Docker configs"""
        
        # Check for .env file
        env_file = app_dir / '.env'
        if env_file.exists():
            config_name = f"{app_name}-env"
            self.configs[config_name] = {
                'content': env_file.read_text()
            }
            # Update service to use config
            if 'env_file' in service_config:
                del service_config['env_file']
            if 'configs' not in service_config:
                service_config['configs'] = []
            service_config['configs'].append({
                'source': config_name,
                'target': '/.env'
            })
        
        # Check for config directory
        config_dir = app_dir / 'config'
        if config_dir.exists() and config_dir.is_dir():
            for config_file in config_dir.rglob('*'):
                if config_file.is_file():
                    rel_path = config_file.relative_to(config_dir)
                    config_name = f"{app_name}-{str(rel_path).replace('/', '-')}"
                    self.configs[config_name] = {
                        'content': config_file.read_text()
                    }
                    
                    # Add to service configs
                    if 'configs' not in service_config:
                        service_config['configs'] = []
                    service_config['configs'].append({
                        'source': config_name,
                        'target': f"/config/{rel_path}"
                    })
        
        # Check for other config files (*.conf, *.json, *.yml, *.yaml)
        for pattern in ['*.conf', '*.json', '*.yml', '*.yaml']:
            for config_file in app_dir.glob(pattern):
                if config_file.name not in ['compose.yaml', 'compose.yml', 'docker-compose.yaml', 'docker-compose.yml']:
                    config_name = f"{app_name}-{config_file.stem}"
                    self.configs[config_name] = {
                        'content': config_file.read_text()
                    }
                    
                    if 'configs' not in service_config:
                        service_config['configs'] = []
                    service_config['configs'].append({
                        'source': config_name,
                        'target': f"/{config_file.name}"
                    })
        
        return service_config
    
    def _write_monolithic_compose(self) -> None:
        """Write the monolithic compose file"""
        compose_data: dict[str, Any] = {}
        
        # Add version if needed
        compose_data['version'] = '3.9'
        
        # Add services
        if self.services:
            compose_data['services'] = self.services
        
        # Add configs
        if self.configs:
            compose_data['configs'] = self.configs
        
        # Add networks
        if self.networks:
            compose_data['networks'] = self.networks
        
        # Add volumes
        if self.volumes:
            compose_data['volumes'] = self.volumes
        
        # Add secrets
        if self.secrets:
            compose_data['secrets'] = self.secrets
        
        # Write file
        output_file = self.target_path / 'docker-compose.aio.yml'
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False, width=120)
        
        print(f"✅ Created monolithic compose file: {output_file}")
        print(f"   - Services: {len(self.services)}")
        print(f"   - Configs: {len(self.configs)}")
        print(f"   - Networks: {len(self.networks)}")
        print(f"   - Volumes: {len(self.volumes)}")
    
    def _group_services_by_app(self, services: dict[str, Any]) -> dict[str, dict[str, Any]]:
        """Group services by application name"""
        apps: dict[str, dict[str, Any]] = {}
        
        for service_name, service_config in services.items():
            # Try to extract app name from service name
            # Common patterns: app-service, app_service, or just app
            parts = re.split(r'[-_]', service_name)
            app_name = parts[0] if parts else service_name
            
            # Special cases for known patterns
            if service_name.endswith('-db') or service_name.endswith('_db'):
                app_name = service_name[:-3]
            elif service_name.endswith('-redis') or service_name.endswith('_redis'):
                app_name = service_name[:-6]
            elif service_name.endswith('-postgres') or service_name.endswith('_postgres'):
                app_name = service_name[:-9]
            
            if app_name not in apps:
                apps[app_name] = {}
            
            apps[app_name][service_name] = service_config
        
        return apps
    
    def _extract_app_configs(
        self,
        app_services: dict[str, Any],
        all_configs: dict[str, Any],
    ) -> dict[str, Any]:
        """Extract configs referenced by app services"""
        app_configs: dict[str, Any] = {}
        
        for service_config in app_services.values():
            if 'configs' in service_config:
                for config in service_config['configs']:
                    if isinstance(config, dict):
                        config_name = config.get('source')
                    else:
                        config_name = config
                    
                    if config_name and config_name in all_configs:
                        app_configs[config_name] = all_configs[config_name]
        
        return app_configs
    
    def _extract_referenced_networks(
        self,
        services: dict[str, Any],
        all_networks: dict[str, Any],
    ) -> dict[str, Any]:
        """Extract networks referenced by services"""
        referenced = set()
        
        for service_config in services.values():
            if 'networks' in service_config:
                networks = service_config['networks']
                if isinstance(networks, list):
                    referenced.update(networks)
                elif isinstance(networks, dict):
                    referenced.update(networks.keys())
        
        return {net: all_networks.get(net, {}) for net in referenced if net in all_networks}
    
    def _extract_referenced_volumes(
        self,
        services: dict[str, Any],
        all_volumes: dict[str, Any],
    ) -> dict[str, Any]:
        """Extract volumes referenced by services"""
        referenced = set()
        
        for service_config in services.values():
            if 'volumes' in service_config:
                for volume in service_config['volumes']:
                    if isinstance(volume, str) and ':' in volume:
                        vol_name = volume.split(':')[0]
                        if not vol_name.startswith('.') and not vol_name.startswith('/'):
                            referenced.add(vol_name)
        
        return {
            vol: all_volumes.get(vol, {})
            for vol in referenced
            if vol in all_volumes
        }
    
    def _group_services(
        self,
        services: dict[str, Any],
        group_by: str,
    ) -> dict[str, dict[str, Any]]:
        """Group services by specified criteria"""
        groups: dict[str, dict[str, Any]] = {}
        
        if group_by == 'category':
            categories: dict[str, list[str]] = {}
            
            for service_name, service_config in services.items():
                assigned: bool = False
                for category, keywords in categories.items():
                    if any(keyword in service_name.lower() for keyword in keywords):
                        if category not in groups:
                            groups[category] = {}
                        groups[category][service_name] = service_config
                        assigned = True
                        break
                
                if not assigned:
                    if 'misc' not in groups:
                        groups['misc'] = {}
                    groups['misc'][service_name] = service_config
        
        elif group_by == 'stack':
            # Group by common stacks (arr stack, media stack, etc.)
            for service_name, service_config in services.items():
                stack = 'general'
                
                if stack not in groups:
                    groups[stack] = {}
                groups[stack][service_name] = service_config
        
        else:
            # Default: group alphabetically
            for service_name, service_config in services.items():
                group = service_name[0].lower() if service_name else 'misc'
                if group not in groups:
                    groups[group] = {}
                groups[group][service_name] = service_config
        
        return groups


def main():
    parser = argparse.ArgumentParser(
        description='Convert between different Docker Compose structures',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert modular apps to monolithic AIO with configs
  %(prog)s to-monolithic --source ./opt/docker/apps --target ./output --use-configs
  
  # Convert monolithic to modular structure
  %(prog)s to-modular --source docker-compose.aio.yml --target ./apps
  
  # Create include-based structure grouped by category
  %(prog)s to-includes --source docker-compose.yml --target ./modular --group-by category
  
  # Merge include-based structure back to monolithic
  %(prog)s from-includes --source ./modular/docker-compose.yml --target ./output
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Conversion commands')
    
    # to-monolithic command
    mono_parser = subparsers.add_parser(
        'to-monolithic',
        help='Convert modular structure to single AIO file'
    )
    mono_parser.add_argument('--source', '-s', type=Path, required=True,
                            help='Source directory with app subdirectories')
    mono_parser.add_argument('--target', '-t', type=Path, required=True,
                            help='Target directory for output')
    mono_parser.add_argument('--use-configs', action='store_true',
                            help='Convert config files to Docker configs')
    mono_parser.add_argument('--verbose', '-v', action='store_true',
                            help='Enable verbose output')
    
    # to-modular command
    mod_parser = subparsers.add_parser(
        'to-modular',
        help='Convert monolithic file to modular structure'
    )
    mod_parser.add_argument('--source', '-s', type=Path, required=True,
                           help='Source compose file')
    mod_parser.add_argument('--target', '-t', type=Path, required=True,
                           help='Target directory for app structure')
    mod_parser.add_argument('--verbose', '-v', action='store_true',
                           help='Enable verbose output')
    
    # to-includes command
    inc_parser = subparsers.add_parser(
        'to-includes',
        help='Convert to include-based modular structure'
    )
    inc_parser.add_argument('--source', '-s', type=Path, required=True,
                           help='Source compose file or directory')
    inc_parser.add_argument('--target', '-t', type=Path, required=True,
                           help='Target directory for output')
    inc_parser.add_argument('--group-by', choices=['category', 'stack', 'alpha'],
                           default='category',
                           help='Grouping strategy for services')
    inc_parser.add_argument('--verbose', '-v', action='store_true',
                           help='Enable verbose output')
    
    # from-includes command
    merge_parser = subparsers.add_parser(
        'from-includes',
        help='Merge include-based structure to monolithic'
    )
    merge_parser.add_argument('--source', '-s', type=Path, required=True,
                             help='Source compose file with includes')
    merge_parser.add_argument('--target', '-t', type=Path, required=True,
                             help='Target directory for output')
    merge_parser.add_argument('--verbose', '-v', action='store_true',
                             help='Enable verbose output')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Create converter instance
    converter = ComposeConverter(
        args.source,
        args.target,
        verbose=args.verbose if hasattr(args, 'verbose') else False
    )
    
    try:
        if args.command == 'to-monolithic':
            converter.convert_to_monolithic(use_configs=args.use_configs)
        elif args.command == 'to-modular':
            converter.convert_to_modular()
        elif args.command == 'to-includes':
            converter.convert_to_includes(group_by=args.group_by)
        elif args.command == 'from-includes':
            converter.convert_from_includes()
        
        print("✅ Conversion completed successfully!")
        
    except Exception as e:
        print(f"❌ Error: {e.__class__.__name__}: {e}", file=sys.stderr)
        if args.verbose if hasattr(args, 'verbose') else False:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
