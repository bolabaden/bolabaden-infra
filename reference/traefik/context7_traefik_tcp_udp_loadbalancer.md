# context7_traefik_tcp_udp_loadbalancer_result.md

TITLE: Configure UDP Service with Two Servers using File Provider
DESCRIPTION: This snippet shows how to declare a UDP service named 'my-service' with two backend servers using Traefik's File Provider. It configures a load balancer to distribute UDP traffic between the specified addresses.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_2>

```yaml
udp:
  services:
    my-service:
      loadBalancer:
        servers:
        - address: "<private-ip-server-1>:<private-port-server-1>"
        - address: "<private-ip-server-2>:<private-port-server-2>"
```

```toml
## Dynamic configuration
[udp.services]
  [udp.services.my-service.loadBalancer]
     [[udp.services.my-service.loadBalancer.servers]]
       address = "<private-ip-server-1>:<private-port-server-1>"
     [[udp.services.my-service.loadBalancer.servers]]
       address = "<private-ip-server-2>:<private-port-server-2>"
```

----------------------------------------

TITLE: Configuring a Traefik UDP Service with a Single Server - YAML
DESCRIPTION: This YAML snippet demonstrates how to define a UDP service named `my-service` in Traefik's dynamic configuration. It configures a load balancer for this service, pointing to a single server at the specified address. This example is intended for use with the File Provider.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/udp/service.md#_snippet_0>

```yaml
## Dynamic configuration
udp:
  services:
    my-service:
      loadBalancer:
        servers:
          - address: "xx.xx.xx.xx:xx"
```

----------------------------------------

TITLE: Declaring TCP Service with Load Balancer
DESCRIPTION: This snippet demonstrates how to define a TCP service named 'my-service' using a load balancer. It configures the load balancer to distribute traffic across two specified server addresses. This configuration is typically used with the File Provider.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/service.md#_snippet_0>

```yaml
tcp:
  services:
    my-service:
      loadBalancer:
        servers:
        - address: "xx.xx.xx.xx:xx"
        - address: "xx.xx.xx.xx:xx"
```

```toml
[tcp.services]
  [tcp.services.my-service.loadBalancer]
    [[tcp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
    [[tcp.services.my-service.loadBalancer.servers]]
        address = "xx.xx.xx.xx:xx"
```2

----------------------------------------

TITLE: Configure TCP Service with Two Servers using File Provider
DESCRIPTION: This snippet illustrates how to declare a TCP service named 'my-service' with two backend servers using Traefik's File Provider. It sets up a load balancer to distribute TCP connections between the specified addresses.
SOURCE: https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_1

```yaml
tcp:
  services:
    my-service:
      loadBalancer:
        servers:
        - address: "<private-ip-server-1>:<private-port-server-1>"
        - address: "<private-ip-server-2>:<private-port-server-2>"
```

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.my-service.loadBalancer]
     [[tcp.services.my-service.loadBalancer.servers]]
       address = "<private-ip-server-1>:<private-port-server-1>"
     [[tcp.services.my-service.loadBalancer.servers]]
       address = "<private-ip-server-2>:<private-port-server-2>"
```

----------------------------------------

TITLE: Configuring a Traefik UDP Service with a Single Server - TOML
DESCRIPTION: This TOML snippet illustrates how to define a UDP service named `my-service` within Traefik's dynamic configuration. It sets up a load balancer for the service, directing traffic to a single server at the specified address. This configuration is suitable for use with the File Provider.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/udp/service.md#_snippet_1>

```toml
## Dynamic configuration
[udp.services]
  [udp.services.my-service.loadBalancer]
    [[udp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
```

----------------------------------------

TITLE: Declare UDP Service with One Load Balanced Server
DESCRIPTION: Example of defining a UDP service with a load balancer pointing to a single backend server. This configuration uses Traefik's file provider and is shown in both YAML and TOML formats.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_63>

```yaml
## Dynamic configuration
udp:
  services:
    my-service:
      loadBalancer:
        servers:
          - address: "xx.xx.xx.xx:xx"
```

```toml
## Dynamic configuration
[udp.services]
  [udp.services.my-service.loadBalancer]
    [[udp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
```

----------------------------------------

TITLE: Declare UDP Service with Two Load Balanced Servers
DESCRIPTION: Example of defining a UDP service with a load balancer distributing requests between two backend servers. This configuration uses Traefik's file provider and is shown in both YAML and TOML formats.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_62>

```yaml
## Dynamic configuration
udp:
  services:
    my-service:
      loadBalancer:
        servers:
        - address: "xx.xx.xx.xx:xx"
        - address: "xx.xx.xx.xx:xx"
```

```toml
## Dynamic configuration
[udp.services]
  [udp.services.my-service.loadBalancer]
    [[udp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
    [[udp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
```

----------------------------------------

TITLE: Configure UDP Service Weighted Round Robin (Partial)
DESCRIPTION: Initiates the configuration for a UDP service using the Weighted Round Robin (WRR) strategy. This strategy is only available with the File provider and for load balancing between services, not individual servers. The provided snippet is a partial YAML example.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_64>

```yaml
## Dynamic configuration
udp:
```

----------------------------------------

TITLE: Configure HTTP Service with Load Balancing across Two Servers using File Provider
DESCRIPTION: This example demonstrates declaring an HTTP service 'my-service' with a load balancer distributing requests between two generic server URLs. It highlights the basic configuration for load balancing using Traefik's File Provider.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_3>

```yaml
http:
  services:
    my-service:
      loadBalancer:
        servers:
        - url: "http://private-ip-server-1/"
        - url: "http://private-ip-server-2/"
```

```toml
## Dynamic configuration
[http.services]
  [http.services.my-service.loadBalancer]

    [[http.services.my-service.loadBalancer.servers]]
      url = "http://private-ip-server-1/"
    [[http.services.my-service.loadBalancer.servers]]
      url = "http://private-ip-server-2/"
```

----------------------------------------

TITLE: Configuring TCP IP AllowList Middleware in TOML File
DESCRIPTION: This TOML configuration file snippet defines a TCP router, an IP allowlist middleware, and a TCP service. It sets up `router1` to use `foo-ip-allowlist` middleware and routes traffic to `myService`, which is configured with a load balancer distributing connections to two backend servers. This is a static configuration approach for Traefik.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/overview.md#_snippet_3>

```toml
# As TOML Configuration File
[tcp.routers]
  [tcp.routers.router1]
    service = "myService"
    middlewares = ["foo-ip-allowlist"]
    rule = "Host(`example.com`)"

[tcp.middlewares]
  [tcp.middlewares.foo-ip-allowlist.ipAllowList]
    sourceRange = ["127.0.0.1/32", "192.168.1.7"]

[tcp.services]
  [tcp.services.service1]
    [tcp.services.service1.loadBalancer]
    [[tcp.services.service1.loadBalancer.servers]]
      address = "10.0.0.10:4000"
    [[tcp.services.service1.loadBalancer.servers]]
      address = "10.0.0.11:4000"
```

----------------------------------------

TITLE: Configuring TCP IP AllowList Middleware in YAML File
DESCRIPTION: This YAML configuration file snippet demonstrates how to define a TCP router, an IP allowlist middleware, and a TCP service. It configures `router1` to apply the `foo-ip-allowlist` middleware and forward requests to `myService`, which balances connections across two specified backend servers. This provides a clear, human-readable static configuration for Traefik.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/overview.md#_snippet_4>

```yaml
# As YAML Configuration File
tcp:
  routers:
    router1:
      service: myService
      middlewares:
        - "foo-ip-allowlist"
      rule: "Host(`example.com`)"

  middlewares:
    foo-ip-allowlist:
      ipAllowList:
        sourceRange:
          - "127.0.0.1/32"
          - "192.168.1.7"

  services:
    service1:
      loadBalancer:
        servers:
        - address: "10.0.0.10:4000"
        - address: "10.0.0.11:4000"
```

----------------------------------------

TITLE: Configure Dynamic UDP Services with Weighted Load Balancing
DESCRIPTION: This configuration snippet demonstrates how to set up dynamic UDP services in Traefik. It defines a main 'app' service with weighted load balancing across 'appv1' and 'appv2' services, each pointing to specific server addresses. This allows for distributing UDP traffic based on defined weights.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_65>

```yaml
udp:
  services:
    app:
      weighted:
        services:
        - name: appv1
          weight: 3
        - name: appv2
          weight: 1

    appv1:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"

    appv2:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"
```

```toml
## Dynamic configuration
[udp.services]
  [udp.services.app]
    [[udp.services.app.weighted.services]]
      name = "appv1"
      weight = 3
    [[udp.services.app.weighted.services]]
      name = "appv2"
      weight = 1

  [udp.services.appv1]
    [udp.services.appv1.loadBalancer]
      [[udp.services.appv1.loadBalancer.servers]]
        address = "private-ip-server-1:8080/"

  [udp.services.appv2]
    [udp.services.appv2.loadBalancer]
      [[udp.services.appv2.loadBalancer.servers]]
        address = "private-ip-server-2:8080/"
```

----------------------------------------

TITLE: Enable Native Load Balancing for Traefik UDP Services
DESCRIPTION: This configuration illustrates how to enable native load balancing for a Traefik IngressRouteUDP by setting `nativeLB: true` on the service definition. This instructs Traefik to use the Kubernetes Service's cluster IP directly, avoiding the creation of a server load balancer with individual pod IPs, which is beneficial for UDP services.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kubernetes-crd.md#_snippet_46>

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: test.route
  namespace: default

spec:
  entryPoints:
    - foo

  routes:
  - services:
    - name: svc
      port: 80
      # Here, nativeLB instructs to build the servers load balancer with the Kubernetes Service clusterIP only.
      nativeLB: true

---
apiVersion: v1
kind: Service
metadata:
  name: svc
  namespace: default
spec:
  type: ClusterIP
  ...
```

----------------------------------------

TITLE: Configuring TCP Router with IP AllowList Middleware (YAML)
DESCRIPTION: This snippet demonstrates how to configure a TCP router, attach an IP allowlist middleware, and define a TCP service with load balancing using a YAML configuration file in Traefik. It restricts access to specified IP ranges.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/overview.md#_snippet_0>

```yaml
# As YAML Configuration File
tcp:
  routers:
    router1:
      service: myService
      middlewares:
        - "foo-ip-allowlist"
      rule: "Host(`example.com`)"

  middlewares:
    foo-ip-allowlist:
      ipAllowList:
        sourceRange:
          - "127.0.0.1/32"
          - "192.168.1.7"

  services:
    service1:
      loadBalancer:
        servers:
        - address: "10.0.0.10:4000"
        - address: "10.0.0.11:4000"
```

----------------------------------------

TITLE: Configuring Traefik Static Entrypoint and File Provider (CLI)
DESCRIPTION: This CLI snippet configures Traefik's static settings via command-line arguments. It sets an entrypoint named 'web' to listen on port 8081 for incoming HTTP requests and enables the file provider, directing it to a specified directory for dynamic configuration files. This enables Traefik to load routing rules, middlewares, and services from external files.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/overview.md#_snippet_2>

```bash
# Listen on port 8081 for incoming requests
--entryPoints.web.address=:8081

# Enable the file provider to define routers / middlewares / services in file
--providers.file.directory=/path/to/dynamic/conf
```

----------------------------------------

TITLE: Setting Up Traefik Static Configuration (Entry Points & File Provider)
DESCRIPTION: These examples illustrate how to configure Traefik's static settings, including defining an entry point (`web` on port `8081`) and enabling the file provider to load dynamic configurations from a specified directory. This is essential for Traefik to listen for requests and discover routing rules.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/overview.md#_snippet_5>

```yaml
entryPoints:
  web:
    # Listen on port 8081 for incoming requests
    address: :8081
providers:
  # Enable the file provider to define routers / middlewares / services in file
  file:
    directory: /path/to/dynamic/conf
```

```toml
[entryPoints]
  [entryPoints.web]
    # Listen on port 8081 for incoming requests
    address = ":8081"

[providers]
  # Enable the file provider to define routers / middlewares / services in file
  [providers.file]
    directory = "/path/to/dynamic/conf"
```

```Bash
# Listen on port 8081 for incoming requests
--entryPoints.web.address=:8081

# Enable the file provider to define routers / middlewares / services in file
--providers.file.directory=/path/to/dynamic/conf
```

----------------------------------------

TITLE: Defining UDP Service Load Balancer Port in Traefik (YAML)
DESCRIPTION: This tag registers a specific port for a UDP service's load balancer. Traefik will use this port to connect to the backend application instance, enabling the load balancer to correctly direct UDP traffic.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_59>

```yaml
traefik.udp.services.myudpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: Configuring Weighted Round Robin TCP Service
DESCRIPTION: This snippet illustrates configuring a Weighted Round Robin (WRR) load balancer for TCP services. It defines an 'app' service that distributes requests to 'appv1' and 'appv2' based on their respective weights (3 and 1). It also shows the underlying 'appv1' and 'appv2' services, each using a standard load balancer to specific server addresses.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/service.md#_snippet_1>

```yaml
tcp:
  services:
    app:
      weighted:
        services:
        - name: appv1
          weight: 3
        - name: appv2
          weight: 1

    appv1:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"

    appv2:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"
```

```toml
[tcp.services]
  [tcp.services.app]
    [[tcp.services.app.weighted.services]]
      name = "appv1"
      weight = 3
    [[tcp.services.app.weighted.services]]
      name = "appv2"
      weight = 1

  [tcp.services.appv1]
    [tcp.services.appv1.loadBalancer]
      [[tcp.services.appv1.loadBalancer.servers]]
        address = "private-ip-server-1:8080/"

  [tcp.services.appv2]
    [tcp.services.appv2.loadBalancer]
      [[tcp.services.appv2.loadBalancer.servers]]
        address = "private-ip-server-2:8080/"
```

----------------------------------------

TITLE: Referencing ServersTransport for TCP Service in Traefik (YAML)
DESCRIPTION: This snippet allows a TCP service's load balancer to reference a predefined ServersTransport resource. This resource, 'foobar@file', defines how Traefik communicates with backend servers for 'mytcpservice'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/ecs.md#_snippet_54>

```yaml
traefik.tcp.services.<service_name>.loadbalancer.serverstransport=foobar@file
```

----------------------------------------

TITLE: Configuring a Basic IngressRouteUDP in Kubernetes
DESCRIPTION: This snippet demonstrates a fundamental IngressRouteUDP configuration. It defines an entry point for incoming UDP traffic and routes it to a specified Kubernetes Service, enabling native load balancing across its pods. This setup is essential for exposing UDP services via Traefik.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/udp/ingressrouteudp.md#_snippet_0>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: ingressrouteudpfoo
  namespace: apps
spec:
  entryPoints:
    - fooudp  # The entry point where Traefik listens for incoming traffic.
  routes:
  - services:
    - name: foo # The name of the Kubernetes Service to route to.
      port: 8080
      weight: 10
      nativeLB: true # Enables native load balancing between pods.
```

----------------------------------------

TITLE: Reference Traefik TCP Service Load Balancer ServersTransport
DESCRIPTION: Allows referencing a ServersTransport resource for a TCP service load balancer, defined via File or Kubernetes CRD provider. This resource defines how Traefik connects to backend servers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/swarm.md#_snippet_53>

```yaml
- "traefik.tcp.services.<service_name>.loadbalancer.serverstransport=foobar@file"
```

----------------------------------------

TITLE: Traefik UDP Router and Service Configuration Paths
DESCRIPTION: This snippet lists common configuration paths for Traefik's UDP routers and services, including entry points, service assignments, and load balancer server addresses or weighted service definitions. The values shown are placeholders.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_34>

```apidoc
| `traefik/udp/routers/UDPRouter1/entryPoints/0` | `foobar` |
| `traefik/udp/routers/UDPRouter1/entryPoints/1` | `foobar` |
| `traefik/udp/routers/UDPRouter1/service` | `foobar` |
| `traefik/udp/services/UDPService01/loadBalancer/servers/0/address` | `foobar` |
| `traefik/udp/services/UDPService01/loadBalancer/servers/1/address` | `foobar` |
| `traefik/udp/services/UDPService02/weighted/services/0/name` | `foobar` |
| `traefik/udp/services/UDPService02/weighted/services/0/weight` | `42` |
| `traefik/udp/services/UDPService02/weighted/services/1/name` | `foobar` |
| `traefik/udp/services/UDPService02/weighted/services/1/weight` | `42` |
```

----------------------------------------

TITLE: Configuring Traefik Static Entrypoint and File Provider (YAML)
DESCRIPTION: This YAML snippet configures Traefik's static settings. It defines an entrypoint named 'web' listening on port 8081 for incoming HTTP requests and enables the file provider, specifying a directory for dynamic configuration files. This allows Traefik to discover routers, middlewares, and services from files.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/overview.md#_snippet_0>

```yaml
entryPoints:
  web:
    # Listen on port 8081 for incoming requests
    address: :8081

providers:
  # Enable the file provider to define routers / middlewares / services in file
  file:
    directory: /path/to/dynamic/conf
```

----------------------------------------

TITLE: Registering a Port for a UDP Service Load Balancer in Traefik
DESCRIPTION: This example demonstrates how to register a specific port, `423`, for a server within a UDP service's load balancer. This tells Traefik which port on the backend application the UDP service should forward traffic to.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/ecs.md#_snippet_59>

```yaml
traefik.udp.services.myudpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: Configure Traefik TCP Service Load Balancer PROXY Protocol Version
DESCRIPTION: Configures the PROXY protocol version for a TCP service load balancer. This enables Traefik to send client connection information to the backend.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/swarm.md#_snippet_52>

```yaml
- "traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1"
```

----------------------------------------

TITLE: Configuring TCP Router with IP AllowList Middleware (TOML)
DESCRIPTION: This snippet demonstrates how to configure a TCP router, attach an IP allowlist middleware, and define a TCP service with load balancing using a TOML configuration file in Traefik. It restricts access to specified IP ranges.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/overview.md#_snippet_1>

```toml
# As TOML Configuration File
[tcp.routers]
  [tcp.routers.router1]
    service = "myService"
    middlewares = ["foo-ip-allowlist"]
    rule = "Host(`example.com`)"

[tcp.middlewares]
  [tcp.middlewares.foo-ip-allowlist.ipAllowList]
    sourceRange = ["127.0.0.1/32", "192.168.1.7"]

[tcp.services]
  [tcp.services.service1]
    [tcp.services.service1.loadBalancer]
    [[tcp.services.service1.loadBalancer.servers]]
      address = "10.0.0.10:4000"
    [[tcp.services.service1.loadBalancer.servers]]
      address = "10.0.0.11:4000"
```

----------------------------------------

TITLE: Configure HTTP Service with Two Servers using File Provider
DESCRIPTION: This snippet demonstrates how to declare an HTTP service named 'my-service' with two backend servers using Traefik's File Provider. It configures a load balancer to distribute requests between the specified URLs.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_0>

```yaml
## Dynamic configuration
http:
  services:
    my-service:
      loadBalancer:
        servers:
        - url: "http://<private-ip-server-1>:<private-port-server-1>/"
        - url: "http://<private-ip-server-2>:<private-port-server-2>/"
```

```toml
## Dynamic configuration
[http.services]
  [http.services.my-service.loadBalancer]

    [[http.services.my-service.loadBalancer.servers]]
      url = "http://<private-ip-server-1>:<private-port-server-1>/"
    [[http.services.my-service.loadBalancer.servers]]
      url = "http://<private-ip-server-2>:<private-port-server-2>/"
```

----------------------------------------

TITLE: Referencing ServersTransport for TCP Service Load Balancer in Traefik (YAML)
DESCRIPTION: This option allows a TCP service's load balancer to reference a pre-defined `ServersTransport` resource. This resource specifies advanced transport configurations, such as client TLS settings for connections to backend servers, and can be defined via file or Kubernetes CRD providers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/nomad.md#_snippet_52>

```yaml
traefik.tcp.services.myservice.loadbalancer.serverstransport=foobar@file
```

----------------------------------------

TITLE: Referencing ServersTransport for TCP Service Load Balancer in Traefik (YAML)
DESCRIPTION: Allows referencing a custom ServersTransport resource, which defines advanced transport options for connections to backend servers. This example links 'mytcpservice' to the 'foobar@file' ServersTransport.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_54>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.serverstransport=foobar@file
```

----------------------------------------

TITLE: Example: Declaring a Basic IngressRouteUDP
DESCRIPTION: Illustrates a basic declaration of an `IngressRouteUDP` resource with two services, `foo` and `bar`, each configured with a specific port and weight for load balancing UDP traffic.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kubernetes-crd.md#_snippet_43>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: ingressrouteudpfoo

spec:
  entryPoints:
    - fooudp
  routes:
  - services:
    - name: foo
      port: 8080
      weight: 10
    - name: bar
      port: 8081
      weight: 10
```

----------------------------------------

TITLE: Configure Traefik TCP Service Load Balancer PROXY Protocol Version
DESCRIPTION: Configure the PROXY protocol version for a Traefik TCP service's load balancer. This enables Traefik to send client connection information to the backend.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/docker.md#_snippet_60>

```yaml
- "traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1"
```

----------------------------------------

TITLE: Configuring PROXY Protocol Version for Traefik TCP Service
DESCRIPTION: Specifies the version of the PROXY protocol to be used by the TCP service load balancer. This allows for the transmission of client connection information to the backend servers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/nomad.md#_snippet_53>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1
```

----------------------------------------

TITLE: Referencing Servers Transport in Traefik Load Balancer
DESCRIPTION: This setting allows a Traefik HTTP service load balancer to reference a pre-defined ServersTransport resource. This resource, typically defined via File provider or Kubernetes CRD, specifies custom transport settings like TLS configurations for backend connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kv.md#_snippet_14>

```Traefik Configuration
traefik/http/services/myservice/loadbalancer/serverstransport: foobar@file
```

----------------------------------------

TITLE: Declaring UDP Routers and Services in Traefik (YAML)
DESCRIPTION: This snippet demonstrates how to declare both a UDP router and a UDP service using Traefik tags. It sets an entrypoint for the router and defines the server port for the service's load balancer.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_56>

```yaml
traefik.udp.routers.my-router.entrypoints=udp
traefik.udp.services.my-service.loadbalancer.server.port=4123
```

----------------------------------------

TITLE: Registering TCP Service Load Balancer Server Port in Traefik (YAML)
DESCRIPTION: Registers a specific port of the backend application for the TCP service's load balancer. This port is where the service listens for connections. This example sets the port to 423 for 'mytcpservice'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_51>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: Configure Traefik TCP Service Load Balancer Server Port in YAML
DESCRIPTION: This snippet demonstrates how to register a specific port for a backend server within a Traefik TCP service's load balancer. This port is where the load balancer will send traffic to the application instance. It's essential for correct service discovery.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/swarm.md#_snippet_56>

```yaml
- "traefik.tcp.services.mytcpservice.loadbalancer.server.port=423"
```

----------------------------------------

TITLE: Configuring Traefik Static Entrypoint and File Provider (TOML)
DESCRIPTION: This TOML snippet configures Traefik's static settings. It defines an entrypoint named 'web' listening on port 8081 for incoming HTTP requests and enables the file provider, specifying a directory for dynamic configuration files. This allows Traefik to discover routers, middlewares, and services from files.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/overview.md#_snippet_1>

```toml
[entryPoints]
  [entryPoints.web]
    # Listen on port 8081 for incoming requests
    address = ":8081"

[providers]
  # Enable the file provider to define routers / middlewares / services in file
  [providers.file]
    directory = "/path/to/dynamic/conf"
```

----------------------------------------

TITLE: Configure Traefik TCP Service Load Balancer Server Port
DESCRIPTION: Registers a specific port of the application backend for the TCP service's load balancer. This is the port Traefik will connect to on the backend server.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/docker.md#_snippet_57>

```apidoc
traefik.tcp.services.<service_name>.loadbalancer.server.port:
  description: Registers a port of the application backend.
  type: integer
```

```yaml
"traefik.tcp.services.mytcpservice.loadbalancer.server.port=423"
```

----------------------------------------

TITLE: Referencing ServersTransport for Traefik TCP Service
DESCRIPTION: Allows a TCP service to reference a pre-defined ServersTransport resource. This resource can be configured via the File provider or Kubernetes CRD, enabling advanced transport options for backend connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/nomad.md#_snippet_54>

```yaml
traefik.tcp.services.myservice.loadbalancer.serverstransport=foobar@file
```

----------------------------------------

TITLE: Reference Traefik TCP Service Load Balancer Servers Transport
DESCRIPTION: Reference a custom ServersTransport resource for a Traefik TCP service's load balancer. This allows for advanced transport configurations, such as custom TLS settings for backend connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/docker.md#_snippet_61>

```yaml
- "traefik.tcp.services.<service_name>.loadbalancer.serverstransport=foobar@file"
```

----------------------------------------

TITLE: Registering TCP Service Load Balancer Port in Traefik (YAML)
DESCRIPTION: This snippet registers a specific port for a server within a TCP service's load balancer. The 'mytcpservice' will forward traffic to port 423 on its backend servers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/ecs.md#_snippet_50>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: Attaching TCP ServersTransport to Service in TOML
DESCRIPTION: This TOML snippet demonstrates how to associate a defined `serversTransport` (e.g., `mytransport`) with a specific TCP service (`Service01`) under the load balancer configuration in Traefik's dynamic settings. This applies the transport's connection properties to the service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/serverstransport.md#_snippet_3>

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.Service01]
    [tcp.services.Service01.loadBalancer]
      serversTransport = "mytransport"
```

----------------------------------------

TITLE: Referencing ServersTransport in Traefik Load Balancer (YAML)
DESCRIPTION: Allows referencing a `ServersTransport` resource, which defines custom transport settings for the backend servers. This resource can be defined either with the File provider or the Kubernetes CRD.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/nomad.md#_snippet_17>

```yaml
traefik.http.services.myservice.loadbalancer.serverstransport=foobar@file
```

----------------------------------------

TITLE: Implement Weighted Round Robin Load Balancing in Traefik TCP Services
DESCRIPTION: This configuration demonstrates how to set up Weighted Round Robin (WRR) load balancing for TCP services in Traefik. It allows distributing requests to different backend services (`appv1`, `appv2`) based on their assigned weights, ensuring more traffic goes to higher-weighted services.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_49>

```yaml
## Dynamic configuration
tcp:
  services:
    app:
      weighted:
        services:
        - name: appv1
          weight: 3
        - name: appv2
          weight: 1

    appv1:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"

    appv2:
      loadBalancer:
        servers:
        - address: "xxx.xxx.xxx.xxx:8080"
```

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.app]
    [[tcp.services.app.weighted.services]]
      name = "appv1"
      weight = 3
    [[tcp.services.app.weighted.services]]
      name = "appv2"
      weight = 1

  [tcp.services.appv1]
    [tcp.services.appv1.loadBalancer]
      [[tcp.services.appv1.loadBalancer.servers]]
        address = "private-ip-server-1:8080/"

  [tcp.services.appv2]
    [tcp.services.appv2.loadBalancer]
      [[tcp.services.appv2.loadBalancer.servers]]
        address = "private-ip-server-2:8080/"
```

----------------------------------------

TITLE: Configuring Traefik EntryPoints for Both TCP and UDP
DESCRIPTION: This example demonstrates how to configure Traefik entry points to listen on the same port for both TCP and UDP protocols, requiring two separate entry point definitions.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/entrypoints.md#_snippet_5>

```yaml
## Static configuration
entryPoints:
  tcpep:
   address: ":3179"
  udpep:
   address: ":3179/udp"
```

```toml
## Static configuration
[entryPoints]
  [entryPoints.tcpep]
    address = ":3179"
  [entryPoints.udpep]
    address = ":3179/udp"
```

```bash
## Static configuration
--entryPoints.tcpep.address=:3179
--entryPoints.udpep.address=:3179/udp
```

----------------------------------------

TITLE: Declare Traefik TCP Service with a Single Load-Balanced Server
DESCRIPTION: Shows how to configure a Traefik TCP service with a load balancer pointing to a single backend server. This setup is useful for simple deployments or when a single instance handles all TCP traffic for a specific service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_44>

```yaml
## Dynamic configuration
tcp:
  services:
    my-service:
      loadBalancer:
        servers:
          - address: "xx.xx.xx.xx:xx"
```

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.my-service.loadBalancer]
    [[tcp.services.my-service.loadBalancer.servers]]
      address = "xx.xx.xx.xx:xx"
```

----------------------------------------

TITLE: Attaching TCP ServersTransport to Service in YAML
DESCRIPTION: This YAML snippet illustrates how to attach a previously defined `serversTransport` named `mytransport` to a TCP service named `Service01` within Traefik's load balancer configuration. This links the transport settings to the service's backend connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/serverstransport.md#_snippet_2>

```yaml
tcp:
  services:
    Service01:
      loadBalancer:
        serversTransport: mytransport
```

----------------------------------------

TITLE: Enabling TLS for TCP Servers Transport
DESCRIPTION: This configuration defines the TLS settings for connecting with TCP backends. An empty `tls` section enables TLS with default settings.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/overview.md#_snippet_18>

```yaml
## Static configuration
tcpServersTransport:
  tls: {}
```

```toml
## Static configuration
[tcpServersTransport.tls]
```

```Bash
## Static configuration
--tcpServersTransport.tls=true
```

----------------------------------------

TITLE: Reference Traefik TCP Service Load Balancer ServersTransport
DESCRIPTION: Allows referencing a ServersTransport resource for the TCP service's load balancer. This resource defines how Traefik communicates with backend servers, including TLS client configuration.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/docker.md#_snippet_60>

```apidoc
traefik.tcp.services.<service_name>.loadbalancer.serverstransport:
  description: References a ServersTransport resource for backend communication.
  type: string
```

```yaml
"traefik.tcp.services.mytcpservice.loadbalancer.serverstransport=foobar@file"
```

----------------------------------------

TITLE: Configuring PROXY Protocol Version for TCP Service in Traefik (YAML)
DESCRIPTION: This snippet configures the PROXY protocol version to be used by the TCP service's load balancer when communicating with backend servers. Setting it to '1' enables PROXY protocol version 1 for 'mytcpservice'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/ecs.md#_snippet_53>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1
```

----------------------------------------

TITLE: Configure PROXY Protocol for Traefik TCP Services
DESCRIPTION: This configuration demonstrates how to enable and specify the version (1 or 2) of the PROXY Protocol for a TCP service's load balancer in Traefik. It allows the proxy to pass client connection information to the backend.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_47>

```yaml
## Dynamic configuration
tcp:
  services:
    my-service:
      loadBalancer:
        proxyProtocol:
          version: 1
```

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.my-service.loadBalancer]
    [tcp.services.my-service.loadBalancer.proxyProtocol]
      version = 1
```

----------------------------------------

TITLE: Enabling TLS for TCP Service Load Balancer Server in Traefik (YAML)
DESCRIPTION: Determines whether Traefik should use TLS when establishing connections to the backend server through the load balancer. This example enables TLS for the backend connection of 'mytcpservice'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_52>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.server.tls=true
```

----------------------------------------

TITLE: Declaring Traefik HTTP Routers, Middlewares, and Services
DESCRIPTION: This example illustrates how to define HTTP routers, middlewares, and services within Traefik's dynamic configuration using the file provider. It shows a router `router0` routing `Path('/foo')` to `service-foo` with `my-basic-auth` middleware, which uses basic authentication with specified users and a password file. The `service-foo` is configured with a load balancer distributing requests to `http://foo/` and `http://bar/`.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/providers/file.md#_snippet_1>

```yaml
http:
  # Add the router
  routers:
    router0:
      entryPoints:
      - web
      middlewares:
      - my-basic-auth
      service: service-foo
      rule: Path(`/foo`)

  # Add the middleware
  middlewares:
    my-basic-auth:
      basicAuth:
        users:
        - test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
        - test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0
        usersFile: etc/traefik/.htpasswd

  # Add the service
  services:
    service-foo:
      loadBalancer:
        servers:
        - url: http://foo/
        - url: http://bar/
        passHostHeader: false
```

```toml
[http]
  # Add the router
  [http.routers]
    [http.routers.router0]
      entryPoints = ["web"]
      middlewares = ["my-basic-auth"]
      service = "service-foo"
      rule = "Path(`/foo`)"

  # Add the middleware
  [http.middlewares]
    [http.middlewares.my-basic-auth.basicAuth]
      users = ["test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/",
                "test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0"]
      usersFile = "etc/traefik/.htpasswd"

  # Add the service
  [http.services]
    [http.services.service-foo]
      [http.services.service-foo.loadBalancer]
        [[http.services.service-foo.loadBalancer.servers]]
          url = "http://foo/"
        [[http.services.service-foo.loadBalancer.servers]]
          url = "http://bar/"
```

----------------------------------------

TITLE: Assigning Service to UDP Router in Traefik (YAML)
DESCRIPTION: This tag links a specific UDP service to a UDP router. The router will forward incoming UDP traffic to the service identified by `myservice`, enabling load balancing and routing to the backend application.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_58>

```yaml
traefik.udp.routers.myudprouter.service=myservice
```

----------------------------------------

TITLE: Reference ServersTransport for Traefik TCP Service Load Balancer in YAML
DESCRIPTION: This snippet demonstrates how to reference a ServersTransport resource within a Traefik TCP service's load balancer configuration. A ServersTransport defines advanced connection settings for backend servers, such as TLS client certificates or insecure skip verify. This allows for flexible and secure backend communication.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/swarm.md#_snippet_59>

```yaml
- "traefik.tcp.services.<service_name>.loadbalancer.serverstransport=foobar@file"
```

----------------------------------------

TITLE: Register Traefik UDP Service Load Balancer Server Port
DESCRIPTION: Registers a port of the application for a UDP service load balancer. This is the port Traefik will use to connect to the backend UDP service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/swarm.md#_snippet_57>

```yaml
- "traefik.udp.services.myudpservice.loadbalancer.server.port=423"
```

----------------------------------------

TITLE: Registering Backend Server Port for UDP Service in Traefik (YAML)
DESCRIPTION: This snippet registers a specific port for a backend server within a UDP service's load balancer configuration in Traefik. This port is where the UDP service will send datagrams to the actual application instance.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/ecs.md#_snippet_58>

```yaml
traefik.udp.services.myudpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: IngressRouteUDP CRD Definition
DESCRIPTION: Defines the structure and attributes of the `IngressRouteUDP` Custom Resource Definition for Traefik UDP routers in Kubernetes. Key attributes include `entryPoints` for specifying entry points, `routes` containing `services` definitions, `name` for the Kubernetes service, `port` for the service port (can reference a named port), `weight` for load balancing, `nativeLB` for direct pod IP load balancing, and `nodePortLB` for NodePort service type load balancing.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kubernetes-crd.md#_snippet_42>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: ingressrouteudpfoo

spec:
  entryPoints:                  # [1]
    - fooudp
  routes:                       # [2]
  - services:                   # [3]
    - name: foo                 # [4]
      port: 8080                # [5]
      weight: 10                # [6]
      nativeLB: true            # [7]
      nodePortLB: true          # [8]
```

----------------------------------------

TITLE: Configuring Traefik TCP IPWhiteList in File Provider (TOML)
DESCRIPTION: This TOML configuration demonstrates how to define the `IPWhiteList` TCP middleware using a file provider. The `sourceRange` array specifies the permitted client IP addresses or CIDR blocks for incoming connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/ipwhitelist.md#_snippet_3>

```toml
# Accepts request from defined IP
[tcp.middlewares]
  [tcp.middlewares.test-ipwhitelist.ipWhiteList]
    sourceRange = ["127.0.0.1/32", "192.168.1.7"]
```

----------------------------------------

TITLE: Reference Traefik Service Load Balancer Servers Transport
DESCRIPTION: Allows referencing a ServersTransport resource, which can be defined via the File provider or Kubernetes CRD. This enables advanced transport configurations for the load balancer. See [serverstransport](../http/load-balancing/serverstransport.md) for more information.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/docker.md#_snippet_23>

```yaml
"traefik.http.services.myservice.loadbalancer.serverstransport=foobar@file"
```

----------------------------------------

TITLE: Configuring Traefik TCP IPWhiteList in File Provider (YAML)
DESCRIPTION: This YAML configuration shows how to set up the `IPWhiteList` TCP middleware using a file provider. The `sourceRange` list defines the allowed IP addresses or CIDR ranges, restricting access to specific client IPs.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/ipwhitelist.md#_snippet_4>

```yaml
# Accepts request from defined IP
tcp:
  middlewares:
    test-ipwhitelist:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"
          - "192.168.1.7"
```

----------------------------------------

TITLE: Enabling ReusePort for Traefik EntryPoints
DESCRIPTION: This example demonstrates how to enable the `ReusePort` option for a Traefik entry point, allowing multiple processes to listen on the same TCP/UDP port by utilizing the `SO_REUSEPORT` socket option for load balancing.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/entrypoints.md#_snippet_8>

```yaml
entryPoints:
  web:
    address: ":80"
    reusePort: true
```

```toml
[entryPoints.web]
  address = ":80"
  reusePort = true
```

```bash
--entryPoints.web.address=:80
--entryPoints.web.reusePort=true
```

----------------------------------------

TITLE: Registering Port for TCP Service Load Balancer in Traefik (YAML)
DESCRIPTION: This configuration registers a specific port for a server within a TCP service's load balancer. Traefik will use this port to connect to the backend application.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/consul-catalog.md#_snippet_50>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.server.port=423
```

----------------------------------------

TITLE: Configuring IngressRouteUDP with ExternalName Service (Port on IngressRouteUDP)
DESCRIPTION: This configuration illustrates how to route UDP traffic using IngressRouteUDP to an ExternalName Service where the target port is explicitly defined within the IngressRouteUDP resource. This is useful when the ExternalName Service itself does not specify a port, allowing Traefik to direct traffic to the correct external endpoint.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/udp/ingressrouteudp.md#_snippet_1>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: test.route
  namespace: apps
spec:
  entryPoints:
    - foo
  routes:
  - match: Host(`example.net`)
    kind: Rule
    services:
    - name: external-svc
      port: 80
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-svc
  namespace: apps
spec:
  externalName: external.domain
  type: ExternalName
```

----------------------------------------

TITLE: Enable Traefik File Provider
DESCRIPTION: Configuration to enable the File provider in Traefik's install configuration, specifying the directory where dynamic configuration files are located.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/dynamic-configuration-methods.md#_snippet_0>

```yaml
providers:
  file:
    directory: "/path/to/dynamic/conf"
```

```toml
[providers.file]
  directory = "/path/to/dynamic/conf"
```

----------------------------------------

TITLE: Traefik Transport and UDP Configuration Parameters
DESCRIPTION: Documents key configuration parameters for Traefik's transport layer and UDP handling, including connection keep-alive settings and UDP session timeouts. These parameters control how Traefik manages client connections and idle sessions.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/install-configuration/entrypoints.md#_snippet_13>

```apidoc
transport.keepAliveMaxRequests:
  description: Set the maximum number of requests Traefik can handle before sending a Connection: Close header to the client (for HTTP2, Traefik sends a GOAWAY). Zero means no limit.
  default: 0
transport.keepAliveMaxTime:
  description: Set the maximum duration Traefik can handle requests before sending a Connection: Close header to the client (for HTTP2, Traefik sends a GOAWAY). Zero means no limit.
  default: 0s (seconds)
udp.timeout:
  description: Define how long to wait on an idle session before releasing the related resources. The Timeout value must be greater than zero.
  default: 3s (seconds)
```

----------------------------------------

TITLE: Configure Traefik TCP Service Load Balancer TLS Backend
DESCRIPTION: Determine whether the Traefik TCP service load balancer should use TLS when establishing connections to the backend servers. Setting this to `true` encrypts the communication between Traefik and the service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/docker.md#_snippet_59>

```yaml
- "traefik.tcp.services.mytcpservice.loadbalancer.server.tls=true"
```

----------------------------------------

TITLE: Configure Traefik TCP Service with TLS for Backend Communication
DESCRIPTION: Demonstrates how to enable TLS for communication between Traefik and a backend server within a TCP service load balancer configuration. This ensures secure data transmission for TCP traffic.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/services/index.md#_snippet_45>

```yaml
## Dynamic configuration
tcp:
  services:
    my-service:
      loadBalancer:
        servers:
              - address: "xx.xx.xx.xx:xx"
                tls: true
```

```toml
## Dynamic configuration
[tcp.services]
  [tcp.services.my-service.loadBalancer]
    [[tcp.services.my-service.loadBalancer.servers]]
          address = "xx.xx.xx.xx:xx"
          tls = true
```

----------------------------------------

TITLE: Enable EntryPoint ReusePort
DESCRIPTION: Enable entryPoints from the same or different processes listening on the same TCP/UDP port by utilizing the SO_REUSEPORT socket option. It also allows the kernel to act like a load balancer to distribute incoming connections between entry points. Refer to documentation for more details.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/install-configuration/entrypoints.md#_snippet_7>

```apidoc
reusePort: boolean
  Default: false
  Description: Enable entryPoints from the same or different processes listening on the same TCP/UDP port by utilizing the SO_REUSEPORT socket option. It also allows the kernel to act like a load balancer to distribute incoming connections between entry points. Refer to documentation for more details.
```

----------------------------------------

TITLE: Enabling Traefik File Provider Configuration
DESCRIPTION: This snippet demonstrates how to enable the Traefik file provider. It shows configuration examples for YAML, TOML, and CLI, specifying the directory where dynamic configuration files are located. The `directory` option points to the path containing the configuration files.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/install-configuration/providers/others/file.md#_snippet_0>

```yaml
providers:
  file:
    directory: "/path/to/dynamic/conf"
```

```toml
[providers.file]
  directory = "/path/to/dynamic/conf"
```

```Bash
--providers.file.directory=/path/to/dynamic/conf
```

----------------------------------------

TITLE: Traefik Service Server Instance Configuration Options
DESCRIPTION: Details the configuration options for individual backend server instances within a Traefik service load balancer. These parameters define how Traefik connects to and interacts with each specific server.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/load-balancing/service.md#_snippet_2>

```apidoc
ServerInstanceConfiguration:
  url:
    description: Points to a specific instance.
    required: Yes for File provider, No for Docker provider
  weight:
    description: Allows for weighted load balancing on the servers.
    required: false
  preservePath:
    description: Allows to preserve the URL path.
    required: false
```

----------------------------------------

TITLE: Configuring Proxy Protocol Version for TCP Service Load Balancer in Traefik (YAML)
DESCRIPTION: Specifies the PROXY protocol version to use when communicating with backend servers, allowing the backend to receive client connection information. This example sets the version to 1 for 'mytcpservice'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_53>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1
```

----------------------------------------

TITLE: Configuring Traefik Static EntryPoint and File Provider (YAML)
DESCRIPTION: This YAML snippet demonstrates a static configuration for Traefik, defining an entry point named 'web' listening on port 80. It also enables the file provider, instructing Traefik to load dynamic configurations from a file named 'dynamic.yaml'. This setup is part of a strategy to customize Traefik's HTTP response behavior, such as returning a 503 instead of a 404.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/getting-started/faq.md#_snippet_1>

```yaml
# traefik.yml

entryPoints:
  web:
    address: :80

providers:
  file:
    filename: dynamic.yaml
```

----------------------------------------

TITLE: Configuring IngressRouteUDP with ExternalName Service (Port on Service)
DESCRIPTION: This example demonstrates routing UDP traffic via IngressRouteUDP to an ExternalName Service where the target port is defined directly on the Service resource. Traefik will use the port specified in the Service definition to establish the connection to the external endpoint.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/udp/ingressrouteudp.md#_snippet_2>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: test.route
  namespace: apps
spec:
  entryPoints:
    - foo
  routes:
  - match: Host(`example.net`)
    kind: Rule
    services:
    - name: external-svc
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-svc
  namespace: apps
spec:
  externalName: external.domain
  type: ExternalName
  ports:
    - port: 80
```

----------------------------------------

TITLE: Configuring Traefik File Provider with a Single Filename
DESCRIPTION: This snippet demonstrates how to configure the Traefik file provider to use a single configuration file instead of a directory. The `filename` option specifies the exact path to the dynamic configuration file. Note that `filename` and `directory` options are mutually exclusive, and `directory` is generally recommended.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/providers/file.md#_snippet_2>

```yaml
providers:
  file:
    filename: /path/to/config/dynamic_conf.yml
```

```toml
[providers]
  [providers.file]
    filename = "/path/to/config/dynamic_conf.toml"
```

```Bash
--providers.file.filename=/path/to/config/dynamic_conf.yml
```

----------------------------------------

TITLE: Traefik Weighted Round Robin Load Balancing Configuration
DESCRIPTION: Illustrates how to configure the Weighted Round Robin (WRR) load balancing strategy in Traefik using dynamic configuration. This strategy allows distributing requests to multiple services based on assigned weights, ensuring a proportional distribution of traffic.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/load-balancing/service.md#_snippet_4>

```yaml
## Dynamic configuration
http:
  services:
    app:
      weighted:
        services:
        - name: appv1
          weight: 3
        - name: appv2
          weight: 1

    appv1:
      loadBalancer:
        servers:
        - url: "http://private-ip-server-1/"

    appv2:
      loadBalancer:
        servers:
        - url: "http://private-ip-server-2/"
```

```toml
## Dynamic configuration
[http.services]
  [http.services.app]
    [[http.services.app.weighted.services]]
      name = "appv1"
      weight = 3
    [[http.services.app.weighted.services]]
      name = "appv2"
      weight = 1

  [http.services.appv1]
    [http.services.appv1.loadBalancer]
      [[http.services.appv1.loadBalancer.servers]]
        url = "http://private-ip-server-1/"

  [http.services.appv2]
    [http.services.appv2.loadBalancer]
      [[http.services.appv2.loadBalancer.servers]]
        url = "http://private-ip-server-2/"
```

----------------------------------------

TITLE: Traefik v2: Configure Basic Auth with Router, Middleware, and Service
DESCRIPTION: Illustrates how to achieve basic authentication and load balancing using Traefik v2's new concepts: routers, middlewares, and services. This snippet provides examples for Docker & Swarm labels, Kubernetes IngressRoute, and File (YAML/TOML) configurations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/migration/v1-to-v2.md#_snippet_1>

```yaml
labels:
  - "traefik.http.routers.router0.rule=Host(`test.localhost`) && PathPrefix(`/test`)"
  - "traefik.http.routers.router0.middlewares=auth"
  - "traefik.http.middlewares.auth.basicauth.users=test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/,test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basicauth
  namespace: foo

spec:
  basicAuth:
    users:
      - test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
      - test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroutebar

spec:
  entryPoints:
    - http
  routes:
  - match: Host(`test.localhost`) && PathPrefix(`/test`)
    kind: Rule
    services:
    - name: server0
      port: 80
    - name: server1
      port: 80
    middlewares:
    - name: basicauth
      namespace: foo
```

```yaml
http:
  routers:
    router0:
      rule: "Host(`test.localhost`) && PathPrefix(`/test`)"
      service: my-service
      middlewares:
        - auth

  services:
    my-service:
      loadBalancer:
        servers:
          - url: http://10.10.10.1:80
          - url: http://10.10.10.2:80

  middlewares:
    auth:
      basicAuth:
        users:
          - "test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
          - "test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0"
```

```toml
[http.routers]
  [http.routers.router0]
    rule = "Host(`test.localhost`) && PathPrefix(`/test`)"
    middlewares = ["auth"]
    service = "my-service"

[http.services]
  [[http.services.my-service.loadBalancer.servers]]
    url = "http://10.10.10.1:80"
```

----------------------------------------

TITLE: APIDOC: Register UDP Service Load Balancer Port Label
DESCRIPTION: Documentation for the `traefik.udp.services.<service_name>.loadbalancer.server.port` label, used to register the application port for a UDP service's load balancer.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/docker.md#_snippet_65>

```apidoc
Label: traefik.udp.services.<service_name>.loadbalancer.server.port
Purpose: Registers a port of the application for the UDP service's load balancer.
```

```yaml
"traefik.udp.services.myudpservice.loadbalancer.server.port=423"
```

----------------------------------------

TITLE: Configuring PROXY Protocol Version for TCP Service in Traefik (YAML)
DESCRIPTION: This configuration specifies the version of the PROXY protocol to be used by the TCP service's load balancer. The PROXY protocol allows passing client connection information to the backend.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/consul-catalog.md#_snippet_52>

```yaml
traefik.tcp.services.mytcpservice.loadbalancer.proxyprotocol.version=1
```

----------------------------------------

TITLE: Traefik Kubernetes Ingress Provider Configuration Parameters
DESCRIPTION: Detailed documentation for various configuration parameters available for the Traefik Kubernetes Ingress provider, including options for load balancing, cluster scope resource discovery, and strict prefix matching.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/install-configuration/providers/kubernetes/kubernetes-ingress.md#_snippet_11>

```apidoc
providers.kubernetesIngress.nativeLBByDefault:
  Description: Allow using the Kubernetes Service load balancing between the pods instead of the one provided by Traefik for every Ingress by default. It can be overridden in the ServerTransport.
  Default: false
  Required: No
providers.kubernetesIngress.disableClusterScopeResources:
  Description: Prevent from discovering cluster scope resources (IngressClass and Nodes). By doing so, it alleviates the requirement of giving Traefik the rights to look up for cluster resources. Furthermore, Traefik will not handle Ingresses with IngressClass references, therefore such Ingresses will be ignored (please note that annotations are not affected by this option). This will also prevent from using the NodePortLB options on services.
  Default: false
  Required: No
providers.kubernetesIngress.strictPrefixMatching:
  Description: Make prefix matching strictly comply with the Kubernetes Ingress specification (path-element-wise matching instead of character-by-character string matching). For example, a PathPrefix of /foo will match /foo, /foo/, and /foo/bar but not /foobar.
  Default: false
  Required: No
```

----------------------------------------

TITLE: Configure Traefik IngressRouteTCP with NativeLB
DESCRIPTION: This example demonstrates how to configure an IngressRouteTCP to use Kubernetes Service clusterIPs directly for load balancing, rather than individual pod IPs. Setting `nativeLB: true` in the service definition within the IngressRouteTCP spec reduces the load balancer's overhead by leveraging Kubernetes' native service discovery.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kubernetes-crd.md#_snippet_39>

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: test.route
  namespace: default

spec:
  entryPoints:
    - foo

  routes:
  - match: HostSNI(`*`)
    services:
    - name: svc
      port: 80
      # Here, nativeLB instructs to build the servers load balancer with the Kubernetes Service clusterIP only.
      nativeLB: true

---
apiVersion: v1
kind: Service
metadata:
  name: svc
  namespace: default
spec:
  type: ClusterIP
  ...
```

----------------------------------------

TITLE: Register Traefik UDP Service Load Balancer Port
DESCRIPTION: Register the target port of the application instance for a Traefik UDP service's load balancer. This tells Traefik which port on the backend server to send UDP traffic to.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/docker.md#_snippet_65>

```yaml
- "traefik.udp.services.myudpservice.loadbalancer.server.port=423"
```

----------------------------------------

TITLE: Limiting InFlight Connections - Traefik File Configuration - TOML
DESCRIPTION: This snippet illustrates configuring the Traefik InFlightConn middleware using a static TOML file. It defines the `inFlightConn` amount for the `test-inflightconn` TCP middleware to 10, limiting the number of simultaneous connections. This provides an alternative file-based configuration format for Traefik.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/inflightconn.md#_snippet_4>

```toml
# Limiting to 10 simultaneous connections
[tcp.middlewares]
  [tcp.middlewares.test-inflightconn.inFlightConn]
    amount = 10
```
