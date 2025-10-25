# Testing

## List of test URLs

- <http://100.118.110.60:8096>  # Tailscale IP
- <http://bolabaden-the-fourth.noodlefish-pound.ts.net:8096>  # Tailscale Hostname
- <http://jellyfin.bolabaden-the-fourth.noodlefish-pound.ts.net>  # Tailscale Hostname
- <https://jellyfin.bolabaden-the-fourth.noodlefish-pound.ts.net>  # Tailscale Hostname
- <http://170.9.243.8:8096>  # Public IP
- <http://bolabaden.duckdns.org:8096>  # Public Legacy DuckDNS
- <http://bolabaden.org:8096>  # Public Cloudflare Main Domain
- <http://jellyfin.bolabaden.org>  # Public Cloudflare Main Domain
- <https://jellyfin.bolabaden.org>  # Public Cloudflare Main Domain

## Reverse Proxy Test Results

### Raw Tailscale IP Tests

| URL | Status |
|-----|--------|
| <http://100.118.110.60:7878>   | Passed! |
| <http://100.118.110.60:8096>   | Passed! |

### Raw Public IP Tests

| URL | Status |
|-----|--------|
| <http://170.9.243.8:7878>    | Passed! |
| <http://170.9.243.8:8096>    | Passed! |

### HTTP Tailscale Domain Test

| URL | Status |
|-----|--------|
| <http://bolabaden-the-fourth.noodlefish-pound.ts.net:7878>          | ERR_NAME_NOT_RESOLVED |
| <http://bolabaden-the-fourth.noodlefish-pound.ts.net:8096>          | ERR_NAME_NOT_RESOLVED |
| <http://radarr.bolabaden-the-fourth.noodlefish-pound.ts.net:80>     | ERR_NAME_NOT_RESOLVED |
| <http://jellyfin.bolabaden-the-fourth.noodlefish-pound.ts.net:80>     | ERR_NAME_NOT_RESOLVED |
| <https://radarr.bolabaden-the-fourth.noodlefish-pound.ts.net:443>   | ERR_NAME_NOT_RESOLVED |
| <https://jellyfin.bolabaden-the-fourth.noodlefish-pound.ts.net:443>   | ERR_NAME_NOT_RESOLVED |

### HTTP Cloudflare Main Domain Test

| URL | Status |
|-----|--------|
| <http://bolabaden.org:7878>          | ERR_CONNECTION_TIMED_OUT |
| <http://radarr.bolabaden.org:80>     | ERR_NAME_NOT_RESOLVED (browse warns Not Secure) |
| <http://jellyfin.bolabaden.org:80>     | ERR_NAME_NOT_RESOLVED (browse warns Not Secure) |
| <https://radarr.bolabaden.org:443>   | ERR_NAME_NOT_RESOLVED (No browser warning?) |
| <https://jellyfin.bolabaden.org:443>   | ERR_NAME_NOT_RESOLVED (No browser warning?) |

Notes: Both http and https versions of the domain show ERR_NAME_NOT_RESOLVED, and both automatically cause the chromium browser to redirect to https://. However, the http:// link shows 'Not Secure' while the https:// link shows 'Secure', which makes zero sense since they don't even load to the point where the certificates would be requested?

### DuckDNS Legacy Subdomain Tests

| URL | Status |
|-----|--------|
| <http://bolabaden.duckdns.org:7878> | Passed! |
| <http://radarr.bolabaden.duckdns.org:80> | 404 (serverside) |
| <http://jellyfin.bolabaden.duckdns.org:80> | 404 (serverside) |
| <https://radarr.bolabaden.duckdns.org:443> | 404 (serverside) |
| <https://jellyfin.bolabaden.duckdns.org:443> | 404 (serverside) |

## Troubleshooting the results

### `curl -v http://100.118.110.60:7878`

    ```shell
    PS C:\Users\remote-tailscale-user> curl -v http://100.118.110.60:7878
    *   Trying 100.118.110.60:7878...
    * Connected to 100.118.110.60 (100.118.110.60) port 7878
    > GET / HTTP/1.1
    > Host: 100.118.110.60:7878
    > User-Agent: curl/8.9.1
    > Accept: */*
    >
    * Request completely sent off
    < HTTP/1.1 302 Found
    < Content-Length: 0
    < Date: Sun, 30 Mar 2025 16:41:06 GMT
    < Server: Kestrel
    < Location: http://100.118.110.60:7878/login?returnUrl=%2F
    <
    * Connection #0 to host 100.118.110.60 left intact
    ```

### `curl -v http://170.9.243.8:7878`

    ```shell
    PS C:\Users\remote-tailscale-user> curl -v http://170.9.243.8:7878
    *   Trying 170.9.243.8:7878...
    * Connected to 170.9.243.8 (170.9.243.8) port 7878
    > GET / HTTP/1.1
    > Host: 170.9.243.8:7878
    > User-Agent: curl/8.9.1
    > Accept: */*
    >
    * Request completely sent off
    < HTTP/1.1 302 Found
    < Content-Length: 0
    < Date: Sun, 30 Mar 2025 16:41:22 GMT
    < Server: Kestrel
    < Location: http://170.9.243.8:7878/login?returnUrl=%2F
    <
    * Connection #0 to host 170.9.243.8 left intact
    ```

### `curl -v http://bolabaden-the-fourth.noodlefish-pound.ts.net:7878`

    ```shell
    PS C:\Users\remote-tailscale-user> curl -v http://bolabaden-the-fourth.noodlefish-pound.ts.net:7878
    *   Trying 100.118.110.60:7878...
    * Connected to 100.118.110.60 (100.118.110.60) port 7878
    > GET / HTTP/1.1
    > Host: bolabaden-the-fourth.noodlefish-pound.ts.net:7878
    > User-Agent: curl/8.9.1
    > Accept: */*
    >
    * Request completely sent off
    < HTTP/1.1 302 Found
    < Content-Length: 0
    < Date: Sun, 30 Mar 2025 16:24:13 GMT
    < Server: Kestrel
    < Location: http://170.9.243.8:7878/login?returnUrl=%2F
    <
    * Connection #0 to host 170.9.243.8 left intact
    ```

### `curl -v http://bolabaden.duckdns.org:7878`

    ```shell
    PS C:\Users\remote-tailscale-user> curl -v http://bolabaden.duckdns.org:7878
    * Host bolabaden.duckdns.org:7878 was resolved.
    * IPv6: (none)
    * IPv4: 170.9.243.8
    *   Trying 170.9.243.8:7878...
    * connect to 170.9.243.8 port 7878 from 0.0.0.0 port 17704 failed: Connection refused
    * Failed to connect to bolabaden.duckdns.org port 7878 after 2189 ms: Could not connect to server
    * closing connection #0
    curl: (7) Failed to connect to bolabaden.duckdns.org port 7878 after 2189 ms: Could not connect to server
    ```

### `curl -v http://bolabaden.org:7878`

    ```shell
    PS C:\Users\remote-tailscale-user> curl -v http://bolabaden.org:7878
    * Host bolabaden.org:7878 was resolved.
    * IPv6: 2606:4700:3032::ac43:c725, 2606:4700:3031::6815:5cdc
    * IPv4: 104.21.92.220, 172.67.199.37
    *   Trying 104.21.92.220:7878...
    *   Trying [2606:4700:3032::ac43:c725]:7878...
    * connect to 2606:4700:3032::ac43:c725 port 7878 from :: port 17768 failed: Network unreachable
    *   Trying [2606:4700:3031::6815:5cdc]:7878...
    * connect to 2606:4700:3031::6815:5cdc port 7878 from :: port 17769 failed: Network unreachable
    * connect to 104.21.92.220 port 7878 from 0.0.0.0 port 17767 failed: Timed out
    *   Trying 172.67.199.37:7878...
    * connect to 172.67.199.37 port 7878 from 0.0.0.0 port 17811 failed: Timed out
    * Failed to connect to bolabaden.org port 7878 after 42194 ms: Could not connect to server
    * closing connection #0
    curl: (28) Failed to connect to bolabaden.org port 7878 after 42194 ms: Could not connect to server
    ```

### ping bolabaden-the-fourth.noodlefish-pound.ts.net

    ```shell
    PS C:\Users\remote-tailscale-user> ping bolabaden-the-fourth.noodlefish-pound.ts.net

    Pinging bolabaden-the-fourth.noodlefish-pound.ts.net. [100.118.110.60] with 32 bytes of data:
    Reply from 100.118.110.60: bytes=32 time=34ms TTL=64
    Reply from 100.118.110.60: bytes=32 time=34ms TTL=64
    Reply from 100.118.110.60: bytes=32 time=34ms TTL=64
    Reply from 100.118.110.60: bytes=32 time=34ms TTL=64

    Ping statistics for 100.118.110.60:
        Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 34ms, Maximum = 34ms, Average = 34ms
    ```

### ping bolabaden.duckdns.org

    ```shell
    PS C:\Users\remote-tailscale-user> ping bolabaden.duckdns.org

    Pinging bolabaden.duckdns.org [170.9.243.8] with 32 bytes of data:
    Reply from 170.9.243.8: bytes=32 time=30ms TTL=49
    Reply from 170.9.243.8: bytes=32 time=30ms TTL=49
    Reply from 170.9.243.8: bytes=32 time=31ms TTL=49
    Reply from 170.9.243.8: bytes=32 time=31ms TTL=49

    Ping statistics for 170.9.243.8:
        Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 30ms, Maximum = 31ms, Average = 30ms
    ```

### ping bolabaden.org

    ```shell
    PS C:\Users\remote-tailscale-user> ping bolabaden.org

    Pinging bolabaden.org [104.21.92.220] with 32 bytes of data:
    Reply from 104.21.92.220: bytes=32 time=15ms TTL=56
    Reply from 104.21.92.220: bytes=32 time=14ms TTL=56
    Reply from 104.21.92.220: bytes=32 time=13ms TTL=56
    Reply from 104.21.92.220: bytes=32 time=13ms TTL=56

    Ping statistics for 104.21.92.220:
        Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 13ms, Maximum = 15ms, Average = 13ms
    ```

## Debug Information

### `/etc/hosts`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ sudo cat /etc/hosts
    127.0.0.1       localhost

    # The following lines are desirable for IPv6 capable hosts
    ::1     ip6-localhost   ip6-loopback
    fe00::0 ip6-localnet
    ff00::0 ip6-mcastprefix
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
    ff02::3 ip6-allhosts
    127.0.1.1       bolabaden-the-fourth    bolabaden-the-fourth
    100.118.110.60 bolabaden-the-fourth.noodlefish-pound.ts.net bolabaden-the-fourth
    100.72.149.123 micklethefickle3.noodlefish-pound.ts.net micklethefickle3
    100.77.219.5 wizard-pc-docker-desktop.noodlefish-pound.ts.net wizard-pc-docker-desktop
    100.119.187.62 wizard.noodlefish-pound.ts.net wizard
    ```

### `/etc/resolv.conf`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ sudo cat /etc/resolv.conf
    [sudo] password for brunner56: 
    # This is /run/systemd/resolve/stub-resolv.conf managed by man:systemd-resolved(8).
    # Do not edit.
    #
    # This file might be symlinked as /etc/resolv.conf. If you're looking at
    # /etc/resolv.conf and seeing this text, you have followed the symlink.
    #
    # This is a dynamic resolv.conf file for connecting local clients to the
    # internal DNS stub resolver of systemd-resolved. This file lists all
    # configured search domains.
    #
    # Run "resolvectl status" to see details about the uplink DNS servers
    # currently in use.
    #
    # Third party programs should typically not access this file directly, but only
    # through the symlink at /etc/resolv.conf. To manage man:resolv.conf(5) in a
    # different way, replace this symlink by a static file or a different symlink.
    #
    # See man:systemd-resolved.service(8) for details about the supported modes of
    # operation for /etc/resolv.conf.

    nameserver 127.0.0.53
    options edns0 trust-ad
    search vcn03111505.oraclevcn.com noodlefish-pound.ts.net
    ```

### `tailscale status`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ tailscale status
    100.118.110.60  bolabaden-the-fourth th3w1zard1@  linux   -
    100.97.148.14   iphone172            th3w1zard1@  iOS     -
    100.72.149.123  micklethefickle      th3w1zard1@  linux   active; direct 149.130.221.93:41641, tx 538562364 rx 291365508
    100.89.241.84   wizard-pc-docker-desktop-1 th3w1zard1@  linux   -
    100.77.219.5    wizard-pc-docker-desktop th3w1zard1@  linux   offline
    100.121.16.10   wizard-pc            th3w1zard1@  linux   active; direct 46.110.81.130:12167, tx 446918744 rx 193461896
    100.119.187.62  wizard               th3w1zard1@  windows active; direct 46.110.81.130:12201, tx 25501636 rx 27180812

    # Health check:
    #     - Tailscale can't reach the configured DNS servers. Internet connectivity may be affected.
    #     - adding [-i tailscale0 -j MARK --set-mark 0x40000/0xff0000] in v6/filter/ts-forward: running [/usr/sbin/ip6tables -t filter -A ts-forward -i tailscale0 -j MARK --set-mark 0x40000/0xff0000 --wait]: exit status 2: Warning: Extension MARK revision 0 not supported, missing kernel module?
    ip6tables v1.8.10 (nf_tables): MARK: bad value for option "--set-mark", or out of range (0-4294967295).

    Try `ip6tables -h' or 'ip6tables --help' for more information.

    ```

### `tailscale ip`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ tailscale ip
    100.118.110.60
    fd7a:115c:a1e0::9f01:6e3e
    ```

### `sudo resolvectl status`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ sudo resolvectl status
    Global
            Protocols: -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
    resolv.conf mode: stub

    Link 2 (enp0s6)
        Current Scopes: DNS
            Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
    Current DNS Server: 169.254.169.254
        DNS Servers: 169.254.169.254
            DNS Domain: vcn03111505.oraclevcn.com

    Link 4 (docker0)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46 (tailscale0)
        Current Scopes: DNS
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
    Current DNS Server: 100.100.100.100
        DNS Servers: 100.100.100.100
            DNS Domain: noodlefish-pound.ts.net ~0.e.1.a.c.5.1.1.a.7.d.f.ip6.arpa ~100.100.in-addr.arpa
                        ~101.100.in-addr.arpa ~102.100.in-addr.arpa ~103.100.in-addr.arpa ~104.100.in-addr.arpa
                        ~105.100.in-addr.arpa ~106.100.in-addr.arpa ~107.100.in-addr.arpa ~108.100.in-addr.arpa
                        ~109.100.in-addr.arpa ~110.100.in-addr.arpa ~111.100.in-addr.arpa ~112.100.in-addr.arpa
                        ~113.100.in-addr.arpa ~114.100.in-addr.arpa ~115.100.in-addr.arpa ~116.100.in-addr.arpa
                        ~117.100.in-addr.arpa ~118.100.in-addr.arpa ~119.100.in-addr.arpa ~120.100.in-addr.arpa
                        ~121.100.in-addr.arpa ~122.100.in-addr.arpa ~123.100.in-addr.arpa ~124.100.in-addr.arpa
                        ~125.100.in-addr.arpa ~126.100.in-addr.arpa ~127.100.in-addr.arpa ~64.100.in-addr.arpa
                        ~65.100.in-addr.arpa ~66.100.in-addr.arpa ~67.100.in-addr.arpa ~68.100.in-addr.arpa
                        ~69.100.in-addr.arpa ~70.100.in-addr.arpa ~71.100.in-addr.arpa ~72.100.in-addr.arpa
                        ~73.100.in-addr.arpa ~74.100.in-addr.arpa ~75.100.in-addr.arpa ~76.100.in-addr.arpa
                        ~77.100.in-addr.arpa ~78.100.in-addr.arpa ~79.100.in-addr.arpa ~80.100.in-addr.arpa
                        ~81.100.in-addr.arpa ~82.100.in-addr.arpa ~83.100.in-addr.arpa ~84.100.in-addr.arpa
                        ~85.100.in-addr.arpa ~86.100.in-addr.arpa ~87.100.in-addr.arpa ~88.100.in-addr.arpa
                        ~89.100.in-addr.arpa ~90.100.in-addr.arpa ~91.100.in-addr.arpa ~92.100.in-addr.arpa
                        ~93.100.in-addr.arpa ~94.100.in-addr.arpa ~95.100.in-addr.arpa ~96.100.in-addr.arpa
                        ~97.100.in-addr.arpa ~98.100.in-addr.arpa ~99.100.in-addr.arpa ~ts.net

    Link 13690 (docker_gwbridge)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 38513 (veth357b852)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 43368 (br-e9906d74e4a3)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44683 (br-36e3ddd32ed8)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44684 (br-a127a61d48cf)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44685 (br-0b2d5c7135f8)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44686 (veth03a7be6)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44698 (veth8a31404)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 44707 (veth788375d)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45675 (veth1940ac2)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45766 (veth5d9dad8)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45968 (veth961333f)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45970 (vetha472228)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45971 (veth03c0dff)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45974 (veth600d86f)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45976 (veth837ea7d)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45977 (veth156bacc)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45980 (veth918916a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45981 (vetha0e0c67)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45982 (veth978381d)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45983 (veth0c16e94)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45984 (veth7ad58f9)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45989 (veth8028508)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45990 (vethf442b7c)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45991 (vethcd7202f)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45992 (veth17da65c)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45997 (veth8aacf9e)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 45999 (vethbaa812b)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46001 (veth24ffb76)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46003 (vethad140d9)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46004 (veth3cbd3f4)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46006 (vethe22a433)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46008 (vethbf5574a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46010 (veth7dcc022)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46015 (veth48750b4)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46017 (veth883eb2c)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46214 (veth96b9ba0)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46215 (vethaaecfc4)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46415 (vethecc75dd)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46505 (veth4bef72a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 46506 (veth66b609d)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47043 (veth28d8eed)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47045 (vethaed86c8)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47063 (veth3974cf7)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47064 (veth09e85bc)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47073 (veth6b0881a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47074 (vethc523abc)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47076 (veth1d8d96f)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47078 (veth99166c6)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47079 (veth8db35e2)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47081 (veth9587ffa)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47082 (veth666833a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47084 (veth51f7409)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47085 (veth29b5f55)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47087 (vetha4fefa6)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47089 (veth47ab51a)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported

    Link 47093 (veth9eb5c0b)
        Current Scopes: none
            Protocols: -DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
    ```

### `sudo iptables -L -v -n -t nat`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ sudo iptables -L -v -n -t nat
    # Warning: iptables-legacy tables present, use iptables-legacy to see them
    Chain PREROUTING (policy ACCEPT 232K packets, 20M bytes)
    pkts bytes target     prot opt in     out     source               destination         
    139K   11M DOCKER-INGRESS  0    --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
    73737 6612K DOCKER     0    --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

    Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
    pkts bytes target     prot opt in     out     source               destination         

    Chain OUTPUT (policy ACCEPT 966K packets, 68M bytes)
    pkts bytes target     prot opt in     out     source               destination         
    401K   30M DOCKER-INGRESS  0    --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
    503 76296 DOCKER     0    --  *      *       0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

    Chain POSTROUTING (policy ACCEPT 1034K packets, 76M bytes)
    pkts bytes target     prot opt in     out     source               destination         
        0     0 MASQUERADE  0    --  *      !br-0b2d5c7135f8  192.168.100.0/24     0.0.0.0/0           
    118  9718 MASQUERADE  0    --  *      !br-a127a61d48cf  172.18.0.0/16        0.0.0.0/0           
    22  1320 MASQUERADE  0    --  *      !br-36e3ddd32ed8  192.51.0.0/16        0.0.0.0/0           
    66938 7018K MASQUERADE  0    --  *      !br-e9906d74e4a3  172.20.0.0/16        0.0.0.0/0           
        0     0 MASQUERADE  0    --  *      docker_gwbridge  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match src-type LOCAL
    25  1500 MASQUERADE  0    --  *      !docker_gwbridge  172.19.0.0/16        0.0.0.0/0           
    491 74452 MASQUERADE  0    --  *      !docker0  172.17.0.0/16        0.0.0.0/0           
    242 36224 MASQUERADE  0    --  *      !docker_gwbridge  172.18.0.0/16        0.0.0.0/0           
    1044K   77M ts-postrouting  0    --  *      *       0.0.0.0/0            0.0.0.0/0           

    Chain DOCKER (2 references)
    pkts bytes target     prot opt in     out     source               destination         
        0     0 RETURN     0    --  br-0b2d5c7135f8 *       0.0.0.0/0            0.0.0.0/0           
        0     0 RETURN     0    --  br-a127a61d48cf *       0.0.0.0/0            0.0.0.0/0           
    38  3228 RETURN     0    --  br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0           
    3399  247K RETURN     0    --  br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0           
        0     0 RETURN     0    --  docker_gwbridge *       0.0.0.0/0            0.0.0.0/0           
        0     0 RETURN     0    --  docker0 *       0.0.0.0/0            0.0.0.0/0           
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:4545 to:172.20.0.2:4545
    2801  168K DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5432 to:172.20.0.17:5432
        2   104 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8585 to:172.20.0.6:8585
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5435 to:172.20.0.9:5432
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5431 to:172.20.0.10:5432
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5434 to:172.20.0.11:5432
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8077 to:172.20.0.15:8080
        2   104 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8443 to:172.20.0.16:8443
        2   104 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9998 to:172.20.0.20:8080
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:6379 to:172.20.0.4:6379
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9090 to:172.20.0.21:9090
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8765 to:172.20.0.22:80
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:6969 to:172.20.0.28:6969
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8686 to:172.20.0.30:8686
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:1900 to:172.20.0.31:1900
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8324 to:172.20.0.31:8324
        3   180 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:32400 to:172.20.0.31:32400
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:1901 to:172.20.0.32:1900
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:32410 to:172.20.0.31:32410
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:7359 to:172.20.0.32:7359
    10   600 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8096 to:172.20.0.32:8096
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:32412 to:172.20.0.31:32412
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8920 to:172.20.0.32:8920
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:3000 to:172.20.0.34:3000
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:32413 to:172.20.0.31:32413
    13   712 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:172.20.0.36:8080
        0     0 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:32414 to:172.20.0.31:32414
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:32469 to:172.20.0.31:32469
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:3005 to:192.51.0.2:3000
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5430 to:192.51.0.2:5430
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:7474 to:192.51.0.2:7474
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8000 to:192.51.0.2:8000
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8085 to:192.51.0.2:8080
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8086 to:192.51.0.2:8080
    89  5340 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8112 to:192.51.0.2:8112
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8191 to:192.51.0.2:8191
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8388 to:192.51.0.2:8388
        0     0 DNAT       17   --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            udp dpt:8388 to:192.51.0.2:8388
        2    84 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8888 to:192.51.0.2:8888
    221 13260 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9094 to:192.51.0.2:9091
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9092 to:192.51.0.2:9092
        1    40 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9117 to:192.51.0.2:9117
    115  6900 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9696 to:192.51.0.2:9696
        1    44 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:9999 to:192.51.0.2:9999
        1    52 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:51413 to:192.51.0.2:51413
        0     0 DNAT       17   --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            udp dpt:51413 to:192.51.0.2:51413
        0     0 DNAT       6    --  !br-36e3ddd32ed8 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:58846 to:192.51.0.2:58846
    28  1680 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8989 to:172.20.0.12:8989
    21  1175 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:80 to:172.20.0.19:80
    54  3208 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443 to:172.20.0.19:443
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8099 to:172.20.0.19:8099
        2   120 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:7878 to:172.20.0.25:7878
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5656 to:172.20.0.23:5656
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:5055 to:172.20.0.13:5055
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:6767 to:172.20.0.33:6767
        6   352 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:6881 to:172.20.0.7:6881
    110 13798 DNAT       17   --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            udp dpt:6881 to:172.20.0.7:6881
        3   180 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8084 to:172.20.0.7:8084
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:4000 to:172.20.0.24:8080
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8075 to:172.20.0.37:8080
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8787 to:172.20.0.35:8787
        0     0 DNAT       6    --  !br-e9906d74e4a3 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:4001 to:172.20.0.26:4000

    Chain DOCKER-INGRESS (2 references)
    pkts bytes target     prot opt in     out     source               destination         
    117K 9548K RETURN     0    --  *      *       0.0.0.0/0            0.0.0.0/0           

    Chain ts-postrouting (1 references)
    pkts bytes target     prot opt in     out     source               destination
    ```

### `sudo iptables-legacy -L -v -n -t nat`

    ```shell
    brunner56@bolabaden-the-fourth:~/my-media-stack$ sudo iptables-legacy -L -v -n -t nat
    Chain PREROUTING (policy ACCEPT 274K packets, 25M bytes)
    pkts bytes target     prot opt in     out     source               destination         

    Chain INPUT (policy ACCEPT 70711 packets, 3995K bytes)
    pkts bytes target     prot opt in     out     source               destination         

    Chain OUTPUT (policy ACCEPT 965K packets, 68M bytes)
    pkts bytes target     prot opt in     out     source               destination         

    Chain POSTROUTING (policy ACCEPT 1151K packets, 88M bytes)
    pkts bytes target     prot opt in     out     source               destination  
    ```

### `/certs/acme.json`

    ```json
    {
        "myresolver": {
            "Account": {
            "Email": "boden.crouch@gmail.com",
            "Registration": {
                "body": {
                "status": "valid",
                "contact": ["mailto:boden.crouch@gmail.com"],
                "termsOfServiceAgreed": true,
                "orders": "https://acme.zerossl.com/v2/DV90/account/H3m7w5OyzI53RLPUo5InbA/orders",
                "externalAccountBinding": {
                    "payload": "<redacted>",
                    "protected": "<redacted>",
                    "signature": "<redacted>"
                }
                },
                "uri": "https://acme.zerossl.com/v2/DV90/account/H3m7w5OyzI53RLPUo5InbA"
            },
            "PrivateKey": "<redacted>",
            "KeyType": "4096"
            },
            "Certificates": [
                {
                    "domain": {
                        "main": "bolabaden.duckdns.org",
                        "sans": ["*.bolabaden.duckdns.org"]
                    },
                    "certificate": "<redacted>",
                    "key": "<redacted>",
                    "Store": "default"
                },
                {
                    "domain": {
                        "main": "bolabaden.org",
                        "sans": ["*.bolabaden.org"]
                    },
                    "certificate": "<redacted>",
                    "key": "<redacted>",
                    "Store": "default"
                }
            ]
        }
    }
    ```
