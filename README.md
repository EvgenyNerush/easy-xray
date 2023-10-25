# easy-xray

*Script for Linux which makes XRay installation and configuration easy.*

(todo) [Readme in Russian](README.ru.md)
(todo) [Readme in Chinese](README.cn.md)

[XRay (aka ProjectX)](https://xtls.github.io/en/) is a frontier solution to surpass the internet censorship. It can work as a server and as
a client, but it's configuration sometimes confusing for a newcomer. So, here is a script which helps to

- install/uninstall (todo: upgrade) *XRay*
- generate credentials and server/client configs
- (todo) add/delete users to the configs

First make the script `ex.sh` executable, then run it with a desired command. Use `./ex.sh help` to see the list of all available commands
and `./ex.sh install` to start interactive prompt which installs and configures *XRay*.
```
$ chmod +x ex.sh
$ ./ex.sh help
$ sudo ./ex.sh install
```

### Prerequisites

For manipulations with configs, [jq](https://jqlang.github.io/jq/) is needed, it can be found in repositories of almost all popular Linux
distributives.

### How it works

With current configs, *XRay* creates a [grpc](https://en.wikipedia.org/wiki/GRPC) tunnel between the client (your laptop, phone etc.) and
the server (your VPS). For the censor the tunnel looks like a usual connection to a site. The server responses to https requests as some
popular site thus it is not suspicious for an active probing. On the client side *XRay* creates a socks proxy which can be used by your
web browser, telegram or TorBrowser like that:

![browser proxy: http/https proxy 127.0.0.1 at port 801, socks v5 host 127.0.0.1 at port 800](browser-proxy-settings.png)

### Acknowledgements

[This article (in Russian)](https://habr.com/ru/articles/731608/) helped me to install *XRay* for the first time.
[XRay config reference](https://xtls.github.io/en/config/) is brilliant and helped me much.
[Configs](https://github.com/XTLS/Xray-examples/tree/main/VLESS-gRPC-REALITY) on which the template configs are based.

(TODO) about, reality-vless, domains, browser settings, no encription(!), choose domain names or geoip, configs for phone...
