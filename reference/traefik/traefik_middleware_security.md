# Traefik Security Hardening

TITLE: Configure Rate Limiting Middleware
DESCRIPTION: Provides a comprehensive overview of the `rateLimit` middleware configuration. This includes settings for average and burst rates, period, and detailed Redis backend configuration for distributed rate limiting, along with source criteria.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_18>

```apidoc
traefik/http/middlewares/<middleware_instance_name>/rateLimit/average: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/burst: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/period: 42s
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/db: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/dialTimeout: 42s
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/endpoints/0: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/endpoints/1: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/maxActiveConns: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/minIdleConns: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/password: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/poolSize: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/readTimeout: 42s
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/tls/ca: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/tls/cert: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/tls/insecureSkipVerify: true
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/tls/key: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/username: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/redis/writeTimeout: 42s
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/ipStrategy/depth: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/ipStrategy/excludedIPs/0: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/ipStrategy/excludedIPs/1: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/ipStrategy/ipv6Subnet: 42
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/requestHeaderName: foobar
traefik/http/middlewares/<middleware_instance_name>/rateLimit/sourceCriterion/requestHost: true
```

----------------------------------------

TITLE: Configuring Request Host Source Criterion for Traefik Rate Limit Middleware
DESCRIPTION: This configuration enables the `requestHost` as a source criterion for Traefik's rate limit middleware. When set to `true`, incoming requests will be grouped for rate limiting based on their host header. This allows for rate limiting policies to be applied per host.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_16>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.requesthost=true"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    sourceCriterion:
      requestHost: true
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.requesthost=true"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        sourceCriterion:
          requestHost: true
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.sourceCriterion]
      requestHost = true
```

----------------------------------------

TITLE: Configuring IPv6 Subnet IP Strategy for Traefik Rate Limit Middleware
DESCRIPTION: This configuration applies the `ipv6Subnet` strategy to Traefik's rate limit middleware. When an IPv6 address is selected, it's transformed into the first IP of its subnet, which is useful for grouping addresses and preventing rate limit bypass. This strategy is effective with `Depth` and `RemoteAddr` strategies and accepts subnet values between 0-128.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_14>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.ipv6Subnet=64"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  ratelimit:
    sourceCriterion:
      ipStrategy:
        ipv6Subnet: 64
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.ipv6Subnet=64"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      ratelimit:
        sourceCriterion:
          ipStrategy:
            ipv6Subnet: 64
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.ratelimit]
    [http.middlewares.test-ratelimit.ratelimit.sourceCriterion.ipStrategy]
      ipv6Subnet = 64
```

----------------------------------------

TITLE: Configuring Redis Endpoints for Distributed Traefik Rate Limit Middleware
DESCRIPTION: This configuration specifies the Redis endpoints for distributed rate limiting in Traefik. By setting this, Traefik uses Redis to store rate limit tokens, enabling rate limiting across multiple Traefik instances. The `endpoints` parameter is required and defaults to '127.0.0.1:6379' if not explicitly provided.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_17>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.endpoints=127.0.0.1:6379"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      endpoints:
        - "127.0.0.1:6379"
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.endpoints=127.0.0.1:6379"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          endpoints:
            - "127.0.0.1:6379"
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      endpoints = ["127.0.0.1:6379"]
```

----------------------------------------

TITLE: Disabling Redis TLS Certificate Verification for Traefik Rate Limit Middleware
DESCRIPTION: This configuration option, `insecureSkipVerify`, when set to `true`, instructs Traefik to bypass the verification of the Redis server's TLS certificate. This can be useful in development or specific environments where certificate validation is not feasible or desired, but it significantly reduces security and should be used with caution. The default value is `false`.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_24>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.insecureSkipVerify=true"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      tls:
        insecureSkipVerify: true
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.insecureSkipVerify=true"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          tls:
            insecureSkipVerify: true
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      [http.middlewares.test-ratelimit.rateLimit.redis.tls]
        insecureSkipVerify = true
```

----------------------------------------

TITLE: Configuring Traefik Rate Limit IP Strategy Depth (Docker/Swarm YAML)
DESCRIPTION: This snippet demonstrates how to configure the `ipStrategy.depth` for a Traefik rate limit middleware using Docker or Swarm labels. It sets the depth to `2`, meaning Traefik will use the second IP from the right in the `X-Forwarded-For` header as the client IP for rate limiting. This configuration applies to a middleware named `test-ratelimit`.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_4>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.depth=2"
```

----------------------------------------

TITLE: Limiting InFlight Connections - Traefik Kubernetes - YAML
DESCRIPTION: This snippet defines a Traefik `MiddlewareTCP` resource in Kubernetes to limit simultaneous connections. It creates a middleware named `test-inflightconn` and configures its `inFlightConn.amount` to 10, ensuring that only 10 concurrent TCP connections are allowed. This is crucial for managing load on services within a Kubernetes cluster.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/inflightconn.md#_snippet_1>

```yaml
apiVersion: traefik.io/v1alpha1
kind: MiddlewareTCP
metadata:
  name: test-inflightconn
spec:
  inFlightConn:
    amount: 10
```

----------------------------------------

TITLE: Configuring InFlightReq Middleware in Traefik (TOML)
DESCRIPTION: This TOML configuration snippet shows how to define the `inFlightReq` middleware in Traefik. It limits the number of simultaneous requests to 10 for the `test-inflightreq` middleware, helping to manage server load. The `amount` key within the `inFlightReq` section controls this limit.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/inflightreq.md#_snippet_1>

```toml
# Limiting to 10 simultaneous connections
[http.middlewares]
  [http.middlewares.test-inflightreq.inFlightReq]
    amount = 10
```

----------------------------------------

TITLE: Traefik HTTP Middleware: Circuit Breaker Configuration
DESCRIPTION: Configures the CircuitBreaker middleware to protect backend services from overload by stopping requests when a certain failure threshold is met.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_4>

```apidoc
CircuitBreaker:
  checkPeriod: duration (The period to check the circuit's health. Example: '42s')
  expression: string (The expression to evaluate for circuit breaking. Example: 'foobar')
  fallbackDuration: duration (The duration to wait before attempting to close the circuit. Example: '42s')
  recoveryDuration: duration (The duration to wait before attempting to recover the circuit. Example: '42s')
  responseCode: integer (The HTTP status code to return when the circuit is open. Example: '42')
```

----------------------------------------

TITLE: Configuring Redis TLS Certificate for Traefik Rate Limit Middleware
DESCRIPTION: This configuration snippet specifies the path to the public certificate (`cert`) required for establishing a secure TLS connection to Redis. It is a prerequisite for enabling TLS and must be used in conjunction with the `key` option. The examples demonstrate how to set this path using labels for Docker/Swarm and Consul Catalog, or directly within Kubernetes Middleware and Secret resources, and file-based configurations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_22>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.cert=path/to/foo.cert"
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.key=path/to/foo.key"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
   name: test-ratelimit
spec:
   rateLimit:
      # ...
      redis:
         tls:
           certSecret: mytlscert

---
apiVersion: v1
kind: Secret
metadata:
   name: mytlscert
   namespace: default

data:
   tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0=
   tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCi0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0=
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.cert=path/to/foo.cert"
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.key=path/to/foo.key"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        redis:
          tls:
            cert: path/to/foo.cert
            key: path/to/foo.key
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      [http.middlewares.test-ratelimit.rateLimit.redis.tls]
        cert = "path/to/foo.cert"
        key = "path/to/foo.key"
```

----------------------------------------

TITLE: Configuring `excludedIPs` for Rate Limiting in File (YAML)
DESCRIPTION: This YAML configuration demonstrates how to define a Traefik rate limit middleware in a static configuration file. The `excludedIPs` list within the `ipStrategy` specifies the IP addresses or CIDR ranges to be excluded from the rate limiting source criterion.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_12>

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        sourceCriterion:
          ipStrategy:
            excludedIPs:
              - "127.0.0.1/32"
              - "192.168.1.7"
```

----------------------------------------

TITLE: Limiting In-Flight Requests with Traefik on Docker & Swarm
DESCRIPTION: This snippet demonstrates how to configure the Traefik InFlightReq middleware using Docker and Swarm labels to limit simultaneous requests to 10. This prevents services from being overwhelmed by high load.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/inflightreq.md#_snippet_0>

```yaml
labels:
  - "traefik.http.middlewares.test-inflightreq.inflightreq.amount=10"
```

----------------------------------------

TITLE: Limiting InFlight Connections - Traefik Docker/Swarm - YAML
DESCRIPTION: This snippet configures the Traefik InFlightConn middleware for Docker and Swarm environments using labels. It sets the maximum number of simultaneous TCP connections to 10 for the `test-inflightconn` middleware. This helps prevent service overload by restricting concurrent connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/inflightconn.md#_snippet_0>

```yaml
labels:
  - "traefik.tcp.middlewares.test-inflightconn.inflightconn.amount=10"
```

----------------------------------------

TITLE: Configuring `excludedIPs` for Rate Limiting in Kubernetes (YAML)
DESCRIPTION: This Kubernetes YAML manifest defines a Traefik Middleware resource to configure rate limiting. The `excludedIPs` field within the `ipStrategy` specifies a list of IP addresses or CIDR ranges that Traefik should ignore when identifying the client IP for rate limiting purposes.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_10>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    sourceCriterion:
      ipStrategy:
        excludedIPs:
        - 127.0.0.1/32
        - 192.168.1.7
```

----------------------------------------

TITLE: Configuring Redis TLS Private Key for Traefik Rate Limit Middleware
DESCRIPTION: This configuration snippet specifies the path to the private key (`key`) necessary for establishing a secure TLS connection to Redis. It is mandatory when the `cert` option is provided, ensuring mutual authentication. The examples illustrate how to define this path using labels for Docker/Swarm and Consul Catalog, or within Kubernetes Middleware and Secret resources, and file-based configurations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_23>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.cert=path/to/foo.cert"
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.key=path/to/foo.key"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
   name: test-ratelimit
spec:
   rateLimit:
      # ...
      redis:
         tls:
            certSecret: mytlscert

---
apiVersion: v1
kind: Secret
metadata:
   name: mytlscert
   namespace: default

data:
   tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0=
   tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCi0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0=
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.cert=path/to/foo.cert"
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.tls.key=path/to/foo.key"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        redis:
          tls:
            cert: path/to/foo.cert
            key: path/to/foo.key
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      [http.middlewares.test-ratelimit.rateLimit.redis.tls]
        cert = "path/to/foo.cert"
        key = "path/to/foo.key"
```

----------------------------------------

TITLE: Limiting InFlight Connections - Traefik Consul Catalog - YAML
DESCRIPTION: This snippet demonstrates configuring the Traefik InFlightConn middleware via Consul Catalog. It sets the `traefik.tcp.middlewares.test-inflightconn.inflightconn.amount` to 10, limiting the number of simultaneous TCP connections to 10 for the specified middleware. This method integrates Traefik's dynamic configuration with Consul.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/inflightconn.md#_snippet_2>

```yaml
# Limiting to 10 simultaneous connections
- "traefik.tcp.middlewares.test-inflightconn.inflightconn.amount=10"
```

----------------------------------------

TITLE: Configuring InFlightConn Middleware via Traefik Tags (JSON)
DESCRIPTION: This snippet demonstrates configuring the `inFlightConn` TCP middleware using Traefik tags within a JSON configuration. It specifies that the `test-inflightconn` middleware should limit simultaneous connections to 10.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/inflightconn.md#_snippet_3>

LANGUAGE: json
CODE:

```
// Limiting to 10 simultaneous connections
{
  //..
  "Tags" : [
    "traefik.tcp.middlewares.test-inflightconn.inflightconn.amount=10"
  ]
}
```

----------------------------------------

TITLE: Configuring Traefik Rate Limit IP Strategy Depth (Kubernetes YAML)
DESCRIPTION: This Kubernetes YAML manifest defines a Traefik Middleware resource named `test-ratelimit`. It configures the `rateLimit` middleware to use an `ipStrategy` with a `depth` of `2`. This setting instructs Traefik to identify the client IP for rate limiting by selecting the second IP from the right within the `X-Forwarded-For` header.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_5>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    sourceCriterion:
      ipStrategy:
        depth: 2
```

----------------------------------------

TITLE: Defining StripPrefix Middleware in Kubernetes IngressRoute (YAML)
DESCRIPTION: This example illustrates how to define a `stripPrefix` middleware as a Kubernetes `Middleware` resource and then reference it within an `IngressRoute`. The middleware `stripprefix` is configured to remove `/stripit` from incoming request paths.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/overview.md#_snippet_1>

```yaml
# As a Kubernetes Traefik IngressRoute
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: stripprefix
spec:
  stripPrefix:
    prefixes:
      - /stripit

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute
spec:
# more fields...
  routes:
    # more fields...
    middlewares:
      - name: stripprefix
```

----------------------------------------

TITLE: Configuring Traefik Chain Middleware with YAML
DESCRIPTION: This YAML configuration demonstrates how to define a `chain` middleware named `secured` that combines `https-only`, `known-ips`, and `auth-users` middlewares. It also shows the definitions for `basicAuth`, `redirectScheme`, and `ipAllowList` middlewares, and how to apply the `secured` chain to a router.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/chain.md#_snippet_0>

```yaml
# ...
http:
  routers:
    router1:
      service: service1
      middlewares:
        - secured
      rule: "Host(`mydomain`)"

  middlewares:
    secured:
      chain:
        middlewares:
          - https-only
          - known-ips
          - auth-users

    auth-users:
      basicAuth:
        users:
          - "test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"

    https-only:
      redirectScheme:
        scheme: https

    known-ips:
      ipAllowList:
        sourceRange:
          - "192.168.1.7"
          - "127.0.0.1/32"

  services:
    service1:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:80"
```

----------------------------------------

TITLE: Configuring Traefik Rate Limit IP Strategy Depth (Consul Catalog YAML)
DESCRIPTION: This YAML snippet shows how to configure the `ipStrategy.depth` for a Traefik rate limit middleware when using Consul Catalog. It sets the `depth` parameter to `2` for the `test-ratelimit` middleware, instructing Traefik to use the second IP from the right in the `X-Forwarded-For` header as the client IP for rate limiting purposes.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_6>

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.depth=2"
```

----------------------------------------

TITLE: Configure In-Flight Request Limiting Middleware
DESCRIPTION: Details the configuration options for the `inFlightReq` middleware, which limits the number of concurrent requests. It includes settings for IP-based source criteria, request header names, and request hosts.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_15>

```apidoc
traefik/http/middlewares/<middleware_instance_name>/inFlightReq/sourceCriterion/ipStrategy/excludedIPs/1: foobar
traefik/http/middlewares/<middleware_instance_name>/inFlightReq/sourceCriterion/ipStrategy/ipv6Subnet: 42
traefik/http/middlewares/<middleware_instance_name>/inFlightReq/sourceCriterion/requestHeaderName: foobar
traefik/http/middlewares/<middleware_instance_name>/inFlightReq/sourceCriterion/requestHost: true
```

----------------------------------------

TITLE: Limiting In-Flight Requests with Traefik on Kubernetes
DESCRIPTION: This Kubernetes YAML snippet defines a Traefik Middleware resource to limit the number of simultaneous in-flight requests to 10. It's applied to prevent service overload in a Kubernetes environment.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/inflightreq.md#_snippet_1>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-inflightreq
spec:
  inFlightReq:
    amount: 10
```

----------------------------------------

TITLE: Defining InFlightReq Middleware in Kubernetes with Traefik CRD (YAML)
DESCRIPTION: This Kubernetes YAML manifest defines a Traefik `Middleware` Custom Resource for `inFlightReq`. It configures the `test-inflightreq` middleware to limit simultaneous requests to 10, integrating the in-flight request limiting directly into a Kubernetes cluster using Traefik's Custom Resource Definitions.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/inflightreq.md#_snippet_4>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-inflightreq
spec:
  inFlightReq:
    amount: 10
```

----------------------------------------

TITLE: Configuring `excludedIPs` for Rate Limiting in Docker & Swarm (YAML)
DESCRIPTION: This snippet demonstrates how to configure the `excludedIPs` option for a Traefik rate limit middleware using Docker labels. It specifies a list of IP addresses or CIDR ranges that should be excluded from the IP strategy's consideration when determining the client IP for rate limiting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_9>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.excludedips=127.0.0.1/32, 192.168.1.7"
```

----------------------------------------

TITLE: Configuring Traefik Buffering with Kubernetes Middleware
DESCRIPTION: This Kubernetes YAML manifest defines a Traefik `Middleware` resource named 'limit'. It configures the buffering middleware to set the `maxRequestBodyBytes` to 2MB (2,000,000 bytes), ensuring that requests exceeding this size are rejected within a Kubernetes environment.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/buffering.md#_snippet_4>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: limit
spec:
  buffering:
    maxRequestBodyBytes: 2000000
```

----------------------------------------

TITLE: Limiting InFlight Connections - Traefik File Configuration - YAML
DESCRIPTION: This snippet shows how to configure the Traefik InFlightConn middleware using a static YAML file. It defines a TCP middleware named `test-inflightconn` and sets its `inFlightConn.amount` to 10, restricting simultaneous connections to 10. This is a common approach for static Traefik configurations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/inflightconn.md#_snippet_3>

```yaml
# Limiting to 10 simultaneous connections.
tcp:
  middlewares:
    test-inflightconn:
      inFlightConn:
        amount: 10
```

----------------------------------------

TITLE: Configuring `excludedIPs` for Rate Limiting in File (TOML)
DESCRIPTION: This TOML configuration illustrates how to set up a Traefik rate limit middleware in a static configuration file. The `excludedIPs` array within the `ipStrategy` defines the IP addresses or CIDR ranges that Traefik should exclude when determining the client IP for rate limiting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_13>

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.sourceCriterion.ipStrategy]
      excludedIPs = ["127.0.0.1/32", "192.168.1.7"]
```

----------------------------------------

TITLE: Configuring Basic Security Headers with Traefik (YAML)
DESCRIPTION: This snippet demonstrates how to configure basic security headers like `frameDeny` and `browserXssFilter` using Traefik's structured YAML configuration. It defines a middleware named `testHeader` to apply these security features, preventing clickjacking and enabling browser XSS protection.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/headers.md#_snippet_2>

```yaml
http:
  middlewares:
    testHeader:
      headers:
        frameDeny: true
        browserXssFilter: true
```

----------------------------------------

TITLE: Configuring Security Headers with Traefik Middleware
DESCRIPTION: This configuration shows how to enable common security-related headers like `frameDeny` (X-Frame-Options) and `browserXssFilter` (X-XSS-Protection) using the Traefik Headers middleware. These headers enhance application security by mitigating common web vulnerabilities.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/headers.md#_snippet_2>

LANGUAGE: YAML (Docker & Swarm)
CODE:

```
labels:
  - "traefik.http.middlewares.testHeader.headers.framedeny=true"
  - "traefik.http.middlewares.testHeader.headers.browserxssfilter=true"
```

LANGUAGE: YAML (Kubernetes)
CODE:

```
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-header
spec:
  headers:
    frameDeny: true
    browserXssFilter: true
```

LANGUAGE: YAML (Consul Catalog)
CODE:

```
- "traefik.http.middlewares.testheader.headers.framedeny=true"
- "traefik.http.middlewares.testheader.headers.browserxssfilter=true"
```

LANGUAGE: YAML (File)
CODE:

```
http:
  middlewares:
    testHeader:
      headers:
        frameDeny: true
        browserXssFilter: true
```

LANGUAGE: TOML (File)
CODE:

```
[http.middlewares]
  [http.middlewares.testHeader.headers]
    frameDeny = true
    browserXssFilter = true
```

----------------------------------------

TITLE: Defining Traefik Middleware in Kubernetes IngressRoute (YAML)
DESCRIPTION: This YAML snippet shows how to define a `stripPrefix` middleware and apply it within a Kubernetes `IngressRoute` resource. It creates a middleware named `stripprefix` that removes `/stripit` from the request path and then references it in the `middlewares` section of an `IngressRoute`. This is used for Kubernetes deployments.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/overview.md#_snippet_1>

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: stripprefix
spec:
  stripPrefix:
    prefixes:
      - /stripit

---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ingressroute
spec:
# more fields...
  routes:
    # more fields...
    middlewares:
      - name: stripprefix
```

----------------------------------------

TITLE: Setting Traefik RateLimit Average Rate
DESCRIPTION: Examples for configuring the `average` parameter of the Traefik RateLimit middleware, which defines the maximum allowed request rate, defaulting to requests per second. A value of `0` disables rate limiting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_1>

```yaml
# 100 reqs/s
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.average=100"
```

```yaml
# 100 reqs/s
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    average: 100
```

```yaml
# 100 reqs/s
- "traefik.http.middlewares.test-ratelimit.ratelimit.average=100"
```

```yaml
# 100 reqs/s
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        average: 100
```

```toml
# 100 reqs/s
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    average = 100
```

----------------------------------------

TITLE: Configuring InFlightConn Middleware in Kubernetes (YAML)
DESCRIPTION: This snippet provides a Kubernetes `MiddlewareTCP` resource definition for the `inFlightConn` middleware. It configures a middleware named `test-inflightconn` to limit the number of simultaneous TCP connections to 10.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/inflightconn.md#_snippet_4>

```yaml
apiVersion: traefik.io/v1alpha1
kind: MiddlewareTCP
metadata:
  name: test-inflightconn
spec:
  inFlightConn:
    amount: 10
```

----------------------------------------

TITLE: Configuring Basic Security Headers with Traefik (Kubernetes)
DESCRIPTION: This snippet shows how to define a Traefik Middleware resource in Kubernetes to configure `frameDeny` and `browserXssFilter` security headers. This approach allows declarative management of security policies directly within a Kubernetes cluster, ensuring consistent application of headers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/headers.md#_snippet_6>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-header
spec:
  headers:
    frameDeny: true
    browserXssFilter: true
```

----------------------------------------

TITLE: Declaring and Referencing HTTP RedirectScheme Middleware in Traefik (YAML)
DESCRIPTION: This snippet demonstrates how to declare an HTTP `redirectscheme` middleware named `my-redirect` to enforce HTTPS, and then reference it from an HTTP router named `my-service`. The middleware is defined with a scheme of `https`, ensuring all traffic is redirected to secure connections. This shows a common pattern for applying middleware to routers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/consul-catalog.md#_snippet_38>

```yaml
# ...
# Declaring a middleware
traefik.http.middlewares.my-redirect.redirectscheme.scheme=https
# Referencing a middleware
traefik.http.routers.my-service.middlewares=my-redirect
```

----------------------------------------

TITLE: Apply Traefik Middlewares to Kubernetes Ingress Router
DESCRIPTION: This annotation allows you to attach one or more Traefik middlewares to the router. Middlewares can modify requests or responses, enabling features like authentication, rate limiting, or header manipulation. Consult the Traefik documentation for available middlewares and their configurations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/kubernetes-ingress.md#_snippet_2>

```yaml
traefik.ingress.kubernetes.io/router.middlewares: auth@file,default-prefix@kubernetescrd
```

----------------------------------------

TITLE: Configuring Traefik Chain Middleware Across Multiple Providers
DESCRIPTION: This collection of examples demonstrates how to configure a Traefik Chain middleware that combines `AllowList`, `BasicAuth`, and `RedirectScheme` functionalities. Each example shows the configuration using a different Traefik provider: Docker & Swarm labels, Kubernetes resources, Consul Catalog, and static configuration files (YAML and TOML). The chain middleware named `secured` groups `https-only`, `known-ips`, and `auth-users` for reusability.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/chain.md#_snippet_0>

```yaml
labels:
  - "traefik.http.routers.router1.service=service1"
  - "traefik.http.routers.router1.middlewares=secured"
  - "traefik.http.routers.router1.rule=Host(`mydomain`)"
  - "traefik.http.middlewares.secured.chain.middlewares=https-only,known-ips,auth-users"
  - "traefik.http.middlewares.auth-users.basicauth.users=test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
  - "traefik.http.middlewares.https-only.redirectscheme.scheme=https"
  - "traefik.http.middlewares.known-ips.ipallowlist.sourceRange=192.168.1.7,127.0.0.1/32"
  - "traefik.http.services.service1.loadbalancer.server.port=80"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: test
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`mydomain`)
      kind: Rule
      services:
        - name: whoami
          port: 80
      middlewares:
        - name: secured
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: secured
spec:
  chain:
    middlewares:
    - name: https-only
    - name: known-ips
    - name: auth-users
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: auth-users
spec:
  basicAuth:
    users:
    - test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-only
spec:
  redirectScheme:
    scheme: https
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: known-ips
spec:
  ipAllowList:
    sourceRange:
    - 192.168.1.7
    - 127.0.0.1/32
```

```yaml
- "traefik.http.routers.router1.service=service1"
- "traefik.http.routers.router1.middlewares=secured"
- "traefik.http.routers.router1.rule=Host(`mydomain`)"
- "traefik.http.middlewares.secured.chain.middlewares=https-only,known-ips,auth-users"
- "traefik.http.middlewares.auth-users.basicauth.users=test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
- "traefik.http.middlewares.https-only.redirectscheme.scheme=https"
- "traefik.http.middlewares.known-ips.ipallowlist.sourceRange=192.168.1.7,127.0.0.1/32"
- "traefik.http.services.service1.loadbalancer.server.port=80"
```

```yaml
# ...
http:
  routers:
    router1:
      service: service1
      middlewares:
        - secured
      rule: "Host(`mydomain`)"

  middlewares:
    secured:
      chain:
        middlewares:
          - https-only
          - known-ips
          - auth-users

    auth-users:
      basicAuth:
        users:
          - "test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"

    https-only:
      redirectScheme:
        scheme: https

    known-ips:
      ipAllowList:
        sourceRange:
          - "192.168.1.7"
          - "127.0.0.1/32"

  services:
    service1:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:80"
```

```toml
# ...
[http.routers]
  [http.routers.router1]
    service = "service1"
    middlewares = ["secured"]
    rule = "Host(`mydomain`)"

[http.middlewares]
  [http.middlewares.secured.chain]
    middlewares = ["https-only", "known-ips", "auth-users"]

  [http.middlewares.auth-users.basicAuth]
    users = ["test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"]

  [http.middlewares.https-only.redirectScheme]
    scheme = "https"

  [http.middlewares.known-ips.ipAllowList]
    sourceRange = ["192.168.1.7", "127.0.0.1/32"]

[http.services]
  [http.services.service1]
    [http.services.service1.loadBalancer]
      [[http.services.service1.loadBalancer.servers]]
        url = "http://127.0.0.1:80"
```

----------------------------------------

TITLE: Configuring Redis Maximum Active Connections for Traefik Rate Limit Middleware
DESCRIPTION: Sets the upper limit on the total number of connections the Redis pool can allocate concurrently. This prevents resource exhaustion by capping the number of active connections. A value of zero means there is no limit on the number of active connections.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_27>

```yaml
labels:
    - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.maxActiveConns=42"
```

```yaml
apiVersion: traefik.io/v1alpha
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      maxActiveConns: 42
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.maxActiveConns=42"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          maxActiveConns: 42
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      maxActiveConns = 42
```

----------------------------------------

TITLE: Configuring Redis Pool Size for Traefik Rate Limit Middleware
DESCRIPTION: Defines the base number of socket connections for the Redis pool. If there are not enough connections, new ones will be allocated beyond this size, which can be limited by `redis.maxActiveConns`. A value of zero means 10 connections per available CPU core as reported by runtime.GOMAXPROCS.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_25>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.poolSize=42"
```

```yaml
apiVersion: traefik.io/v1alpha
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      poolSize: 42
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.poolSize=42"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          poolSize: 42
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      poolSize = 42
```

----------------------------------------

TITLE: Configuring Traefik Chain Middleware in Kubernetes (YAML)
DESCRIPTION: This Kubernetes YAML configuration defines an `IngressRoute` that uses a `secured` middleware chain. It also defines the individual `Middleware` resources for `secured` (the chain itself), `auth-users` (basicAuth), `https-only` (redirectScheme), and `known-ips` (ipAllowList), demonstrating how to deploy a chained middleware setup in a Kubernetes environment.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/chain.md#_snippet_4>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: test
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`mydomain`)
      kind: Rule
      services:
        - name: whoami
          port: 80
      middlewares:
        - name: secured
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: secured
spec:
  chain:
    middlewares:
    - name: https-only
    - name: known-ips
    - name: auth-users
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: auth-users
spec:
  basicAuth:
    users:
    - test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-only
spec:
  redirectScheme:
    scheme: https
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: known-ips
spec:
  ipAllowList:
    sourceRange:
    - 192.168.1.7
    - 127.0.0.1/32
```

----------------------------------------

TITLE: Traefik HTTP Headers Middleware Configuration
DESCRIPTION: Configuration options for the Traefik HTTP Headers middleware, allowing fine-grained control over HTTP response and request headers for security, caching, and other purposes. This includes settings for CORS, security headers like CSP and HSTS, and custom headers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_11>

```apidoc
traefik/http/middlewares/Middleware12/headers/accessControlAllowCredentials | true
traefik/http/middlewares/Middleware12/headers/accessControlAllowHeaders/0 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowHeaders/1 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowMethods/0 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowMethods/1 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowOriginList/0 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowOriginList/1 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowOriginListRegex/0 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlAllowOriginListRegex/1 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlExposeHeaders/0 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlExposeHeaders/1 | foobar
traefik/http/middlewares/Middleware12/headers/accessControlMaxAge | 42
traefik/http/middlewares/Middleware12/headers/addVaryHeader | true
traefik/http/middlewares/Middleware12/headers/allowedHosts/0 | foobar
traefik/http/middlewares/Middleware12/headers/allowedHosts/1 | foobar
traefik/http/middlewares/Middleware12/headers/browserXssFilter | true
traefik/http/middlewares/Middleware12/headers/contentSecurityPolicy | foobar
traefik/http/middlewares/Middleware12/headers/contentSecurityPolicyReportOnly | foobar
traefik/http/middlewares/Middleware12/headers/contentTypeNosniff | true
traefik/http/middlewares/Middleware12/headers/customBrowserXSSValue | foobar
traefik/http/middlewares/Middleware12/headers/customFrameOptionsValue | foobar
traefik/http/middlewares/Middleware12/headers/customRequestHeaders/name0 | foobar
traefik/http/middlewares/Middleware12/headers/customRequestHeaders/name1 | foobar
traefik/http/middlewares/Middleware12/headers/customResponseHeaders/name0 | foobar
traefik/http/middlewares/Middleware12/headers/customResponseHeaders/name1 | foobar
traefik/http/middlewares/Middleware12/headers/featurePolicy | foobar
traefik/http/middlewares/Middleware12/headers/forceSTSHeader | true
traefik/http/middlewares/Middleware12/headers/frameDeny | true
traefik/http/middlewares/Middleware12/headers/hostsProxyHeaders/0 | foobar
traefik/http/middlewares/Middleware12/headers/hostsProxyHeaders/1 | foobar
traefik/http/middlewares/Middleware12/headers/isDevelopment | true
traefik/http/middlewares/Middleware12/headers/permissionsPolicy | foobar
traefik/http/middlewares/Middleware12/headers/publicKey | foobar
traefik/http/middlewares/Middleware12/headers/referrerPolicy | foobar
traefik/http/middlewares/Middleware12/headers/sslForceHost | true
traefik/http/middlewares/Middleware12/headers/sslHost | foobar
traefik/http/middlewares/Middleware12/headers/sslProxyHeaders/name0 | foobar
traefik/http/middlewares/Middleware12/headers/sslProxyHeaders/name1 | foobar
traefik/http/middlewares/Middleware12/headers/sslRedirect | true
traefik/http/middlewares/Middleware12/headers/sslTemporaryRedirect | true
traefik/http/middlewares/Middleware12/headers/stsIncludeSubdomains | true
traefik/http/middlewares/Middleware12/headers/stsPreload | true
traefik/http/middlewares/Middleware12/headers/stsSeconds | 42
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

----------------------------------------

TITLE: Configuring InFlightReq Middleware in Traefik (YAML)
DESCRIPTION: This snippet demonstrates how to configure the `inFlightReq` middleware in Traefik using a structured YAML configuration. It sets a limit of 10 simultaneous in-flight requests for the `test-inflightreq` middleware, preventing the service from being overwhelmed. The `amount` parameter specifies the maximum number of concurrent requests allowed.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/inflightreq.md#_snippet_0>

```yaml
# Limiting to 10 simultaneous connections
http:
  middlewares:
    test-inflightreq:
      inFlightReq:
        amount: 10
```

----------------------------------------

TITLE: Applying InFlightReq Middleware via Traefik Labels (YAML)
DESCRIPTION: This snippet illustrates how to apply the `inFlightReq` middleware configuration using Traefik labels, typically used in container orchestrators like Docker. It sets the `amount` for the `test-inflightreq` middleware to 10, effectively limiting concurrent requests through label-based dynamic configuration.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/inflightreq.md#_snippet_2>

```yaml
labels:
  - "traefik.http.middlewares.test-inflightreq.inflightreq.amount=10"
```

----------------------------------------

TITLE: Traefik HTTP In-Flight Request Middleware Configuration
DESCRIPTION: Configuration options for the Traefik HTTP In-Flight Request middleware, which limits the number of simultaneous requests being processed by a service. It includes settings for the maximum amount of concurrent requests and a source criterion to group requests (e.g., by IP address) for more granular control.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_14>

```apidoc
traefik/http/middlewares/Middleware15/inFlightReq/amount | 42
traefik/http/middlewares/Middleware15/inFlightReq/sourceCriterion/ipStrategy/depth | 42
traefik/http/middlewares/Middleware15/inFlightReq/sourceCriterion/ipStrategy/excludedIPs/0 | foobar
```

----------------------------------------

TITLE: Configuring maxBodySize for ForwardAuth Middleware
DESCRIPTION: Set the `maxBodySize` to limit the body size in bytes. If the body is bigger than this, it returns a 401 (unauthorized). The default is `-1`, which means no limit.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/forwardauth.md#_snippet_35>

```yaml
labels:
  - "traefik.http.middlewares.test-auth.forwardauth.maxBodySize=1000"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-auth
spec:
  forwardAuth:
    address: https://example.com/auth
    forwardBody: true
    maxBodySize: 1000
```

```yaml
- "traefik.http.middlewares.test-auth.forwardauth.maxBodySize=1000"
```

```yaml
http:
  middlewares:
    test-auth:
      forwardAuth:
        address: "https://example.com/auth"
        maxBodySize: 1000
```

----------------------------------------

TITLE: Configuring Traefik Chain Middleware with TOML
DESCRIPTION: This TOML configuration provides an alternative way to define the `secured` chain middleware, combining `https-only`, `known-ips`, and `auth-users`. It includes the TOML definitions for the individual `basicAuth`, `redirectScheme`, and `ipAllowList` middlewares, and their application to a router.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/chain.md#_snippet_1>

```toml
# ...
[http.routers]
  [http.routers.router1]
    service = "service1"
    middlewares = ["secured"]
    rule = "Host(`mydomain`)"

[http.middlewares]
  [http.middlewares.secured.chain]
    middlewares = ["https-only", "known-ips", "auth-users"]

  [http.middlewares.auth-users.basicAuth]
    users = ["test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"]

  [http.middlewares.https-only.redirectScheme]
    scheme = "https"

  [http.middlewares.known-ips.ipAllowList]
    sourceRange = ["192.168.1.7", "127.0.0.1/32"]

[http.services]
  [http.services.service1]
    [http.services.service1.loadBalancer]
      [[http.services.service1.loadBalancer.servers]]
        url = "http://127.0.0.1:80"
```

----------------------------------------

TITLE: Traefik TCP Middleware Configuration
DESCRIPTION: Details the configuration paths for various TCP middlewares in Traefik, such as IP allow lists, IP white lists, and in-flight connection limits. These middlewares can be applied to TCP routers to control traffic flow.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_30>

```apidoc
tcp:
  middlewares:
    TCPMiddleware01:
      ipAllowList:
        sourceRange:
          - foobar
          - foobar
    TCPMiddleware02:
      ipWhiteList:
        sourceRange:
          - foobar
          - foobar
    TCPMiddleware03:
      inFlightConn:
        amount: 42
```

----------------------------------------

TITLE: Limiting In-Flight Requests with Traefik on Consul Catalog
DESCRIPTION: This snippet shows how to configure the Traefik InFlightReq middleware for Consul Catalog, setting the maximum simultaneous requests to 10. This helps manage load for services registered in Consul.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/inflightreq.md#_snippet_2>

```yaml
# Limiting to 10 simultaneous connections
- "traefik.http.middlewares.test-inflightreq.inflightreq.amount=10"
```

----------------------------------------

TITLE: Configuring TCP IPAllowList with Docker & Swarm in Traefik
DESCRIPTION: This snippet demonstrates how to configure the TCP IPAllowList middleware using Docker labels for Traefik. It specifies allowed IP ranges (127.0.0.1/32 and 192.168.1.7) for incoming TCP connections, effectively limiting client access.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/ipallowlist.md#_snippet_0>

```yaml
# Accepts connections from defined IP
labels:
  - "traefik.tcp.middlewares.test-ipallowlist.ipallowlist.sourcerange=127.0.0.1/32, 192.168.1.7"
```

----------------------------------------

TITLE: Configuring Redis Minimum Idle Connections for Traefik Rate Limit Middleware
DESCRIPTION: Specifies the minimum number of idle connections to maintain in the Redis pool, which is beneficial when establishing new connections is slow. A value of zero indicates that idle connections will not be closed, allowing them to persist indefinitely.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_26>

```yaml
labels:
    - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.minIdleConns=42"
```

```yaml
apiVersion: traefik.io/v1alpha
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      minIdleConns: 42
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.minIdleConns=42"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          minIdleConns: 42
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      minIdleConns = 42
```

----------------------------------------

TITLE: Traefik HTTP Middleware: Buffering Configuration
DESCRIPTION: Configures the Buffering middleware to buffer requests and responses. This can be used to protect backend services from slow clients or to handle large payloads.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_2>

```apidoc
Buffering:
  maxRequestBodyBytes: integer (The maximum size of the request body in bytes. Example: '42')
  maxResponseBodyBytes: integer (The maximum size of the response body in bytes. Example: '42')
  memRequestBodyBytes: integer (The maximum size of the request body to keep in memory in bytes. Example: '42')
  memResponseBodyBytes: integer (The maximum size of the response body to keep in memory in bytes. Example: '42')
  retryExpression: string (A retry expression to determine if a request should be retried. Example: 'foobar')
```

----------------------------------------

TITLE: Configuring maxBodySize for ForwardAuth Middleware
DESCRIPTION: Set the `maxBodySize` to limit the body size in bytes. If the body is bigger than this, it returns a 401 (unauthorized). The default is `-1`, which means no limit.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/forwardauth.md#_snippet_36>

```toml
[http.middlewares]
  [http.middlewares.test-auth.forwardAuth]
    address = "https://example.com/auth"
    forwardBody = true
    maxBodySize = 1000
```

----------------------------------------

TITLE: Configuring Redis Dial Timeout for Rate Limit in Kubernetes (YAML)
DESCRIPTION: This snippet shows how to configure the Redis dial timeout for a Traefik rate limit middleware within a Kubernetes `Middleware` resource. The `dialTimeout` field under `spec.rateLimit.redis` sets the connection timeout.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_31>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      dialTimeout: 42s
```

----------------------------------------

TITLE: Configuring RateLimit Middleware via Traefik Labels
DESCRIPTION: This snippet illustrates how to configure the `rateLimit` middleware using Traefik labels, typically for Docker or other orchestrators. It sets the average rate to 100 and the burst capacity to 200 requests.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/ratelimit.md#_snippet_2>

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.test-ratelimit.ratelimit.burst=200"
```

----------------------------------------

TITLE: Limiting In-Flight Requests with Traefik via YAML File
DESCRIPTION: This YAML file configuration demonstrates how to define the Traefik InFlightReq middleware to limit simultaneous requests to 10. It's used for static configuration of Traefik.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/inflightreq.md#_snippet_3>

```yaml
# Limiting to 10 simultaneous connections
http:
  middlewares:
    test-inflightreq:
      inFlightReq:
        amount: 10
```

----------------------------------------

TITLE: Configuring InFlightConn Middleware in Traefik TCP (TOML)
DESCRIPTION: This snippet shows the TOML configuration for the `inFlightConn` TCP middleware in Traefik. It limits the number of simultaneous connections to 10 for the `test-inflightconn` middleware, ensuring services are not overwhelmed.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/inflightconn.md#_snippet_1>

```toml
# Limiting to 10 simultaneous connections
[tcp.middlewares]
  [tcp.middlewares.test-inflightconn.inFlightConn]
    amount = 10
```

----------------------------------------

TITLE: Configuring Traefik RateLimit Middleware
DESCRIPTION: This example demonstrates how to configure the Traefik RateLimit middleware with a specified average request rate and burst capacity across various deployment environments, including Docker, Kubernetes, Consul Catalog, and File providers.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_0>

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.test-ratelimit.ratelimit.burst=200"
```

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    average: 100
    burst: 200
```

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
- "traefik.http.middlewares.test-ratelimit.ratelimit.average=100"
- "traefik.http.middlewares.test-ratelimit.ratelimit.burst=50"
```

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        average: 100
        burst: 200
```

```toml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    average = 100
    burst = 200
```

----------------------------------------

TITLE: Removing Authorization Header Before Forwarding Request
DESCRIPTION: Sets the `removeHeader` option to `true` to strip the `Authorization` header from the request before it is forwarded to the backend service. This enhances security by preventing credentials from being sent unnecessarily to the upstream service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/basicauth.md#_snippet_4>

```yaml
labels:
  - "traefik.http.middlewares.test-auth.basicauth.removeheader=true"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-auth
spec:
  basicAuth:
    removeHeader: true
```

LANGUAGE: JSON
CODE:

```
- "traefik.http.middlewares.test-auth.basicauth.removeheader=true"
```

```yaml
http:
  middlewares:
    test-auth:
      basicAuth:
        removeHeader: true
```

```toml
[http.middlewares]
  [http.middlewares.test-auth.basicAuth]
    removeHeader = true
```

----------------------------------------

TITLE: Configuring Basic Security Headers with Traefik (Labels)
DESCRIPTION: This snippet illustrates how to apply `frameDeny` and `browserXssFilter` security headers using Traefik labels. These labels are typically used in container orchestrators (e.g., Docker, Kubernetes) to dynamically configure middleware, enabling robust security features for services.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/headers.md#_snippet_4>

```yaml
labels:
  - "traefik.http.middlewares.testHeader.headers.framedeny=true"
  - "traefik.http.middlewares.testHeader.headers.browserxssfilter=true"
```

----------------------------------------

TITLE: Configuring `excludedIPs` for Rate Limiting in Consul Catalog (YAML)
DESCRIPTION: This snippet shows how to set the `excludedIPs` for a Traefik rate limit middleware using Consul Catalog. It uses a key-value pair format to define the IP addresses or CIDR ranges that Traefik should exclude from its IP strategy for rate limiting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_11>

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.ipstrategy.excludedips=127.0.0.1/32, 192.168.1.7"
```

----------------------------------------

TITLE: Configuring Request Header Name Source Criterion for Traefik Rate Limit Middleware
DESCRIPTION: This configuration sets the `requestHeaderName` as the source criterion for rate limiting in Traefik. Requests are grouped based on the value of the specified header (e.g., 'username'). If the header is not present in a request, all such requests will be grouped together for rate limiting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_15>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.requestheadername=username"
```

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    sourceCriterion:
      requestHeaderName: username
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.sourcecriterion.requestheadername=username"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        sourceCriterion:
          requestHeaderName: username
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.sourceCriterion]
      requestHeaderName = "username"
```

----------------------------------------

TITLE: Configuring Default HTTP Middlewares for Traefik Entry Points
DESCRIPTION: This configuration demonstrates how to define default HTTP middlewares for a Traefik entry point named 'websecure'. These middlewares, 'auth@file' and 'strip@file', will be prepended to all routers associated with this entry point. This ensures consistent security and request processing across all services exposed via 'websecure'.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/entrypoints.md#_snippet_33>

```yaml
entryPoints:
  websecure:
    address: ':443'
    http:
      middlewares:
        - auth@file
        - strip@file
```

```toml
[entryPoints.websecure]
  address = ":443"

  [entryPoints.websecure.http]
    middlewares = ["auth@file", "strip@file"]
```

LANGUAGE: Bash
CODE:

```
--entryPoints.websecure.address=:443
--entryPoints.websecure.http.middlewares=auth@file,strip@file
```

----------------------------------------

TITLE: Applying MiddlewareTCP to IngressRouteTCP (YAML)
DESCRIPTION: This YAML snippet defines an `IngressRouteTCP` named `ingressroutebar` that routes TCP traffic for `example.com` with a path prefix `/allowlist` to the `whoami` service on port 80. It applies the previously defined `ipallowlist` `MiddlewareTCP` from the `foo` namespace to this route, ensuring that only allowed IPs can access the service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/tcp/middlewaretcp.md#_snippet_1>

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: ingressroutebar

spec:
  entryPoints:
    - web
  routes:
  - match: Host(`example.com`) && PathPrefix(`/allowlist`)
    kind: Rule
    services:
    - name: whoami
      port: 80
    middlewares:
    - name: ipallowlist
      namespace: foo
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

TITLE: Configuring Traefik Buffering with Structured YAML
DESCRIPTION: This YAML snippet configures the Traefik HTTP buffering middleware named 'limit'. It sets the maximum allowed request body size to 2MB (2,000,000 bytes) using the `maxRequestBodyBytes` option, preventing larger requests from being forwarded to services.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/buffering.md#_snippet_0>

```yaml
http:
  middlewares:
    limit:
      buffering:
        maxRequestBodyBytes: 2000000
```

----------------------------------------

TITLE: Configuring RateLimit Middleware in Traefik (TOML)
DESCRIPTION: This snippet shows the TOML configuration for the `rateLimit` middleware in Traefik. It allows an average of 100 requests per second and a burst of 200 requests, defining the rate and burst capacity.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/ratelimit.md#_snippet_1>

```toml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    average = 100
    burst = 200
```

----------------------------------------

TITLE: Configuring Redis Dial Timeout for Rate Limit in File (YAML)
DESCRIPTION: This snippet demonstrates how to define the Redis dial timeout for a Traefik rate limit middleware in a static YAML configuration file. The `dialTimeout` is nested under `http.middlewares.test-ratelimit.rateLimit.redis`.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_33>

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          dialTimeout: 42s
```

----------------------------------------

TITLE: Configuring IP Allow List MiddlewareTCP (YAML)
DESCRIPTION: This YAML snippet defines a `MiddlewareTCP` resource named `ipallowlist` which configures an IP allow list. It restricts incoming TCP connections to specified IP ranges, in this case, `127.0.0.1/32` and `192.168.1.7`. This middleware can then be applied to TCP routes to enforce IP-based access control.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/tcp/middlewaretcp.md#_snippet_0>

```yaml
apiVersion: traefik.io/v1alpha1
kind: MiddlewareTCP
metadata:
  name: ipallowlist
spec:
  ipAllowList:
    sourceRange:
      - 127.0.0.1/32
      - 192.168.1.7
```

----------------------------------------

TITLE: Configuring Redis Dial Timeout for Rate Limit in File (TOML)
DESCRIPTION: This snippet shows how to configure the Redis dial timeout for a Traefik rate limit middleware in a static TOML configuration file. The `dialTimeout` is set within the `[http.middlewares.test-ratelimit.rateLimit.redis]` section.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_34>

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      dialTimeout = "42s"
```

----------------------------------------

TITLE: Limiting In-Flight Requests with Traefik via TOML File
DESCRIPTION: This TOML file configuration shows how to set up the Traefik InFlightReq middleware, limiting simultaneous requests to 10. This is for static configuration using TOML format.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/inflightreq.md#_snippet_4>

```toml
# Limiting to 10 simultaneous connections
[http.middlewares]
  [http.middlewares.test-inflightreq.inFlightReq]
    amount = 10
```

----------------------------------------

TITLE: Configuring Traefik Rate Limit IP Strategy Depth (File TOML)
DESCRIPTION: This TOML configuration snippet for Traefik's static or dynamic configuration file defines a `rateLimit` middleware named `test-ratelimit`. It sets the `ipStrategy.depth` to `2` within this middleware. This configuration instructs Traefik to identify the client IP for rate limiting by selecting the second IP from the right in the `X-Forwarded-For` header.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_8>

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.sourceCriterion.ipStrategy]
      depth = 2
```

----------------------------------------

TITLE: Configuring Traefik HTTP Retry Middleware with Kubernetes YAML
DESCRIPTION: This snippet illustrates how to define the Traefik `retry` middleware as a Kubernetes `Middleware` custom resource. It configures 4 retry attempts and an initial exponential backoff interval of 100 milliseconds, allowing Traefik to manage retries within a Kubernetes cluster.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/retry.md#_snippet_4>

```yaml
# Retry 4 times with exponential backoff
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-retry
spec:
  retry:
    attempts: 4
    initialInterval: 100ms
```

----------------------------------------

TITLE: Configuring Traefik TCP IPWhiteList with Docker Labels (YAML)
DESCRIPTION: This snippet demonstrates how to configure the `IPWhiteList` TCP middleware using Docker labels. It defines `sourceRange` to accept connections only from `127.0.0.1/32` and `192.168.1.7`, limiting client access based on their IP addresses.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/ipwhitelist.md#_snippet_0>

```yaml
# Accepts connections from defined IP
labels:
  - "traefik.tcp.middlewares.test-ipwhitelist.ipwhitelist.sourcerange=127.0.0.1/32, 192.168.1.7"
```

----------------------------------------

TITLE: Configuring Traefik Rate Limit IP Strategy Depth (File YAML)
DESCRIPTION: This YAML configuration snippet for Traefik's static or dynamic configuration file defines a `rateLimit` middleware named `test-ratelimit`. Within this middleware, it sets the `ipStrategy.depth` to `2`. This configuration ensures that Traefik uses the second IP from the right in the `X-Forwarded-For` header as the client IP when applying rate limits.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_7>

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        sourceCriterion:
          ipStrategy:
            depth: 2
```

----------------------------------------

TITLE: Configuring TCP IP AllowList Middleware in Kubernetes
DESCRIPTION: This snippet demonstrates how to define a Traefik `MiddlewareTCP` for IP allowlisting and apply it to an `IngressRouteTCP` within a Kubernetes environment. It restricts incoming TCP connections based on source IP ranges.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/overview.md#_snippet_4>

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: MiddlewareTCP
metadata:
  name: foo-ip-allowlist
spec:
  ipAllowList:
    sourcerange:
      - 127.0.0.1/32
      - 192.168.1.7

---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: ingressroute
spec:
# more fields...
  routes:
    # more fields...
    middlewares:
      - name: foo-ip-allowlist
```

----------------------------------------

TITLE: Configuring Redis Dial Timeout for Rate Limit in Consul Catalog (YAML)
DESCRIPTION: This snippet illustrates setting the Redis dial timeout for a Traefik rate limit middleware when using Consul Catalog. It uses a similar label-based configuration as Docker/Swarm for service discovery.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_32>

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.dialTimeout=42s"
```

----------------------------------------

TITLE: Defining a Traefik Kubernetes StripPrefix Middleware (YAML)
DESCRIPTION: This snippet defines a Traefik `Middleware` custom resource named `stripprefix` in the `foo` namespace. It configures a `stripPrefix` middleware to remove the `/stripit` prefix from incoming request paths before forwarding them to the backend service. This middleware is designed to be referenced by other Traefik resources like IngressRoutes.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/kubernetes/crd/http/middleware.md#_snippet_0>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: stripprefix
  namespace: foo

spec:
  stripPrefix:
    prefixes:
      - /stripit
```

----------------------------------------

TITLE: Configuring RateLimit Middleware in Traefik (YAML)
DESCRIPTION: This snippet demonstrates how to configure the `rateLimit` middleware in Traefik using YAML. It sets an average of 100 requests per second and allows a burst of 200 requests, based on a token bucket algorithm.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/ratelimit.md#_snippet_0>

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        average: 100
        burst: 200
```

----------------------------------------

TITLE: Traefik Service Load Balancer and Basic Authentication
DESCRIPTION: This snippet demonstrates how to configure a Traefik service with a load balancer to distribute requests to a backend server. It also shows the setup of a basic authentication middleware with predefined user credentials for securing access.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/migration/v1-to-v2.md#_snippet_2>

```toml
[[http.services.my-service.loadBalancer.servers]]
  url = "http://10.10.10.2:80"

[http.middlewares]
  [http.middlewares.auth.basicAuth]
    users = [
      "test:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/",
      "test2:$apr1$d9hr9HBB$4HxwgUir3HP4EsggP/QNo0",
    ]
```

----------------------------------------

TITLE: Configuring Redis Dial Timeout for Rate Limit in Docker & Swarm (YAML)
DESCRIPTION: This snippet demonstrates how to set the Redis dial timeout for a Traefik rate limit middleware using Docker labels. The `dialTimeout` parameter specifies the maximum time to wait for establishing a new connection to Redis.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_30>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.dialTimeout=42s"
```

----------------------------------------

TITLE: Configuring StripPrefixRegex Middleware with Kubernetes
DESCRIPTION: This snippet shows how to define a `StripPrefixRegex` middleware in Kubernetes using a `Middleware` custom resource. It sets up a middleware named `test-stripprefixregex` to remove path prefixes matching the specified regular expression, such as `/foo/bar/456/`.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/stripprefixregex.md#_snippet_1>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-stripprefixregex
spec:
  stripPrefixRegex:
    regex:
      - "/foo/[a-z0-9]+/[0-9]+/"
```

----------------------------------------

TITLE: Configure Traefik Router Middlewares with Labels
DESCRIPTION: Attaches one or more middlewares to a Traefik HTTP router using a label. Middlewares are used to modify requests or responses, such as authentication, rate limiting, or header manipulation. They are applied in the order listed.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/docker.md#_snippet_8>

```yaml
- "traefik.http.routers.myrouter.middlewares=auth,prefix,cb"
```

----------------------------------------

TITLE: Applying Middlewares to Router in Traefik ECS (YAML)
DESCRIPTION: This label attaches a list of middlewares to the Traefik HTTP router. Middlewares are used to modify requests or responses, or to perform actions like authentication, rate limiting, or header manipulation. The example applies `auth`, `prefix`, and `cb` middlewares.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/ecs.md#_snippet_2>

```yaml
traefik.http.routers.myrouter.middlewares=auth,prefix,cb

```

----------------------------------------

TITLE: Configuring Traefik Router Middlewares
DESCRIPTION: This tag attaches a list of HTTP middlewares to the router. Middlewares are applied in the order they are listed (comma-separated) and can perform various functions like authentication, request modification, or rate limiting before the request reaches the service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/nomad.md#_snippet_3>

```yaml
traefik.http.routers.myrouter.middlewares=auth,prefix,cb
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

TITLE: Configuring Basic Security Headers with Traefik (TOML)
DESCRIPTION: This snippet shows how to set up `frameDeny` and `browserXssFilter` security headers using Traefik's structured TOML configuration. It defines a middleware `testHeader` to enforce these security policies, protecting against iframe embedding and cross-site scripting.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/headers.md#_snippet_3>

```toml
[http.middlewares]
  [http.middlewares.testHeader.headers]
    frameDeny = true
    browserXssFilter = true
```

----------------------------------------

TITLE: Configuring StripPrefix Middleware in Traefik (YAML Structured)
DESCRIPTION: This YAML configuration defines a `stripPrefix` middleware named `test-stripprefix` that removes `/foobar` and `/fiibar` from the request URL path. It's used when a backend expects requests on its root path but is exposed via a specific prefix.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/stripprefix.md#_snippet_0>

```yaml
# Strip prefix /foobar and /fiibar
http:
  middlewares:
    test-stripprefix:
      stripPrefix:
        prefixes:
          - "/foobar"
          - "/fiibar"
```

----------------------------------------

TITLE: Configuring TCP IP AllowList Middleware with Docker Labels
DESCRIPTION: This snippet demonstrates how to define and apply a TCP IP allowlist middleware using Docker labels for a Traefik Proxy service. It creates a middleware named `foo-ip-allowlist` that restricts connections to specified IP ranges and then applies this middleware to a TCP router named `router1`. This configuration is suitable for Docker and Swarm environments.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/tcp/overview.md#_snippet_0>

```yaml
# As a Docker Label
whoami:
  #  A container that exposes an API to show its IP address
  image: traefik/whoami
  labels:
    # Create a middleware named `foo-ip-allowlist`
    - "traefik.tcp.middlewares.foo-ip-allowlist.ipallowlist.sourcerange=127.0.0.1/32, 192.168.1.7"
    # Apply the middleware named `foo-ip-allowlist` to the router named `router1`
    - "traefik.tcp.routers.router1.middlewares=foo-ip-allowlist@docker"
```

----------------------------------------

TITLE: Configuring GrpcWeb Middleware in Traefik (Kubernetes CRD)
DESCRIPTION: This Kubernetes YAML manifest defines a `Middleware` resource for Traefik, specifically configuring the `grpcWeb` middleware. It creates a middleware named `test-grpcweb` and sets `allowOrigins` to `*`, enabling CORS for all gRPC Web requests within a Kubernetes cluster.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/grpcweb.md#_snippet_4>

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-grpcweb
spec:
  grpcWeb:
    allowOrigins:
      - "*"
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

TITLE: Configuring Redis Write Timeout for Traefik Rate Limit Middleware
DESCRIPTION: Sets the maximum duration for socket write operations. If a write operation exceeds this timeout, the command will fail with a timeout error instead of blocking indefinitely. A value of zero indicates no timeout for write operations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_29>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.writeTimeout=42s"
```

```yaml
apiVersion: traefik.io/v1alpha
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      writeTimeout: 42s
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.writeTimeout=42s"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          writeTimeout: 42s
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      writeTimeout = "42s"
```

----------------------------------------

TITLE: Configuring Traefik HTTP Router for Specific EntryPoints (Dynamic, YAML)
DESCRIPTION: This dynamic YAML configuration defines an HTTP router (`Router-1`) that explicitly limits its listening scope to only the `websecure` and `other` EntryPoints, excluding `web`. It applies a host rule for `example.com` and routes traffic to `service-1`. This demonstrates how to restrict a router to a specific subset of defined EntryPoints.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/routers/index.md#_snippet_8>

```yaml
## Dynamic configuration
http:
  routers:
    Router-1:
      # won't listen to entry point web
      entryPoints:
        - "websecure"
        - "other"
      rule: "Host(`example.com`)"
      service: "service-1"
```

----------------------------------------

TITLE: Configuring Redis Read Timeout for Traefik Rate Limit Middleware
DESCRIPTION: Defines the maximum duration for socket read operations. If a read operation exceeds this timeout, the command will fail with a timeout error instead of blocking indefinitely. A value of zero indicates no timeout for read operations.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/ratelimit.md#_snippet_28>

```yaml
labels:
  - "traefik.http.middlewares.test-ratelimit.ratelimit.redis.readTimeout=42s"
```

```yaml
apiVersion: traefik.io/v1alpha
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    # ...
    redis:
      readTimeout: 42s
```

```yaml
- "traefik.http.middlewares.test-ratelimit.ratelimit.redis.readTimeout=42s"
```

```yaml
http:
  middlewares:
    test-ratelimit:
      rateLimit:
        # ...
        redis:
          readTimeout: 42s
```

```toml
[http.middlewares]
  [http.middlewares.test-ratelimit.rateLimit]
    [http.middlewares.test-ratelimit.rateLimit.redis]
      readTimeout = "42s"
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

TITLE: Configuring StripPrefixRegex Middleware with Docker & Swarm
DESCRIPTION: This snippet demonstrates how to configure the `StripPrefixRegex` middleware for Traefik using Docker and Swarm labels. It defines a middleware named `test-stripprefixregex` that uses a regular expression to match and strip prefixes like `/foo/abc/123/` from incoming request paths.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/stripprefixregex.md#_snippet_0>

```yaml
labels:
  - "traefik.http.middlewares.test-stripprefixregex.stripprefixregex.regex=/foo/[a-z0-9]+/[0-9]+/"
```

----------------------------------------

TITLE: Configuring InFlightConn Middleware in Traefik TCP (YAML)
DESCRIPTION: This snippet demonstrates how to configure the `inFlightConn` TCP middleware in Traefik using a structured YAML configuration. It sets the maximum allowed simultaneous connections to 10 for the `test-inflightconn` middleware, preventing service overload.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/tcp/middlewares/inflightconn.md#_snippet_0>

```yaml
# Limiting to 10 simultaneous connections
tcp:
  middlewares:
    test-inflightconn:
      inFlightConn:
        amount: 10
```

----------------------------------------

TITLE: Traefik HTTP Middleware: Digest Authentication Configuration
DESCRIPTION: Configures the DigestAuth middleware for HTTP Digest Authentication, providing a more secure alternative to Basic Auth.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/dynamic-configuration/kv-ref.md#_snippet_7>

```apidoc
DigestAuth:
  headerField: string (The header field to use for authentication. Example: 'foobar')
  realm: string (The authentication realm. Example: 'foobar')
  removeHeader: boolean (Whether to remove the authentication header after processing. Example: 'true')
  users: array of string (List of user:password pairs for authentication. Example: ['foobar', 'foobar'])
  usersFile: string (Path to a file containing user:password pairs. Example: 'foobar')
```

----------------------------------------

TITLE: Configuring Traefik Buffering with Docker Labels
DESCRIPTION: This snippet demonstrates how to configure the Traefik buffering middleware using Docker labels. It sets the `maxRequestBodyBytes` for a middleware named 'limit' to 2MB (2,000,000 bytes), typically applied to a container to control its request size limits.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/buffering.md#_snippet_2>

```yaml
labels:
  - "traefik.http.middlewares.limit.buffering.maxRequestBodyBytes=2000000"
```

----------------------------------------

TITLE: Traefik GrpcWeb Middleware `allowOrigins` Configuration Option
DESCRIPTION: Describes the `allowOrigins` configuration parameter for the Traefik GrpcWeb middleware, which defines the list of allowed origins for gRPC Web requests. A wildcard `*` can be used to match all requests.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/middlewares/http/grpcweb.md#_snippet_1>

```apidoc
allowOrigins:
  type: array of strings
  description: List of allowed origins for gRPC Web requests. A wildcard `*` can be configured to match all requests.
  example: ["*"], ["https://example.com", "https://another.org"]
```

----------------------------------------

TITLE: Configuring RateLimit Middleware in Traefik Kubernetes
DESCRIPTION: This snippet shows how to define a `rateLimit` middleware as a Kubernetes `Middleware` custom resource for Traefik. It configures an average of 100 requests per second and a burst of 200 requests.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/http/middlewares/ratelimit.md#_snippet_4>

```yaml
# Here, an average of 100 requests per second is allowed.
# In addition, a burst of 200 requests is allowed.
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: test-ratelimit
spec:
  rateLimit:
    average: 100
    burst: 200
```

----------------------------------------

TITLE: Declaring and Referencing Traefik TCP Middleware
DESCRIPTION: Demonstrates how to declare a TCP middleware, such as `InFlightConn`, and subsequently reference it within a TCP router configuration. This example shows how to limit concurrent connections and apply the middleware to a service.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/nomad.md#_snippet_55>

```yaml
# ...
# Declaring a middleware
traefik.tcp.middlewares.test-inflightconn.amount=10
# Referencing a middleware
traefik.tcp.routers.my-service.middlewares=test-inflightconn
```

----------------------------------------

TITLE: Configure Traefik Buffering Middleware for Content-Length Validation
DESCRIPTION: This YAML configuration defines a Traefik HTTP middleware named `buffer-and-validate` that enables full buffering. When this middleware is applied, Traefik will read the entire request or response body into memory and compare its actual size against the `Content-Length` header, rejecting messages if the counts do not match. This ensures strict content validation but introduces memory and latency overhead.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/security/content-length.md#_snippet_0>

```yaml
http:
  middlewares:
    buffer-and-validate:
      buffering: {}
```

----------------------------------------

TITLE: Securing Traefik HTTP Sticky Session Cookie
DESCRIPTION: This configuration sets the `secure` flag to `true` for the sticky session cookie of `myservice`. This ensures that the cookie is only transmitted over secure HTTPS connections, protecting sensitive information from interception.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/routing/providers/ecs.md#_snippet_33>

```yaml
traefik.http.services.myservice.loadbalancer.sticky.cookie.secure=true
```

----------------------------------------

TITLE: Declare and Reference Traefik TCP Middleware in YAML
DESCRIPTION: This snippet provides an example of how to declare a Traefik TCP middleware and then reference it from a TCP router. Middleware components allow for modifying requests or responses, such as limiting concurrent connections. This demonstrates the two-step process of defining and applying middleware.
SOURCE: <https://github.com/traefik/traefik/blob/master/docs/content/reference/routing-configuration/other-providers/swarm.md#_snippet_60>

```yaml
# ...
# Declaring a middleware
traefik.tcp.middlewares.test-inflightconn.amount=10
