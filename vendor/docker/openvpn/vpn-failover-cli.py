#!/usr/bin/env python3
"""
VPN Failover Service CLI

Command-line interface for managing the VPN failover service.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import subprocess
import sys
from typing import Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VPNFailoverCLI:
    """CLI for VPN Failover Service"""

    def __init__(self):
        self.service_name: str = "vpn-failover"
        self.config_file: str = "/etc/vpn-failover/config.json"

    def run_command(self, cmd: list[str]) -> tuple[int, str, str]:
        """Run a system command"""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired as e:
            return 1, "", f"Command timed out: {e.__class__.__name__}: {e}"
        except Exception as e:
            return 1, "", f"An error occurred: {e.__class__.__name__}: {e}"

    def get_service_status(self) -> dict[str, Any]:
        """Get service status via systemctl"""
        returncode, stdout, stderr = self.run_command(
            ["systemctl", "--no-pager", "is-active", self.service_name]
        )

        if returncode == 0:
            return {"status": "active", "output": stdout.strip()}
        else:
            return {"status": "inactive", "output": stderr.strip()}

    def start_service(self) -> None:
        """Start the VPN failover service"""
        print("Starting VPN failover service...")
        returncode, stdout, stderr = self.run_command(
            [
                "systemctl",
                "--no-pager",
                "start",
                self.service_name,
            ]
        )

        if returncode == 0:
            print("✓ Service started successfully")
        else:
            print(f"✗ Failed to start service: {stderr}")
            sys.exit(1)

    def stop_service(self) -> None:
        """Stop the VPN failover service"""
        print("Stopping VPN failover service...")
        returncode, stdout, stderr = self.run_command(
            [
                "systemctl",
                "--no-pager",
                "stop",
                self.service_name,
            ]
        )

        if returncode == 0:
            print("✓ Service stopped successfully")
        else:
            print(f"✗ Failed to stop service: {stderr}")
            sys.exit(1)

    def restart_service(self) -> None:
        """Restart the VPN failover service"""
        print("Restarting VPN failover service...")
        returncode, stdout, stderr = self.run_command(
            [
                "systemctl",
                "--no-pager",
                "restart",
                self.service_name,
            ]
        )

        if returncode == 0:
            print("✓ Service restarted successfully")
        else:
            print(f"✗ Failed to restart service: {stderr}")
            sys.exit(1)

    def show_status(self) -> None:
        """Show service status"""
        status = self.get_service_status()

        print(f"Service Status: {status['status']}")
        print(f"Output: {status['output']}")

        # Show recent logs
        print("\nRecent logs:")
        returncode, stdout, stderr = self.run_command(
            [
                "journalctl",
                "--no-pager",
                "-u",
                self.service_name,
                "-n",
                "20",
            ]
        )

        if returncode == 0:
            print(stdout)
        else:
            print(f"Failed to get logs: {stderr}")

    def show_logs(self, follow: bool = False) -> None:
        """Show service logs"""
        cmd = [
            "journalctl",
            "--no-pager",
            "-u",
            self.service_name,
        ]

        if follow:
            cmd.append("--follow")
        else:
            cmd.extend(["-n", "50"])

        # Use subprocess.Popen for following logs
        if follow:
            try:
                process = subprocess.Popen(cmd)
                process.wait()
            except KeyboardInterrupt:
                process.terminate()
                print("\nStopped following logs")
        else:
            returncode, stdout, stderr = self.run_command(cmd)
            if returncode == 0:
                print(stdout)
            else:
                print(f"Failed to get logs: {stderr}")

    def show_config(self) -> None:
        """Show current configuration"""
        if not os.path.exists(self.config_file):
            print(f"Configuration file not found: {self.config_file}")
            return

        try:
            with open(self.config_file, "r") as f:
                config = json.load(f)

            print("Current Configuration:")
            print(json.dumps(config, indent=2))

        except Exception as e:
            print(f"Failed to read configuration: {e.__class__.__name__}: {e}")

    def edit_config(self) -> None:
        """Edit configuration file"""
        if not os.path.exists(self.config_file):
            print(f"Configuration file not found: {self.config_file}")
            return

        editor = os.environ.get("EDITOR", "nano")
        try:
            subprocess.run([editor, self.config_file])
            print("Configuration updated. Restart service to apply changes.")
        except Exception as e:
            print(f"Failed to open editor: {e.__class__.__name__}: {e}")

    def test_vpn(self, vpn_name: str) -> None:
        """Test a specific VPN connection"""
        print(f"Testing VPN connection: {vpn_name}")

        # This would require integration with the service
        # For now, we'll just show how to test manually
        print("Manual testing commands:")
        print(f"1. Check if {vpn_name} is configured in {self.config_file}")
        print("2. Test connectivity manually:")
        print("   curl --max-time 10 https://httpbin.org/ip")
        print("3. Check OpenVPN logs:")
        print(f"   journalctl -u openvpn@{vpn_name} -f")

    def list_vpns(self) -> None:
        """List configured VPNs"""
        if not os.path.exists(self.config_file):
            print("No configuration file found")
            return

        try:
            with open(self.config_file, "r") as f:
                config = json.load(f)

            print("Configured VPNs:")
            print("-" * 60)

            for vpn in config.get("vpns", []):
                status = "✓ Enabled" if vpn.get("enabled", True) else "✗ Disabled"
                print(
                    f"{vpn['name']:<20} {vpn['type']:<10} Priority: {vpn.get('priority', 1):<3} {status}"
                )

        except Exception as e:
            print(f"Failed to read configuration: {e.__class__.__name__}: {e}")

    def enable_vpn(self, vpn_name: str) -> None:
        """Enable a VPN configuration"""
        self._toggle_vpn(vpn_name, True)

    def disable_vpn(self, vpn_name: str) -> None:
        """Disable a VPN configuration"""
        self._toggle_vpn(vpn_name, False)

    def _toggle_vpn(self, vpn_name: str, enabled: bool) -> None:
        """Toggle VPN enabled/disabled status"""
        if not os.path.exists(self.config_file):
            print("Configuration file not found")
            return

        try:
            with open(self.config_file, "r") as f:
                config = json.load(f)

            # Find and update the VPN
            found = False
            for vpn in config.get("vpns", []):
                if vpn["name"] == vpn_name:
                    vpn["enabled"] = enabled
                    found = True
                    break

            if not found:
                print(f"VPN '{vpn_name}' not found in configuration")
                return

            # Write back configuration
            with open(self.config_file, "w") as f:
                json.dump(config, f, indent=2)

            status = "enabled" if enabled else "disabled"
            print(f"✓ VPN '{vpn_name}' {status}")
            print("Restart service to apply changes")

        except Exception as e:
            print(f"Failed to update configuration: {e.__class__.__name__}: {e}")


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(
        description="VPN Failover Service CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  vpn-failover-cli status          # Show service status
  vpn-failover-cli start           # Start the service
  vpn-failover-cli logs -f         # Follow logs
  vpn-failover-cli list            # List configured VPNs
  vpn-failover-cli enable primary  # Enable a VPN
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Service control commands
    subparsers.add_parser("start", help="Start the service")
    subparsers.add_parser("stop", help="Stop the service")
    subparsers.add_parser("restart", help="Restart the service")
    subparsers.add_parser("status", help="Show service status")

    # Logs command
    logs_parser = subparsers.add_parser("logs", help="Show service logs")
    logs_parser.add_argument(
        "-f", "--follow", action="store_true", help="Follow logs in real-time"
    )

    # Configuration commands
    subparsers.add_parser("config", help="Show current configuration")
    subparsers.add_parser("edit-config", help="Edit configuration file")

    # VPN management commands
    subparsers.add_parser("list", help="List configured VPNs")

    test_parser = subparsers.add_parser("test", help="Test a VPN connection")
    test_parser.add_argument("vpn_name", help="Name of the VPN to test")

    enable_parser = subparsers.add_parser("enable", help="Enable a VPN")
    enable_parser.add_argument("vpn_name", help="Name of the VPN to enable")

    disable_parser = subparsers.add_parser("disable", help="Disable a VPN")
    disable_parser.add_argument("vpn_name", help="Name of the VPN to disable")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    cli = VPNFailoverCLI()

    try:
        if args.command == "start":
            cli.start_service()
        elif args.command == "stop":
            cli.stop_service()
        elif args.command == "restart":
            cli.restart_service()
        elif args.command == "status":
            cli.show_status()
        elif args.command == "logs":
            cli.show_logs(args.follow)
        elif args.command == "config":
            cli.show_config()
        elif args.command == "edit-config":
            cli.edit_config()
        elif args.command == "list":
            cli.list_vpns()
        elif args.command == "test":
            cli.test_vpn(args.vpn_name)
        elif args.command == "enable":
            cli.enable_vpn(args.vpn_name)
        elif args.command == "disable":
            cli.disable_vpn(args.vpn_name)
        else:
            parser.print_help()

    except KeyboardInterrupt as e:
        print(f"\nOperation cancelled: {e.__class__.__name__}: {e}")
    except Exception as e:
        print(f"Error: {e.__class__.__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
