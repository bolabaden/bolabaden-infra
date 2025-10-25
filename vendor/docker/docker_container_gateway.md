# [Use docker container as network gateway](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway)

Asked6 years, 9 months ago

Modified [3 years, 10 months ago](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway?lastactivity "2021-09-04 19:43:37Z")

Viewed
20k times


This question shows research effort; it is useful and clear

12

Save this question.

[Timeline](https://stackoverflow.com/posts/52595272/timeline)

Show activity on this post.

I want to configure a gateway to connect two containers. Below is an example compose file that creates three containers - a test\_client, a test\_server and a proxy. The proxy server should act as the default gateway for all traffic to the test\_server from the test\_client. I am using compose file format v2 as IPAM gateway configurations are not supported in v3.

```hljs yaml
version: "2"
services:
  proxy:
    build: .
    cap_add:
      - NET_ADMIN
    expose:
      - 8080
      - 80
      - 443
    networks:
      client_network:
          ipv4_address: '192.168.0.5'
      server_network: null
    stdin_open: true
    tty: true
  test_server:
    build: ./test_server
    expose:
      - 8000
    networks:
      - server_network
  test_client:
    build: ./test_client
    networks:
      - client_network
    stdin_open: true
    tty: true

networks:
  client_network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: "192.168.0.0/24"
          gateway: "192.168.0.5"
  server_network:
    driver: bridge

```

When I run `docker-compose up`, I get the following error:

```hljs yaml
ERROR: for 28e458cec9ac_network_proxy_1  b'user specified IP address is supported only when connecting to networks with user configured subnets'

```

I've read the following resources:

[SO: docker container as gateway between two docker bridges](https://stackoverflow.com/questions/45695927/docker-container-as-gateway-between-two-docker-bridges) [Docker forums](https://forums.docker.com/t/setting-default-gateway-to-a-container/17420)

But they don't seem to help me answer how I get this setup. I'm not committed to any particular networking structure - the only thing I want is to configure something where one container acts as a network-level gateway between two other containers.

- [docker](https://stackoverflow.com/questions/tagged/docker "show questions tagged 'docker'")
- [docker-compose](https://stackoverflow.com/questions/tagged/docker-compose "show questions tagged 'docker-compose'")
- [docker-network](https://stackoverflow.com/questions/tagged/docker-network "show questions tagged 'docker-network'")

[Share](https://stackoverflow.com/q/52595272 "Short permalink to this question")

Share a link to this question

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

[Improve this question](https://stackoverflow.com/posts/52595272/edit "")

Follow



Follow this question to receive notifications

asked Oct 1, 2018 at 16:30

[![Orphid's user avatar](https://www.gravatar.com/avatar/2708b8f0465834a359f8abde10e8b3a3?s=64&d=identicon&r=PG&f=y&so-version=2)](https://stackoverflow.com/users/3100456/orphid)

[Orphid](https://stackoverflow.com/users/3100456/orphid) Orphid

2,85222 gold badges3030 silver badges4141 bronze badges

2

- Alright, I'm really not sure about this, but considering that the only network in your docker-compose file is "user-specified" in the sense that you do define it explicitly, could your problem be that you are using a subnet that is already used by your host's networking? Maybe switch to `192.168.5.0/24` and see if it changes anything?


– [NicolasB](https://stackoverflow.com/users/10408843/nicolasb "1,081 reputation")

[CommentedOct 1, 2018 at 18:00](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment92127519_52595272)

- Had the same problem. Your docker-compose file looks fine to me. I guess, you tried creating the stuff without the subnet config and now docker won't update the network configuration to the one with a subnet specified... check with `docker network inspect client_network`. If that's the case, DO NOT remove it with "docker network rm" or you would break lots of stuff (just found out the hard way), seems like you should remove the networks via `docker-compose down`... See: [github.com/docker/compose/issues/5745#issuecomment-370031631](https://github.com/docker/compose/issues/5745#issuecomment-370031631) (haven't tested this, chose the wrong way)


– [mozzbozz](https://stackoverflow.com/users/1202500/mozzbozz "3,153 reputation")

[CommentedOct 29, 2018 at 0:01](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment92974430_52595272)


[Add a comment](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway# "Use comments to ask for more information or suggest improvements. Avoid answering questions in comments.") \| [Expand to show all comments on this post](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway# "Expand to show all comments on this post")

## 1 Answer  1

Sorted by:
[Reset to default](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway?answertab=scoredesc#tab-top)

Highest score (default)

Trending (recent votes count more)

Date modified (newest first)

Date created (oldest first)


This answer is useful

13

Save this answer.

[Timeline](https://stackoverflow.com/posts/69055795/timeline)

Show activity on this post.

Unfortunately this use-case isn't really supported by bridge networks (or any other kind of docker network). The problem is that bridge networks use your host machine as the gateway. It does this by creating a virtual interface for your host on the bridge network and doing some host configuration to implement the necessary routing. The `gateway` option only configures what IP address will be assigned to this virtual interface.

This doesn't seem to be well documented, I think it's considered an implementation detail of docker networking. I found it out from a couple of forum posts: [source 1](https://forums.docker.com/t/setting-default-gateway-to-a-container/17420/2), [source 2](https://forums.docker.com/t/new-user-set-default-gateway-of-container-to-other-machine-in-lan/35066).

Edit: Here's my working docker-compose file. This has two private networks, each with it's own gateway, ie `alice <-> moon <-> sun <-> bob`. The magic is in the `ip` and `iptables` commands inside the `command:` block run by each container. Ignore the `tail -f /dev/null`, it's just a command that will never finish which means the container stays running until you kill it.

```hljs yaml
version: "3.3"

services:

  alice:
    image: ubuntu-with-tools
    cap_add:
      - NET_ADMIN
    hostname: alice
    networks:
      moon-internal:
        ipv4_address: 172.28.0.3
    command: >-
      sh -c "ip route del default &&
      ip route add default via 172.28.0.2 &&
      tail -f /dev/null"

  moon:
    image: ubuntu-with-tools
    cap_add:
      - NET_ADMIN
    hostname: moon
    networks:
      moon-internal:
        ipv4_address: 172.28.0.2
      internet:
        ipv4_address: 172.30.0.2
    command: >-
      sh -c "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE &&
      iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE &&
      iptables -A FORWARD -i eth1 -j ACCEPT &&
      iptables -A FORWARD -i eth0 -j ACCEPT &&
      ip route add 172.29.0.0/16 via 172.30.0.4 &&
      tail -f /dev/null"

  sun:
    image: ubuntu-with-tools
    cap_add:
      - NET_ADMIN
    hostname: sun
    networks:
      sun-internal:
        ipv4_address: 172.29.0.4
      internet:
        ipv4_address: 172.30.0.4
    command: >-
      sh -c "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE &&
      iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE &&
      iptables -A FORWARD -i eth1 -j ACCEPT &&
      iptables -A FORWARD -i eth0 -j ACCEPT &&
      ip route add 172.28.0.0/16 via 172.30.0.2 &&
      tail -f /dev/null"

  bob:
    image: ubuntu-with-tools
    cap_add:
      - NET_ADMIN
    hostname: bob
    networks:
      sun-internal:
        ipv4_address: 172.29.0.5
    command: >-
      sh -c "ip route del default &&
      ip route add default via 172.29.0.4 &&
      tail -f /dev/null"

networks:
  moon-internal:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
  sun-internal:
    driver: bridge
    ipam:
      config:
        - subnet: 172.29.0.0/16
  internet:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16

```

To try it out run `docker exec -it ipsec-playground_bob_1 tcpdump` and `docker exec -it ipsec-playground_alice_1 ping 172.29.0.5`. You should see pings from alice reaching bob.

`ubuntu-with-tools` is a simple ubuntu image with some things that I wanted installed, here's the Dockerfile:

```hljs yaml
FROM ubuntu
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2 inetutils-ping curl host mtr-tiny tcpdump iptables \
    && rm -rf /var/lib/apt/lists/*

```

[Share](https://stackoverflow.com/a/69055795 "Short permalink to this answer")

Share a link to this answer

Copy link [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/ "The current license for this post: CC BY-SA 4.0")

[Improve this answer](https://stackoverflow.com/posts/69055795/edit "")

Follow



Follow this answer to receive notifications

[edited Sep 4, 2021 at 19:43](https://stackoverflow.com/posts/69055795/revisions "show all edits to this post")

answered Sep 4, 2021 at 13:32

[![dshepherd's user avatar](https://www.gravatar.com/avatar/d874715650c92331b59b1ba8792ea84e?s=64&d=identicon&r=PG)](https://stackoverflow.com/users/874671/dshepherd)

[dshepherd](https://stackoverflow.com/users/874671/dshepherd) dshepherd

5,50744 gold badges4141 silver badges5050 bronze badges

6

- This looks awesome! Thanks. I was working on this a while a go, but hopefully will get a chance to test it out soon. I'll mark it as the accepted answer once I've given it a go.


– [Orphid](https://stackoverflow.com/users/3100456/orphid "2,852 reputation")

[CommentedSep 7, 2021 at 10:41](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment122102884_69055795)

- 1





It doesn't work with "internal" networks, why ?


– [Taknok](https://stackoverflow.com/users/4896841/taknok "767 reputation")

[CommentedApr 18, 2022 at 19:12](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment127079851_69055795)

- @Taknok I spent much time trying to answer the same question and came up empty handed


– [Luke Miles](https://stackoverflow.com/users/4941530/luke-miles "1,200 reputation")

[CommentedSep 12, 2023 at 0:59](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment135893346_69055795)

- 1





Oh weird, it's probably because docker uses iptables internally to implement internal networks. Whatever it does is probably incompatible with this setup. If so then to get it working you'll need different commands.


– [dshepherd](https://stackoverflow.com/users/874671/dshepherd "5,507 reputation")

[CommentedSep 12, 2023 at 6:44](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment135895115_69055795)

- @dshepherd, thanks allot for your example. I will use this as a foundation for a complete MITM setup in docker with compose. Here is the repo that proves your work. [github.com/kelvin-id/…](https://github.com/kelvin-id/workaround-for-docker-container-network-gateway-restrictions)


– [Kwuite](https://stackoverflow.com/users/3123191/kwuite "646 reputation")

[CommentedApr 2, 2024 at 23:06](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway#comment137978031_69055795)


[Use comments to ask for more information or suggest improvements. Avoid comments like “+1” or “thanks”.](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway# "Use comments to ask for more information or suggest improvements. Avoid comments like “+1” or “thanks”.") \| [Show **1** more comment](https://stackoverflow.com/questions/52595272/use-docker-container-as-network-gateway# "Expand to show all comments on this post")