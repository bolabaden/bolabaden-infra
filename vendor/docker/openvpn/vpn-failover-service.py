#!/usr/bin/env python3
"""VPN Failover Service

Manages multiple VPN connections with automatic failover and health checking.
Supports both OpenVPN and Cloudflare WARP connections.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any
import threading
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/vpn-failover.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class VPNType(Enum):
    """VPN connection types"""
    OPENVPN = "openvpn"
    WARP = "warp"


class VPNStatus(Enum):
    """VPN connection status"""
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    FAILED = "failed"
    DISCONNECTING = "disconnecting"


@dataclass
class VPNConfig:
    """VPN configuration"""
    name: str
    vpn_type: VPNType
    config_path: str
    auth_path: str | None = None
    priority: int = 1
    health_check_url: str = "https://httpbin.org/ip"
    health_check_interval: int = 30
    health_check_timeout: int = 10
    max_failures: int = 3
    reconnect_delay: int = 60
    enabled: bool = True


@dataclass
class VPNConnection:
    """VPN connection instance"""
    config: VPNConfig
    status: VPNStatus = VPNStatus.DISCONNECTED
    process: subprocess.Popen | None = None
    pid: int | None = None
    last_health_check: datetime | None = None
    failure_count: int = 0
    last_failure: datetime | None = None
    start_time: datetime | None = None
    stop_time: datetime | None = None


class VPNFailoverService:
    """Main VPN failover service"""
    
    def __init__(
      self,
      config_file: os.PathLike | str = "/etc/vpn-failover/config.json",
      docker_network: str = "vpn-network",
    ):
        self.config_file: Path = Path(config_file)
        self.configs: list[VPNConfig] = []
        self.connections: dict[str, VPNConnection] = {}
        self.active_connection: VPNConnection | None = None
        self.running = False
        self.health_check_thread: threading.Thread | None = None
        self.docker_network = "vpn-network"
        
        # Load configuration
        self.load_config()
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def load_config(self) -> None:
        """Load VPN configurations from file"""
        try:
            if not os.path.exists(self.config_file):
                self.create_default_config()
            
            with open(self.config_file, 'r') as f:
                data = json.load(f)
            
            self.configs = []
            for vpn_data in data.get('vpns', []):
                config = VPNConfig(
                    name=vpn_data['name'],
                    vpn_type=VPNType(vpn_data['type']),
                    config_path=vpn_data['config_path'],
                    auth_path=vpn_data.get('auth_path'),
                    priority=vpn_data.get('priority', 1),
                    health_check_url=vpn_data.get('health_check_url', 'https://httpbin.org/ip'),
                    health_check_interval=vpn_data.get('health_check_interval', 30),
                    health_check_timeout=vpn_data.get('health_check_timeout', 10),
                    max_failures=vpn_data.get('max_failures', 3),
                    reconnect_delay=vpn_data.get('reconnect_delay', 60),
                    enabled=vpn_data.get('enabled', True)
                )
                self.configs.append(config)
            
            # Sort by priority (lower number = higher priority)
            self.configs.sort(key=lambda x: x.priority)
            
            logger.info(f"Loaded {len(self.configs)} VPN configurations")
            
        except Exception as e:
            logger.error(f"Failed to load configuration: {e.__class__.__name__}: {e}")
            sys.exit(1)
    
    def create_default_config(self) -> None:
        """Create default configuration file"""
        default_config: dict[str, Any] = {
            "vpns": [
                {
                    "name": "primary-openvpn",
                    "type": "openvpn",
                    "config_path": "/etc/openvpn/client/vpn_config.conf",
                    "auth_path": "/etc/openvpn/client/auth.conf",
                    "priority": 1,
                    "health_check_url": "https://httpbin.org/ip",
                    "health_check_interval": 30,
                    "health_check_timeout": 10,
                    "max_failures": 3,
                    "reconnect_delay": 60,
                    "enabled": True
                },
                {
                    "name": "backup-openvpn",
                    "type": "openvpn",
                    "config_path": "/etc/openvpn/client/backup_config.conf",
                    "auth_path": "/etc/openvpn/client/backup_auth.conf",
                    "priority": 2,
                    "health_check_url": "https://httpbin.org/ip",
                    "health_check_interval": 30,
                    "health_check_timeout": 10,
                    "max_failures": 3,
                    "reconnect_delay": 60,
                    "enabled": True
                },
                {
                    "name": "warp-fallback",
                    "type": "warp",
                    "config_path": "",
                    "priority": 3,
                    "health_check_url": "https://httpbin.org/ip",
                    "health_check_interval": 30,
                    "health_check_timeout": 10,
                    "max_failures": 3,
                    "reconnect_delay": 60,
                    "enabled": True
                }
            ],
            "docker_network": "vpn-network",
            "log_level": "INFO"
        }
        
        # Create config directory if it doesn't exist
        config_dir = os.path.dirname(self.config_file)
        os.makedirs(config_dir, exist_ok=True)
        
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        logger.info(f"Created default configuration at {self.config_file}")
    
    def start(self) -> None:
        """Start the VPN failover service"""
        logger.info("Starting VPN failover service")
        self.running = True
        
        # Initialize connections
        for config in self.configs:
            if config.enabled:
                connection = VPNConnection(config=config)
                self.connections[config.name] = connection
        
        # Start health check thread
        self.health_check_thread = threading.Thread(target=self.health_check_loop, daemon=True)
        self.health_check_thread.start()
        
        # Start with highest priority VPN
        self.connect_best_available()
        
        # Main event loop
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        finally:
            self.stop()
    
    def stop(self) -> None:
        """Stop the VPN failover service"""
        logger.info("Stopping VPN failover service")
        self.running = False
        
        # Disconnect all VPNs
        for connection in self.connections.values():
            if connection.status in [VPNStatus.CONNECTED, VPNStatus.CONNECTING]:
                self.disconnect_vpn(connection)
        
        logger.info("VPN failover service stopped")
    
    def signal_handler(self, signum: int, frame: Any) -> None:
        """Handle system signals"""
        logger.info(f"Received signal {signum}")
        self.stop()
    
    def connect_best_available(self) -> None:
        """Connect to the best available VPN based on priority"""
        for config in self.configs:
            if not config.enabled:
                continue
            
            connection = self.connections[config.name]
            if connection.status == VPNStatus.DISCONNECTED:
                if self.connect_vpn(connection):
                    self.active_connection = connection
                    logger.info(f"Connected to {config.name}")
                    break
    
    def connect_vpn(self, connection: VPNConnection) -> bool:
        """Connect to a specific VPN"""
        config = connection.config
        logger.info(f"Connecting to {config.name} ({config.vpn_type.value})")
        
        connection.status = VPNStatus.CONNECTING
        connection.start_time = datetime.now()
        
        try:
            if config.vpn_type == VPNType.OPENVPN:
                return self._connect_openvpn(connection)
            elif config.vpn_type == VPNType.WARP:
                return self._connect_warp(connection)
            else:
                logger.error(f"Unsupported VPN type: {config.vpn_type}")
                return False
        except Exception as e:
            logger.error(f"Failed to connect to {config.name}: {e.__class__.__name__}: {e}")
            connection.status = VPNStatus.FAILED
            connection.failure_count += 1
            connection.last_failure = datetime.now()
            return False
    
    def _connect_openvpn(self, connection: VPNConnection) -> bool:
        """Connect to OpenVPN"""
        config = connection.config
        
        # Prepare command
        cmd = [
            'openvpn',
            '--config', config.config_path,
            '--daemon',
            '--log', f'/var/log/openvpn-{config.name}.log',
            '--writepid', f'/var/run/openvpn-{config.name}.pid'
        ]
        
        if config.auth_path:
            cmd.extend(['--auth-user-pass', config.auth_path])
        
        # Start OpenVPN process
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait a bit for connection to establish
            time.sleep(5)
            
            # Check if process is still running
            if process.poll() is None:
                connection.process = process
                connection.pid = process.pid
                connection.status = VPNStatus.CONNECTED
                connection.failure_count = 0
                
                # Update Docker network routing
                self._update_docker_routing(config.name)
                
                return True
            else:
                stdout, stderr = process.communicate()
                logger.error(f"OpenVPN failed to start: {stderr.decode()}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start OpenVPN: {e.__class__.__name__}: {e}")
            return False
    
    def _connect_warp(self, connection: VPNConnection) -> bool:
        """Connect to Cloudflare WARP"""
        config = connection.config
        
        try:
            # Check if WARP is installed
            result = subprocess.run(['warp-cli', '--version'], 
                                  capture_output=True, text=True)
            if result.returncode != 0:
                logger.error("WARP CLI not found. Please install Cloudflare WARP.")
                return False
            
            # Disconnect any existing WARP connection
            subprocess.run(['warp-cli', 'disconnect'], 
                         capture_output=True, text=True)
            
            # Connect to WARP
            result = subprocess.run(['warp-cli', 'connect'], 
                                  capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                connection.status = VPNStatus.CONNECTED
                connection.failure_count = 0
                
                # Update Docker network routing for WARP
                self._update_docker_routing(config.name)
                
                return True
            else:
                logger.error(f"WARP connection failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired as e:
            logger.error(f"WARP connection timed out: {e.__class__.__name__}: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to connect to WARP: {e.__class__.__name__}: {e}")
            return False
    
    def disconnect_vpn(self, connection: VPNConnection) -> None:
        """Disconnect a VPN connection"""
        config = connection.config
        logger.info(f"Disconnecting from {config.name}")
        
        connection.status = VPNStatus.DISCONNECTING
        connection.stop_time = datetime.now()
        
        try:
            if config.vpn_type == VPNType.OPENVPN:
                self._disconnect_openvpn(connection)
            elif config.vpn_type == VPNType.WARP:
                self._disconnect_warp(connection)
        except Exception as e:
            logger.error(f"Error disconnecting from {config.name}: {e.__class__.__name__}: {e}")
        finally:
            connection.status = VPNStatus.DISCONNECTED
            connection.process = None
            connection.pid = None
    
    def _disconnect_openvpn(self, connection: VPNConnection) -> None:
        """Disconnect OpenVPN"""
        if connection.process:
            connection.process.terminate()
            try:
                connection.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                connection.process.kill()
                connection.process.wait()
        
        # Clean up PID file
        config = connection.config
        pid_file = f'/var/run/openvpn-{config.name}.pid'
        if os.path.exists(pid_file):
            os.remove(pid_file)
    
    def _disconnect_warp(self, connection: VPNConnection) -> None:
        """Disconnect WARP"""
        try:
            subprocess.run(['warp-cli', 'disconnect'], 
                         capture_output=True, text=True)
        except Exception as e:
            logger.error(f"Error disconnecting WARP: {e.__class__.__name__}: {e}")
    
    def _update_docker_routing(self, vpn_name: str) -> None:
        """Update Docker network routing for the active VPN"""
        try:
            # This would integrate with your existing vpn-up.sh logic
            # For now, we'll just log that routing should be updated
            logger.info(f"Routing updated for {vpn_name} on {self.docker_network}")
        except Exception as e:
            logger.error(f"Failed to update Docker routing: {e.__class__.__name__}: {e}")
    
    def health_check_loop(self) -> None:
        """Main health check loop"""
        while self.running:
            try:
                if self.active_connection:
                    self._check_vpn_health(self.active_connection)
                
                # Check if we need to failover
                if self._should_failover():
                    self._perform_failover()
                
                time.sleep(10)  # Check every 10 seconds
                
            except Exception as e:
                logger.error(f"Error in health check loop: {e.__class__.__name__}: {e}")
                time.sleep(30)  # Wait longer on error
    
    def _check_vpn_health(self, connection: VPNConnection) -> None:
        """Check health of a VPN connection"""
        config = connection.config
        
        try:
            # Use curl to check connectivity
            cmd = [
                'curl', '--silent', '--max-time', str(config.health_check_timeout),
                '--connect-timeout', str(config.health_check_timeout),
                config.health_check_url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=config.health_check_timeout + 5)
            
            if result.returncode == 0:
                connection.last_health_check = datetime.now()
                connection.failure_count = 0
            else:
                connection.failure_count += 1
                connection.last_failure = datetime.now()
                logger.warning(f"Health check failed for {config.name} (failure {connection.failure_count}/{config.max_failures})")
                
        except Exception as e:
            connection.failure_count += 1
            connection.last_failure = datetime.now()
            logger.error(f"Health check error for {config.name}: {e}")
    
    def _should_failover(self) -> bool:
        """Determine if failover is needed"""
        if not self.active_connection:
            return False
        
        config = self.active_connection.config
        
        # Check if max failures exceeded
        if self.active_connection.failure_count >= config.max_failures:
            return True
        
        # Check if connection is in failed state
        if self.active_connection.status == VPNStatus.FAILED:
            return True
        
        return False
    
    def _perform_failover(self) -> None:
        """Perform failover to next available VPN"""
        logger.info("Performing VPN failover")
        
        # Disconnect current VPN
        if self.active_connection:
            self.disconnect_vpn(self.active_connection)
            self.active_connection = None
        
        # Find next available VPN
        current_priority = self.active_connection.config.priority if self.active_connection else 0
        
        for config in self.configs:
            if not config.enabled or config.priority <= current_priority:
                continue
            
            connection = self.connections[config.name]
            if connection.status == VPNStatus.DISCONNECTED:
                if self.connect_vpn(connection):
                    self.active_connection = connection
                    logger.info(f"Failover successful to {config.name}")
                    return
        
        logger.error("No available VPN for failover")
    
    def get_status(self) -> dict[str, Any]:
        """Get current service status"""
        status = {
            "service_running": self.running,
            "active_connection": None,
            "connections": {}
        }
        
        if self.active_connection:
            status["active_connection"] = {
                "name": self.active_connection.config.name,
                "type": self.active_connection.config.vpn_type.value,
                "status": self.active_connection.status.value,
                "uptime": str(datetime.now() - self.active_connection.start_time) if self.active_connection.start_time else None,
                "failure_count": self.active_connection.failure_count
            }
        
        for name, connection in self.connections.items():
            status["connections"][name] = {
                "type": connection.config.vpn_type.value,
                "status": connection.status.value,
                "priority": connection.config.priority,
                "enabled": connection.config.enabled,
                "failure_count": connection.failure_count,
                "last_health_check": connection.last_health_check.isoformat() if connection.last_health_check else None
            }
        
        return status


def main():
    """Main entry point"""
    service = VPNFailoverService()
    service.start()


if __name__ == "__main__":
    main() 