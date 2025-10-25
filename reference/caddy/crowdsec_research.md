[{"type": "text", "text": "========================
CODE SNIPPETS
========================

TITLE: Automatic Bouncer Registration via Docker Secret
DESCRIPTION: This command illustrates how to automatically register a bouncer with Crowdsec at container startup using a Docker secret. The secret, named `bouncer_key_<name>` (e.g., `bouncer_key_nginx`), contains the bouncer's API key. This method provides a more secure way to pass sensitive keys compared to environment variables, enabling Crowdsec to automatically recognize and manage the bouncer.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_11>

LANGUAGE: Shell
CODE:

```
docker run -d \\
    --secret bouncer_key_nginx \\
    --name crowdsec crowdsecurity/crowdsec
```

----------------------------------------

TITLE: Automatic Bouncer Registration via Environment Variable
DESCRIPTION: This command demonstrates how to automatically register a bouncer with Crowdsec at container startup using an environment variable. The variable `BOUNCER_KEY_<name>` (e.g., `BOUNCER_KEY_nginx`) is set with the bouncer's API key, allowing Crowdsec to recognize and manage the bouncer without manual registration via `cscli`. This method is suitable for initial deployments but not for updating existing bouncers.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_10>

LANGUAGE: Shell
CODE:

```
docker run -d \\
    -e BOUNCER_KEY_nginx=mysecretkey12345 \\
    --name crowdsec crowdsecurity/crowdsec
```

----------------------------------------

TITLE: Running Crowdsec Docker with Notification System
DESCRIPTION: This command demonstrates how to run the full Crowdsec Docker image with a custom notification system enabled. It mounts `profiles.yaml` and a specific notification configuration (e.g., `http_notification.yaml`) into the container, allowing Crowdsec to send alerts via configured channels. It also exposes necessary ports for LAPI and metrics.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_7>

LANGUAGE: Shell
CODE:

```
docker run -d \\
    -v ./profiles.yaml:/etc/crowdsec/profiles.yaml \\
    -v ./http_notification.yaml:/etc/crowdsec/notifications/http_notification.yaml \\
    -p 8080:8080 -p 6060:6060 \\
    --name crowdsec crowdsecurity/crowdsec
```

----------------------------------------

TITLE: Starting Crowdsec Docker Instance with Volume Mounts
DESCRIPTION: This `docker run` command starts a detached Crowdsec container, persisting its configuration and data using named volumes (`crowdsec_config`, `crowdsec_data`). It also bind-mounts host log directories (`/var/log/auth.log`, `/var/log/syslog.log`, `/var/log/apache`) into the container for log ingestion. Environment variables are used to install specific collections, and ports 8080 and 6060 are mapped for API access.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_6>

LANGUAGE: shell
CODE:

```
docker run -d \\
    -v crowdsec_config:/etc/crowdsec \\
    -v local_path_to_crowdsec_config/acquis.d:/etc/crowdsec/acquis.d \\
    -v local_path_to_crowdsec_config/acquis.yaml:/etc/crowdsec/acquis.yaml \\
    -v crowdsec_data:/var/lib/crowdsec/data \\
    -v /var/log/auth.log:/logs/auth.log:ro \\
    -v /var/log/syslog.log:/logs/syslog.log:ro \\
    -v /var/log/apache:/logs/apache:ro \\
    -e COLLECTIONS=\"crowdsecurity/apache2 crowdsecurity/sshd\" \\
    -p 8080:8080 -p 6060:6060 \\
    --name crowdsec crowdsecurity/crowdsec
```

----------------------------------------

TITLE: Configuring Crowdsec Acquisition Directory (Legacy)
DESCRIPTION: This YAML snippet shows how to explicitly configure the acquisition directory in `/etc/crowdsec/config.yaml.local` for Crowdsec versions prior to 1.5.0. It sets `acquisition_dir` to `/etc/crowdsec/acquis.d`, allowing Crowdsec to discover acquisition files within that directory.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_4>

LANGUAGE: yaml
CODE:

```
crowdsec_service:
  acquisition_dir: /etc/crowdsec/acquis.d
```

----------------------------------------

TITLE: Running MariaDB Docker Container for Testing
DESCRIPTION: This command starts a MariaDB container named 'mariadb' detached from the terminal, mapping port 3306 and setting the MYSQL_ROOT_PASSWORD environment variable. It includes the --cap-add=sys_nice flag. This is a prerequisite for testing Crowdsec with a MariaDB backend.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_12>

LANGUAGE: Shell
CODE:

```
sudo docker run --cap-add=sys_nice --detach --name=mariadb -p 3306:3306  --env=\"MYSQL_ROOT_PASSWORD=password\" mariadb
```

----------------------------------------

TITLE: Building Custom Debian Crowdsec Image (Legacy Build-Arg)
DESCRIPTION: This command demonstrates the legacy syntax (for Crowdsec versions < 1.5.0) to build a custom Debian-based Crowdsec Docker image. It uses the `--build-arg=BUILD_ENV=slim` flag to specify the 'slim' environment, which results in a reduced-size image without notifier plugins or the GeoIP database.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_1>

LANGUAGE: console
CODE:

```
docker build -f Dockerfile.debian --build-arg=BUILD_ENV=slim .
```

----------------------------------------

TITLE: Running MySQL Docker Container for Testing
DESCRIPTION: This command starts a MySQL container named 'mysql' detached from the terminal, mapping port 3306 and setting the MYSQL_ROOT_PASSWORD environment variable. It includes the --cap-add=sys_nice flag. This is a prerequisite for testing Crowdsec with a MySQL backend.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_10>

LANGUAGE: Shell
CODE:

```
sudo docker run --cap-add=sys_nice --detach --name=mysql -p 3306:3306  --env=\"MYSQL_ROOT_PASSWORD=password\" mysql
```

----------------------------------------

TITLE: Building Custom Debian Crowdsec Image (Slim Target)
DESCRIPTION: This command builds a custom Debian-based Crowdsec Docker image, specifically targeting the 'slim' variant. The 'slim' target reduces image size by excluding notifier plugins and the GeoIP database. This is suitable for environments where these features are not required or will be downloaded at runtime.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_0>

LANGUAGE: console
CODE:

```
docker build -f Dockerfile.debian --target slim .
```

----------------------------------------

TITLE: Registering a New Agent with LAPI (No TLS)
DESCRIPTION: This command registers a new agent with the Crowdsec Local API (LAPI) when TLS authentication is not used. It executes `cscli machines add` inside the LAPI container, requiring a specified agent username and password for authentication. This allows the agent to connect and send alerts to the LAPI.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_8>

LANGUAGE: Shell
CODE:

```
docker exec -it crowdsec_lapi_container_name cscli machines add agent_user_name --password agent_password
```

----------------------------------------

TITLE: Running PostgreSQL Docker Container for Testing
DESCRIPTION: This command starts a PostgreSQL container named 'postgres' detached from the terminal, mapping port 5432 and setting the POSTGRES_PASSWORD environment variable. It's a prerequisite for testing Crowdsec with a PostgreSQL backend.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_8>

LANGUAGE: Shell
CODE:

```
sudo docker run --detach --name=postgres -p 5432:5432 --env=\"POSTGRES_PASSWORD=postgres\" postgres:latest
```

----------------------------------------

TITLE: Configuring Crowdsec Log Acquisition (Apache)
DESCRIPTION: This YAML snippet defines an acquisition configuration for Crowdsec, typically saved as `apache.yaml` in `/etc/crowdsec/acquis.d/`. It specifies that all log files within `/logs/apache2/` ending with `.log` should be ingested. The `labels.type` is set to `apache2`, indicating that these logs should be processed by Apache parsers.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_3>

LANGUAGE: yaml
CODE:

```
filename: /logs/apache2/*.log
labels:
  type: apache2
```

----------------------------------------

TITLE: Configuring Crowdsec Log Acquisition (Single File, Deprecated)
DESCRIPTION: This YAML snippet demonstrates a deprecated method (before 1.5.0) of configuring Crowdsec log acquisition in a single file, typically `/etc/crowdsec/acquis.yaml`. It combines configurations for syslog (auth.log, syslog) and apache2 logs, using `---` as a document separator. While functional, the recommended approach is to use one file per datasource.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_5>

LANGUAGE: yaml
CODE:

```
filenames:
 - /logs/auth.log
 - /logs/syslog
labels:
  type: syslog
---
filename: /logs/apache2/*.log
labels:
  type: apache2
```

----------------------------------------

TITLE: Running Crowdsec Agent Connected to Remote LAPI
DESCRIPTION: This command illustrates how to run a Crowdsec agent configured to connect to a remote Local API (LAPI). It uses environment variables to disable the agent's local API, specify the pre-registered agent's username and password, and define the URL of the remote LAPI. This setup is typical for distributed deployments where agents report to a central LAPI.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_9>

LANGUAGE: Shell
CODE:

```
docker run -d \\
    -e DISABLE_LOCAL_API=true \\
    -e AGENT_USERNAME=\"agent_user_name\" \\
    -e AGENT_PASSWORD=\"agent_password\" \\
    -e LOCAL_API_URL=\"http://LAPI_host:LAPI_port\" \\
    --name crowdsec_agent crowdsecurity/crowdsec
```

----------------------------------------

TITLE: Configuring Crowdsec Log Acquisition (SSH/Syslog)
DESCRIPTION: This YAML snippet defines an acquisition configuration for Crowdsec, typically saved as `ssh.yaml` in `/etc/crowdsec/acquis.d/`. It specifies two log files, `/logs/auth.log` and `/logs/syslog`, to be ingested. The `labels.type` is set to `syslog`, indicating that these logs should be processed by syslog parsers.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/docker/README.md#_snippet_2>

LANGUAGE: yaml
CODE:

```
filenames:
 - /logs/auth.log
 - /logs/syslog
labels:
  type: syslog
```

----------------------------------------

TITLE: Detecting Apache2 using Systemd Units and Path Existence (YAML)
DESCRIPTION: This snippet illustrates detecting Apache using systemd units (`UnitFound`) combined with checking for the existence of specific files (`PathExists`) to differentiate between Debian-based and RedHat-based systems, providing a more robust OS detection method than relying solely on `OS.ID`.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_6>

LANGUAGE: yaml
CODE:

```
version: 1.0

services:

  apache2-systemd-deb:
    when:
      - UnitFound(\"apache2.service\")
      - PathExists(\"/etc/debian_version\")
    install:
    # [...]

  apache2-systemd-rpm:
    when:
      - UnitFound(\"httpd.service\")
      - PathExists(\"/etc/redhat-release\")
    install:
    # [...]
```

----------------------------------------

TITLE: Create Initial Data Tarball (instance-data make) - Shell
DESCRIPTION: Executes setup steps like adding machines, registering CAPI, updating hub, and installing collections. It packages the resulting configuration, hub, and database files into a tar archive located at `./local-init/init-config-data.tar`. This archive represents a known initial state for testing.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_2>

LANGUAGE: Shell
CODE:

```
instance-data make
```

----------------------------------------

TITLE: Detecting Apache2 using Systemd Units and OS ID (YAML)
DESCRIPTION: This snippet demonstrates detecting Apache using systemd units (`UnitFound`) and differentiating configurations based on the operating system ID (`OS.ID`). It shows separate service definitions for standard systems and CentOS due to different unit names.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_5>

LANGUAGE: yaml
CODE:

```
version: 1.0

services:

  apache2-systemd:
    when:
      - UnitFound(\"apache2.service\")
      - OS.ID != \"centos\"
    install:
      collections:
        - crowdsecurity/apache2
    datasource:
      source: file
      labels:
        type: syslog
      filenames:
        - /var/log/apache2/*.log

  apache2-systemd-centos:
    when:
      - UnitFound(\"httpd.service\")
      - OS.ID == \"centos\"
    install:
      collections:
        - crowdsecurity/apache2
    datasource:
      source: file
      labels:
        type: syslog
      filenames:
        - /var/log/httpd/*.log
```

----------------------------------------

TITLE: Generating Setup Configuration with cscli detect --yaml
DESCRIPTION: This console command shows how to use `cscli setup detect --yaml` to automatically detect services (like Apache and Linux system logs) and generate a setup configuration in YAML format. The output includes detected services, required collections/parsers, and data source configurations.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_8>

LANGUAGE: console
CODE:

```
$ cscli setup detect --yaml
setup:
  - detected_service: apache2-systemd-deb
    install:
      collections:
        - crowdsecurity/apache2
    datasource:
      filenames:
        - /var/log/apache2/*.log
      labels:
        type: apache2
  - detected_service: linux
    install:
      collections:
        - crowdsecurity/linux
    datasource:
      filenames:
        - /var/log/syslog
        - /var/log/kern.log
        - /var/log/messages
      labels:
        type: syslog
  - detected_service: whitelists
    install:
      parsers:
        - crowdsecurity/whitelists
```

----------------------------------------

TITLE: Install Vagrant Libvirt Plugin (Bash)
DESCRIPTION: Installs the necessary Vagrant plugin to interact with the libvirt virtualization provider.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_0>

LANGUAGE: Bash
CODE:

```
vagrant plugin install vagrant-libvirt
```

----------------------------------------

TITLE: Trigger Bucket for New TCP Connections - CrowdSec Configuration
DESCRIPTION: Sets up a trigger bucket named 'New connection' that activates upon detecting a new TCP connection. It filters events where the service is 'tcp' and a new connection is established. When the trigger condition is met ('on_overflow'), it initiates a 'Reprocess' action.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/leakybucket/README.md#_snippet_2>

LANGUAGE: CrowdSec Configuration
CODE:

```
- type: trigger
  name: \"New connection\"
  filter: \"Meta.service == 'tcp' && Event.new_connection == 'true'\"
  on_overflow: Reprocess
```

----------------------------------------

TITLE: Previewing Hub Installation with cscli setup (Console)
DESCRIPTION: Uses the `cscli setup install-hub` command with the `--dry-run` flag to show which collections, parsers, and other items would be installed based on the `setup.yaml` file generated by the detect step, without actually installing them.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_1>

LANGUAGE: console
CODE:

```
# cscli setup install-hub setup.yaml --dry-run
dry-run: would install collection crowdsecurity/apache2
dry-run: would install collection crowdsecurity/linux
dry-run: would install collection crowdsecurity/pgsql
dry-run: would install parser crowdsecurity/whitelists
```

----------------------------------------

TITLE: Detecting Apache2 using ProcessRunning (YAML)
DESCRIPTION: This snippet shows a basic `detect.yaml` configuration for detecting the `apache2` service by checking if the `apache2` process is running. It specifies the collection to install and the log file paths for data acquisition.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_4>

LANGUAGE: yaml
CODE:

```
version: 1.0

services:

  apache2:
    when:
      - ProcessRunning(\"apache2\")
    install:
      collections:
        - crowdsecurity/apache2
    datasources:
      source: file
      labels:
        type: apache2
      filenames:
        - /var/log/apache2/*.log
        - /var/log/httpd/*.log
```

----------------------------------------

TITLE: Load Initial Data from Tarball (instance-data load) - Shell
DESCRIPTION: Extracts the configuration, hub, and database files from the `./local-init/init-config-data.tar` archive created by `instance-data make` into the local test environment (`./test/local`). This restores the CrowdSec instance to the initial state defined in the tarball. CrowdSec must not be running during this operation.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_3>

LANGUAGE: Shell
CODE:

```
instance-data load
```

----------------------------------------

TITLE: Generating Datasource Configuration with cscli setup (Console)
DESCRIPTION: Runs the `cscli setup datasources` command with the `setup.yaml` file to generate acquisition configuration files. The `--to-dir` flag specifies the directory where these files will be created, typically `/etc/crowdsec/acquis.d`.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_3>

LANGUAGE: console
CODE:

```
# cscli setup datasources setup.yaml --to-dir /etc/crowdsec/acquis.d
```

----------------------------------------

TITLE: Counter Bucket for New TCP Connections - CrowdSec Configuration
DESCRIPTION: Defines a counter bucket named 'counter' to track new TCP connections. It filters events where the service is 'tcp' and a new connection is established. Events are counted distinctly based on the combination of source IP and destination port over a 5-minute duration with unlimited capacity.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/leakybucket/README.md#_snippet_1>

LANGUAGE: CrowdSec Configuration
CODE:

```
# reporting of src_ip,dest_port seen
- type: counter
  name: counter
  filter: \"Meta.service == 'tcp' && Event.new_connection == 'true'\"
  distinct: \"Meta.source_ip + ':' + Meta.dest_port\"
  duration: 5m
  capacity: -1
```

----------------------------------------

TITLE: Unlock Test Environment (instance-data unlock) - Shell
DESCRIPTION: Re-enables the BATS test suite, allowing it to run and potentially modify the local CrowdSec installation's configuration and data as part of test execution.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_5>

LANGUAGE: Shell
CODE:

```
instance-data unlock
```

----------------------------------------

TITLE: Detecting Services with cscli setup (Console)
DESCRIPTION: Runs the `cscli setup detect` command to identify installed services and system information. The output is redirected to `setup.yaml` for later use in installation and datasource generation.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_0>

LANGUAGE: console
CODE:

```
# cscli setup detect > setup.yaml
```

----------------------------------------

TITLE: Installing Hub Items with cscli setup (Console)
DESCRIPTION: Executes the `cscli setup install-hub` command using the `setup.yaml` file. This command downloads and enables the recommended collections, parsers, and other Crowdsec hub items corresponding to the detected services.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_2>

LANGUAGE: console
CODE:

```
# cscli setup install-hub setup.yaml
INFO[29-06-2022 03:16:14 PM] crowdsecurity/apache2-logs : OK              
INFO[29-06-2022 03:16:14 PM] Enabled parsers : crowdsecurity/apache2-logs 
INFO[29-06-2022 03:16:14 PM] crowdsecurity/http-logs : OK             
[...]
INFO[29-06-2022 03:16:18 PM] Enabled crowdsecurity/linux
```

----------------------------------------

TITLE: Defining OS Detection Services in YAML
DESCRIPTION: This YAML configuration defines services for different operating systems (Linux, FreeBSD, Windows). It specifies the condition (`when`) for activating the service based on the OS family, the collections to install (`install`), and the data sources (`datasource`) to monitor, such as system logs.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_7>

LANGUAGE: yaml
CODE:

```
version: 1.0

services:

  linux:
    when:
      - OS.Family == \"linux\"
    install:
      collections:
        - crowdsecurity/linux
    datasource:
      type: file
      labels:
        type: syslog
      log_files:
      - /var/log/syslog
      - /var/log/kern.log
      - /var/log/messages

  freebsd:
    when:
      - OS.Family == \"freebsd\"
    install:
      collections:
        - crowdsecurity/freebsd

  windows:
    when:
      - OS.Family == \"windows\"
    install:
      collections:
        - crowdsecurity/windows
```

----------------------------------------

TITLE: Building and Testing with PostgreSQL Backend
DESCRIPTION: These commands set the DB_BACKEND environment variable to 'pgx' and then execute the standard build, fixture setup, and test steps using the configured PostgreSQL database. This sequence is used after setting up the PostgreSQL container.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_9>

LANGUAGE: Shell
CODE:

```
export DB_BACKEND=pgx
make clean bats-build bats-fixture bats-test
```

----------------------------------------

TITLE: Building and Testing with MySQL Backend
DESCRIPTION: These commands set the DB_BACKEND environment variable to 'mysql' and then execute the standard build, fixture setup, and test steps using the configured MySQL database. This sequence is used after setting up the MySQL container.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_11>

LANGUAGE: Shell
CODE:

```
export DB_BACKEND=mysql
make clean bats-build bats-fixture bats-test
```

----------------------------------------

TITLE: Change Directory to Vagrant Distro Config (Bash)
DESCRIPTION: Navigates into the specific directory containing the Vagrant configuration for the desired distribution.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_2>

LANGUAGE: Bash
CODE:

```
cd vagrant/<distro-of-your-choice>
```

----------------------------------------

TITLE: Applying Patches with Quilt (Shell)
DESCRIPTION: This command uses the 'quilt' tool to apply patches defined in the 'debian/patches' directory. It pushes all patches ('-a') and then refreshes the patch series, typically done before building the package.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/debian/README.md#_snippet_0>

LANGUAGE: Shell
CODE:

```
QUILT_PATCHES=debian/patches quilt push -a && quilt refresh
```

----------------------------------------

TITLE: Create and Provision Vagrant VM Separately (Bash)
DESCRIPTION: Creates the virtual machine without provisioning, then provisions it in a separate step. This allows debugging if provisioning fails.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_3>

LANGUAGE: Bash
CODE:

```
vagrant up --no-provision; vagrant provision
```

----------------------------------------

TITLE: Source Environment Script (Bash)
DESCRIPTION: Executes the environment setup script in the current shell to configure necessary variables.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_1>

LANGUAGE: Bash
CODE:

```
source environment.sh
```

----------------------------------------

TITLE: Leaky Bucket for SSH Bruteforce - CrowdSec Configuration
DESCRIPTION: Configures a leaky bucket named 'ssh_bruteforce' to detect SSH bruteforce attempts. It filters logs for failed SSH authentication ('ssh_failed-auth'), stacks events by source IP, and bans the IP for 1 hour upon overflow after reaching a capacity of 5 events within a 10-second leak speed.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/leakybucket/README.md#_snippet_0>

LANGUAGE: CrowdSec Configuration
CODE:

```
# ssh bruteforce
- type: leaky
  name: ssh_bruteforce
  filter: \"Meta.log_type == 'ssh_failed-auth'\"
  leakspeed: \"10s\"
  capacity: 5
  stackkey: \"source_ip\"
  on_overflow: ban,1h
```

----------------------------------------

TITLE: Building Debian Package with dpkg-buildpackage (Shell)
DESCRIPTION: This command builds a Debian package using 'dpkg-buildpackage'. The flags '-uc' and '-us' prevent signing the changelog and source package respectively, while '-b' builds only the binary package.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/debian/README.md#_snippet_1>

LANGUAGE: Shell
CODE:

```
dpkg-buildpackage -uc -us -b
```

----------------------------------------

TITLE: Displaying Help for cscli setup datasources Command
DESCRIPTION: This console command displays the help information for the `cscli setup datasources` command. It shows the command usage, arguments (like `setup_file`), and available flags, including `--to-dir` for writing configuration to a directory.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/setup/README.md#_snippet_9>

LANGUAGE: console
CODE:

```
$ cscli setup datasources --help
generate datasource (acquisition) configuration from a setup file

Usage:
  cscli setup datasources [setup_file] [flags]

Flags:
  -h, --help            help for datasources
      --to-dir string   write the configuration to a directory, in multiple files
[...] 
```

----------------------------------------

TITLE: Parser Node Enrichment Configuration YAML
DESCRIPTION: Demonstrates how to trigger an enrichment method (like GeoIpCity) and copy results from the 'Enriched' map to the 'Meta' map using statics.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_8>

LANGUAGE: yaml
CODE:

```
statics:
  - method: GeoIpCity
    expression: Meta.source_ip
  - meta: IsoCode
    expression: Enriched.IsoCode
  - meta: IsInEU
    expression: Enriched.IsInEU
```

----------------------------------------

TITLE: Create and Provision Vagrant VM (Bash)
DESCRIPTION: Creates and provisions the virtual machine in a single command. Note that this destroys the VM on test failure.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_4>

LANGUAGE: Bash
CODE:

```
vagrant up
```

----------------------------------------

TITLE: Start CrowdSec Background Process (instance-crowdsec start) - Shell
DESCRIPTION: Starts the CrowdSec agent and/or LAPI as a background process within the local test environment. PID and lock files are managed in `./local/var/run/`. This allows tests to interact with a running CrowdSec instance.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_6>

LANGUAGE: Shell
CODE:

```
instance-crowdsec start
```

----------------------------------------

TITLE: Lock Test Environment (instance-data lock) - Shell
DESCRIPTION: Prevents the BATS test suite from running. This is useful when manually interacting with the local CrowdSec installation to ensure that automated tests do not overwrite or modify the current configuration and data.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_4>

LANGUAGE: Shell
CODE:

```
instance-data lock
```

----------------------------------------

TITLE: Parser Node OnSuccess Configuration YAML
DESCRIPTION: Illustrates configuring the behavior after a parser node successfully processes an event using the 'onsuccess' key, choosing between 'next_stage' or 'continue'.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_3>

LANGUAGE: yaml
CODE:

```
onsuccess: next_stage|continue
```

----------------------------------------

TITLE: Parser Node Statics Configuration YAML
DESCRIPTION: Shows how to define static assignments to the Event's Meta or Parsed dictionaries using the 'statics' key, allowing assignment from static values or expression results.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_4>

LANGUAGE: yaml
CODE:

```
statics:
    - meta: service
      value: tcp
    - meta: source_ip
      expression: \"Event['source_ip']\"
    - parsed: \"new_connection\"
      expression: \"Event['tcpflags'] contains 'S' ? 'true' : 'false'\"
    - target: Parsed.this_is_a_test
      value: foobar
```

----------------------------------------

TITLE: Generate Go Code from Protobuf using protoc
DESCRIPTION: This command uses the protoc compiler to generate Go code from the specified Protocol Buffer definition file. It generates standard Go structs (--go_out) and gRPC service code (--go-grpc_out), placing the output files relative to the source file path.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/protobufs/README.md#_snippet_0>

LANGUAGE: Shell
CODE:

```
protoc --go_out=. --go_opt=paths=source_relative \\
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \\
    proto/alert.proto
```

----------------------------------------

TITLE: Run Automated Prepare and Run Script (Bash)
DESCRIPTION: Executes the automated script that handles the preparation and running of tests across multiple Vagrant configurations. Requires Bash >= 4.4.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_6>

LANGUAGE: Bash
CODE:

```
./prepare-run
```

----------------------------------------

TITLE: Example Parser Node Configuration YAML
DESCRIPTION: Illustrates a complete parser node configuration including filter, debug, onsuccess, name, pattern_syntax, grok, and statics. Shows how to apply a grok pattern and set static metadata.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_0>

LANGUAGE: yaml
CODE:

```
filter: \"evt.Line.Labels.type == 'testlog'\"
debug: true
onsuccess: next_stage
name: tests/base-grok
pattern_syntax:
  MYCAP: \".*\"
nodes:
  - grok:
      pattern: ^xxheader %{MYCAP:extracted_value} trailing stuff$
      apply_on: Line.Raw
statics:
  - meta: log_type
    value: parsed_testlog
```

----------------------------------------

TITLE: Parser Node Grok Pattern by Name YAML
DESCRIPTION: Configures a grok pattern application using a predefined pattern name loaded from the patterns directory, applied to a specific event field.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_5>

LANGUAGE: yaml
CODE:

```
grok:
  name: \"TCPDUMP_OUTPUT\"
  apply_on: message
```

----------------------------------------

TITLE: Start CrowdSec Service (Shell)
DESCRIPTION: Uses the standard Windows net command to start the installed CrowdSec Windows service. This command requires Administrator privileges.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_5>

LANGUAGE: Shell
CODE:

```
net start crowdsec
```

----------------------------------------

TITLE: Destroy Vagrant VM (Bash)
DESCRIPTION: Destroys and removes the virtual machine created by Vagrant.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/ansible/README.md#_snippet_5>

LANGUAGE: Bash
CODE:

```
vagrant destroy
```

----------------------------------------

TITLE: Install CrowdSec Parser (PowerShell)
DESCRIPTION: Executes the cscli.exe command to install a specific parser configuration (crowdsecurity/syslog-logs) from the CrowdSec hub, enabling the agent to process syslog log files.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_3>

LANGUAGE: PowerShell
CODE:

```
& 'C:\\Program Files\\CrowdSec\\cscli.exe' parsers install crowdsecurity/syslog-logs
```

----------------------------------------

TITLE: Example Node Tree Configuration - YAML
DESCRIPTION: This YAML snippet demonstrates a basic Crowdsec parser node tree configuration. It shows how a root node uses a filter, contains child nodes with grok patterns and local statics, and applies global statics if any part of the tree processing is successful.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_9>

LANGUAGE: YAML
CODE:

```
filter: \"Event['program'] == 'nginx'\" #A
nodes: #A'
  - grok: #B
      name: \"NGINXACCESS\"
      # this statics will apply only if the above grok pattern matched
      statics: #B'
        - meta: log_type
          value: \"http_access-log\"
  - grok: #C
      name: \"NGINXERROR\"
      statics:
        - meta: log_type
          value: \"http_error-log\"
statics: #D
  - meta: service
    value: http
```

----------------------------------------

TITLE: Install CrowdSec Installer Dependencies (PowerShell)
DESCRIPTION: Executes the PowerShell script .\\windows\\install_installer_windows.ps1 to install additional dependencies needed specifically for building the CrowdSec MSI and Chocolatey installer packages on Windows.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_1>

LANGUAGE: PowerShell
CODE:

```
powershell .\\windows\\install_installer_windows.ps1
```

----------------------------------------

TITLE: View CrowdSec Metrics (PowerShell)
DESCRIPTION: Executes the cscli.exe command-line tool, typically located in the CrowdSec installation directory, to display current metrics and operational status of the CrowdSec agent.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_2>

LANGUAGE: PowerShell
CODE:

```
& 'C:\\Program Files\\CrowdSec\\cscli.exe' metrics
```

----------------------------------------

TITLE: Install CrowdSec Development Dependencies (PowerShell)
DESCRIPTION: Executes the PowerShell script .\\windows\\install_dev_windows.ps1 to install necessary dependencies like Go, GCC, and Git required for building CrowdSec from source on Windows.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_0>

LANGUAGE: PowerShell
CODE:

```
powershell .\\windows\\install_dev_windows.ps1
```

----------------------------------------

TITLE: Debugging Output in BATS Test (Shell)
DESCRIPTION: Demonstrates how to redirect output to file descriptor 3 (>&#x26;3) within a BATS test function to display debugging information even if the test passes. This output is separate from the standard stdout/stderr captured by bats-core.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_0>

LANGUAGE: Shell
CODE:

```
@test \"mytest\" {
   echo \"hello world!\" >&3
   run some-command
   assert_success
   echo \"goodbye.\" >&3
}
```

----------------------------------------

TITLE: Accessing Chocolatey Environment Variables (PowerShell)
DESCRIPTION: Demonstrates how to access environment variables made available by Chocolatey within PowerShell automation scripts. These variables provide information about the installation path, package details, and temporary directories.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/Chocolatey/crowdsec/ReadMe.md#_snippet_0>

LANGUAGE: PowerShell
CODE:

```
$env:TheVariableNameBelow
```

----------------------------------------

TITLE: Parser Node Grok Pattern Inline YAML
DESCRIPTION: Configures a grok pattern application using an inline pattern definition, applied to a specific event field.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_6>

LANGUAGE: yaml
CODE:

```
grok:
  pattern: \"^%{GREEDYDATA:request}\\\\?%{GREEDYDATA:http_args}$\"
  apply_on: request
```

----------------------------------------

TITLE: Including GMSL in a Makefile
DESCRIPTION: This snippet demonstrates the standard way to include the GNU Make Standard Library (GMSL) into a Makefile. By including 'gmsl', all the functions provided by the library become available for use in the current Makefile, as 'gmsl' automatically includes its dependency '__gmsl'.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_0>

LANGUAGE: Makefile
CODE:

```
include gmsl
```

----------------------------------------

TITLE: Parser Node Debug Configuration YAML
DESCRIPTION: Demonstrates enabling debug logging for a specific parser node using the 'debug' key.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_2>

LANGUAGE: yaml
CODE:

```
debug: true
```

----------------------------------------

TITLE: Parser Node Filter Configuration YAML
DESCRIPTION: Shows how to define a filter expression using the 'filter' key to conditionally apply a parser node based on event properties.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_1>

LANGUAGE: yaml
CODE:

```
filter: \"Line.Src endsWith '/foobar'\"
```

----------------------------------------

TITLE: Stop CrowdSec Service (Shell)
DESCRIPTION: Uses the standard Windows net command to stop the installed CrowdSec Windows service. This command requires Administrator privileges.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/windows/README.md#_snippet_4>

LANGUAGE: Shell
CODE:

```
net stop crowdsec
```

----------------------------------------

TITLE: BATS Setup and Teardown Execution Flow (Shell)
DESCRIPTION: Illustrates the execution order of setup_file, teardown_file, setup, teardown, and test functions (@test) in a BATS test file. It highlights that code outside functions is executed multiple times.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_1>

LANGUAGE: Shell
CODE:

```
echo \"begin\" >&3

setup_file() {
        echo \"setup_file\" >&3
}

teardown_file() {
        echo \"teardown_file\" >&3
}

setup() {
        echo \"setup\" >&3
}

teardown() {
        echo \"teardown\" >&3
}

@test \"test 1\" {
        echo \"test #1\" >&3
}

@test \"test 2\" {
        echo \"test #2\" >&3
}

echo \"end\" >&3
```

----------------------------------------

TITLE: Pushing Element onto GMSL Named Stack
DESCRIPTION: This function pushes a specified value onto the top of a named stack. The value must be a string without spaces. It returns nothing.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_20>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call push, <stack_name>, <value>)
```

----------------------------------------

TITLE: Decrementing X-Representation Number in GMSL
DESCRIPTION: This function decrements a number in 'x's representation by 1, returning the new value in the same representation. Note that it does not perform range checking and will not underflow.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_8>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_dec, <number>)
```

----------------------------------------

TITLE: Parser Node Pattern Syntax Definition YAML
DESCRIPTION: Defines custom sub-patterns within the parser node's scope using the 'pattern_syntax' key, allowing reuse within grok patterns in the same node.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/parser/README.md#_snippet_7>

LANGUAGE: yaml
CODE:

```
pattern_syntax:
  DIR: \"^.*/\"
  FILE: \"[^/].*$\"
```

----------------------------------------

TITLE: Getting Depth of GMSL Named Stack
DESCRIPTION: This function returns the current number of items present on a named stack, indicating its depth.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_23>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call depth, <stack_name>)
```

----------------------------------------

TITLE: Popping Element from GMSL Named Stack
DESCRIPTION: This function removes and returns the top element from a named stack. The stack must not be empty.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_21>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call pop, <stack_name>)
```

----------------------------------------

TITLE: Decrementing Integer in GMSL
DESCRIPTION: This function decrements a standard integer argument by 1, returning the decremented value. Note that it does not perform range checking and will not underflow.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_9>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call dec, <integer>)
```

----------------------------------------

TITLE: Incrementing X-Representation Number in GMSL
DESCRIPTION: This function increments a number in 'x's representation by 1, returning the new value in the same representation.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_6>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_inc, <number>)
```

----------------------------------------

TITLE: Memoizing Function Calls in GMSL
DESCRIPTION: This function provides a memoization mechanism to reduce redundant calls to slow functions, such as $(shell). It calls the specified function with the given string argument only once for each unique argument, caching and returning previous results for subsequent identical calls.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_24>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call memoize, <function_name>, <string_argument>)
```

----------------------------------------

TITLE: Doubling X-Representation Number in GMSL
DESCRIPTION: This function doubles a number in 'x's representation (multiplies by 2) and returns the result in the same representation.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_10>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_double, <number>)
```

----------------------------------------

TITLE: Doubling Integer in GMSL
DESCRIPTION: This function doubles a standard integer argument (multiplies by 2) and returns the result.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_11>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call double, <integer>)
```

----------------------------------------

TITLE: Listing Keys in GMSL Associative Array
DESCRIPTION: This function returns a list of all keys that are currently defined (not empty) within a specified named associative array.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_18>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call keys, <array_name>)
```

----------------------------------------

TITLE: Converting Decimal to Other Bases in GMSL
DESCRIPTION: These functions convert a decimal integer argument to its hexadecimal, binary, or octal string representation, respectively.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_15>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call dec2hex, <decimal_integer>)
$(call dec2bin, <decimal_integer>)
$(call dec2oct, <decimal_integer>)
```

----------------------------------------

TITLE: Incrementing Integer in GMSL
DESCRIPTION: This function increments a standard integer argument by 1, returning the incremented value.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_7>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call inc, <integer>)
```

----------------------------------------

TITLE: Retrieving Value from GMSL Associative Array
DESCRIPTION: This function retrieves the value associated with a given key from a named associative array. It returns the stored value.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_17>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call get, <array_name>, <key>)
```

----------------------------------------

TITLE: Echoing Variable Value with GMSL (Makefile)
DESCRIPTION: This GMSL target echoes only the value of a specified Make variable. Similar to 'gmsl-print-%', the '%' is a wildcard for the variable name, providing a concise way to retrieve variable values.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_27>

LANGUAGE: Shell
CODE:

```
make gmsl-echo-SHELL
```

----------------------------------------

TITLE: Matching 'Crowdsec' Case-Insensitive Regex
DESCRIPTION: This regular expression matches any line containing 'Crowdsec' or 'crowdsec'. The `[sS]` character class matches either a lowercase 's' or an uppercase 'S', making the match case-insensitive for that specific character.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/exprhelpers/tests/test_data_re.txt#_snippet_1>

LANGUAGE: Regex
CODE:

```
.*Crowd[sS]ec.*
```

----------------------------------------

TITLE: Stop CrowdSec Background Process (instance-crowdsec stop) - Shell
DESCRIPTION: Stops the background CrowdSec process that was started using `instance-crowdsec start`. This is typically used in test teardown phases to clean up running processes.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/test/README.md#_snippet_7>

LANGUAGE: Shell
CODE:

```
instance-crowdsec stop
```

----------------------------------------

TITLE: Setting Value in GMSL Associative Array
DESCRIPTION: This function sets a key-value pair in a named associative array. The key must be a string without spaces, and the value can be any string. It returns nothing.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_16>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call set, <array_name>, <key>, <value>)
```

----------------------------------------

TITLE: Halving X-Representation Number in GMSL
DESCRIPTION: This function halves a number in 'x's representation (divides by 2) and returns the result in the same representation.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_12>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_halve, <number>)
```

----------------------------------------

TITLE: Peeking Top Element of GMSL Named Stack
DESCRIPTION: This function returns the top element from a named stack without removing it. This allows inspection of the top element without modifying the stack.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_22>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call peek, <stack_name>)
```

----------------------------------------

TITLE: Halving Integer in GMSL
DESCRIPTION: This function halves a standard integer argument (divides by 2) and returns the result.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_13>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call halve, <integer>)
```

----------------------------------------

TITLE: Matching 'Crowdsec' Regex
DESCRIPTION: This regular expression matches any line containing the exact string 'Crowdsec'. The `.*` matches any character (except newline) zero or more times before and after 'Crowdsec'.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/pkg/exprhelpers/tests/test_data_re.txt#_snippet_0>

LANGUAGE: Regex
CODE:

```
.*Crowdsec.*
```

----------------------------------------

TITLE: Performing Integer Modulo in GMSL
DESCRIPTION: This function calculates the remainder of an integer division. It takes two integer arguments and returns the remainder of the first argument divided by the second.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_1>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_mod, <dividend>, <divisor>)
```

----------------------------------------

TITLE: Checking Key Definition in GMSL Associative Array
DESCRIPTION: This function checks if a specific key is defined (i.e., not empty) within a named associative array. It returns $(true) if the key is defined, otherwise $(false).

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_19>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call defined, <array_name>, <key>)
```

----------------------------------------

TITLE: GMSL Boolean Constant: true
DESCRIPTION: This constant represents the boolean true value in GMSL, used for conditional expressions like $(if) and as a return value from GMSL functions. It is accessed as a normal GNU Make variable.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_25>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(true)
```

----------------------------------------

TITLE: Generating Integer Sequence in GMSL
DESCRIPTION: This function generates a sequence of two integers. It returns `[arg1 arg2]` if `arg1` is greater than or equal to `arg2`, or `[arg2 arg1]` if `arg2` is greater than `arg1`.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_14>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call sequence, <integer1>, <integer2>)
```

----------------------------------------

TITLE: Printing Variable Value with GMSL (Makefile)
DESCRIPTION: This GMSL target allows printing the name and value of a specified Make variable. The '%' acts as a wildcard for the variable name. It's useful for debugging and inspecting variable states during a Make build.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_26>

LANGUAGE: Shell
CODE:

```
make gmsl-print-SHELL
```

----------------------------------------

TITLE: Finding Max/Min of Integers in GMSL
DESCRIPTION: These functions return the maximum or minimum of two standard integer arguments. They provide basic comparison functionality for integer values.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_3>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call max, <integer1>, <integer2>)
$(call min, <integer1>, <integer2>)
```

----------------------------------------

TITLE: Comparing X-Representation Numbers in GMSL
DESCRIPTION: These functions perform various comparison operations on two numbers in 'x's representation, returning $(true) or $(false). They include greater than, greater than or equal to, less than, less than or equal to, equal to, and not equal to.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_4>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_gt, <number1>, <number2>)
$(call int_gte, <number1>, <number2>)
$(call int_lt, <number1>, <number2>)
$(call int_lte, <number1>, <number2>)
$(call int_eq, <number1>, <number2>)
$(call int_ne, <number1>, <number2>)
```

----------------------------------------

TITLE: Finding Max/Min of X-Representation Numbers in GMSL
DESCRIPTION: These functions return the maximum or minimum of two numbers represented in 'x's representation. They are designed for specific numerical formats within the GMSL context.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_2>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call int_max, <number1>, <number2>)
$(call int_min, <number1>, <number2>)
```

----------------------------------------

TITLE: Comparing Integers in GMSL
DESCRIPTION: These functions perform standard comparison operations on two integer arguments, returning $(true) or $(false). They cover greater than, greater than or equal to, less than, less than or equal to, equal to, and not equal to for integer values.

SOURCE: <https://github.com/crowdsecurity/crowdsec/blob/master/mk/gmsl.html#_snippet_5>

LANGUAGE: GNU Make Scripting Language
CODE:

```
$(call gt, <integer1>, <integer2>)
$(call gte, <integer1>, <integer2>)
$(call lt, <integer1>, <integer2>)
$(call lte, <integer1>, <integer2>)
$(call eq, <integer1>, <integer2>)
$(call ne, <integer1>, <integer2>)
```", "uuid": "a28ca47f-477a-4f9b-8f74-ec3669e3e5ec"}]
