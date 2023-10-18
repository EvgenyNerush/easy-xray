# easy-xray

*Script for Linux which make XRay installation and configuration easy.*

(todo) [Readme in Russian](README.ru.md)

[XRay (aka ProjectX)](https://xtls.github.io/en/) is a frontier solution to surpass the internet censorship. It can work as a server and as
a client, but it's configuration sometimes confusing for a newbie. So, here is a scripts which help

- install(todo /uninstall/update) *XRay*
- generate credentials and server/client config
- (todo) add/delete user and update config

First make the script `ex.sh` executable, then run it with a desired command. Use `./ex.sh help` to see the list of all available commands
and `./ex.sh all` to start interactive prompt which installs and configures *XRay*.
```
$ chmod +x ex.sh
$ ./ex.sh help
$ sudo ./ex.sh all
```

### Prerequisites

For manipulations with configs, [jq](https://jqlang.github.io/jq/) is needed, it can be found in repositories of almost all popular Linux
distributives.

### Acknowledgements

[This article (in Russian)](https://habr.com/ru/articles/731608/) helped me install *XRay* for the first time.
[XRay config reference](https://xtls.github.io/en/config/) is brilliant and helped me much.

(TODO) about, reality-vless, domains, browser settings, no encription(!), choose domain names or geoip
