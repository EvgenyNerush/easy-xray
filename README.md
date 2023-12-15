# easy-xray

*Script for Linux which makes XRay management easy*

(todo) [Readme in Russian](README.ru.md)

(todo) [Readme in Chinese](README.cn.md)

[XRay (aka ProjectX)](https://xtls.github.io/en/) is a frontier solution to circumvent the internet censorship. XRay allows to guide traffic
through a server (VPS) outside the region of censorship as a proxie, but connection to xray server looks for authorities as a typical
connection to a regular website. Attempts to detect VPN such as [active probing](https://ensa.fi/active-probing/) or blocking by the rule
"all except https" are eliminated by XRay.  Also, XRay server can be configured to open only foreign websites, thus preventing detection by
the code on domestic websites.  As a proxy, XRay has no need to encrypt already encrypted https traffic, hence CPU load is low. XRay doesn't
need to keep the connection alive, and users don't need to manually reconnect to it time-to-time. Also users don't need to turn a client off
to go to most domestic websites.

![xray-schematic: traffic to foreign websites goes through vps, traffic to domestic sites goes directly from pc](figs/xray-schematic.png)

Besides of its plusses, configuration and management of XRay server is quite sophisticated. So, here is a script which helps to do it. It
can

- install/upgrade/remove XRay
- generate credentials and server/client configs
- add/delete users to the configs
- and more

### How to use on VPS

First you need a Linux server (VPS) with [jq](https://jqlang.github.io/jq/) and `openssl` installed, they can be found in repositories of
almost all popular Linux distributions. Then download whole `easy-xray` folder to the VPS, make the script `ex.sh` executable, and run a
desired command with it. Use `./ex.sh help` to see the list of all available commands and `./ex.sh install` to start interactive prompt
that installs and configures XRay.

```
chmod +x ex.sh
./ex.sh help
sudo ./ex.sh install
```

Now you have `conf` folder with server and client configs and some user configs. Server config is properly installed and XRay is running.
Time to share configs or *links* with users! To generate config in the link form, use `./ex.sh link user_config_file.json`.

### Clients

#### Linux

XRay itself can be a client, besides plenty of GUI clients that are available for other popular operating systems (see below). You can
manually install XRay with [official script](https://github.com/XTLS/Xray-install) and manually copy `customgeo.dat` to
`/usr/local/share/xray/` or just install them both with `sudo ./ex.sh install` command. Then, copy client config from the server and run:

```
sudo cp config_client_username.json /usr/local/etc/xray/config.json
sudo systemctl start xray
```

or

```
sudo xray run -c config_client_username.json
```

In the current configuration, on the client side XRay creates http/https and socks5 proxies on your PC which can be used by your Telegram
app or Web browser like this:

![browser proxy: http/https proxy 127.0.0.1 at port 801, socks v5 host 127.0.0.1 at port 800](figs/browser-proxy-settings.png)

To check that traffic to domestic and foreing sites goes by different ways, visit, for example,
[whatismyip.com](https://www.whatismyip.com/) and [2ip.ru](https://2ip.ru/). They should show different IP addressess.

#### Windows

Use [Nekoray (Nekobox)](https://github.com/MatsuriDayo/nekoray) client that releases can be found on [this
page](https://github.com/MatsuriDayo/nekoray/releases). Choose one of Assets, for instance `nekoray-3.26-2023-12-09-windows64.zip`, download
then unzip it and run Nekoray. The following configuration is [quite easy (RU)](Nekoray.ru.md).

#### MacOS

Use XRay:

```
brew install xray
cp customgeo.dat /usr/local/share/xray/ # not yet tested
sudo xray -config=config_client_username.json
```

#### Android

For many mobile applications it is enough to paste a client config in a link form from the buffer, and add customgeo in an appropriate form
(see `misc` dir) to somethere like `Settings/Routing/Custom rules/Direct URL`. Tested applications are listed below.

Use [V2RayNG](https://play.google.com/store/apps/details?id=com.v2ray.ang&pcampaignid=web_share),
[HiddifyNG](https://play.google.com/store/apps/details?id=ang.hiddify.com&pcampaignid=web_share) or [Hiddify
Next](https://play.google.com/store/apps/details?id=app.hiddify.com&pcampaignid=web_share). They are very similar to each other, here are
some instructions for [V2RayNG (RU)](V2RayNG.ru.md) and [HiddifyNG (EN)](HiddifyNG.en.md).

#### iOS

Use [Straisand](https://apps.apple.com/us/app/streisand/id6450534064). Its configuration is very similar to that of V2Ray and Hiddify (see
above). Manual copy-paste from json config file is also possible. (customgeo not yet tested)

#### Others

[Here](https://github.com/xtls/xray-core) you can find an additional list of clients.

### Tor

Most of GUI clients are based on xray core, but do not fully support its configuration, that is crutial for Tor. To use
[TorBrowser](https://www.torproject.org/download/) in this case, use bridges. To get a bridge, send a letter to bridges@torproject.org, then
copy symbols after `obfs4` and paste them to TorBrowser bridge settings.

### Bittorrent

Bittorent protocol is blocked in the current configuration. Using bittorent on a VPS can lead to a ban from VPS provider.

### Futher reading

Template configs contain comments and links and are a good start to find another interesting Xray configuration options.

See [this link](https://github.com/EvgenyNerush/coherence-grabber) for details on how `customgeo` files are generated.

[This article (in Russian)](https://habr.com/ru/articles/731608/) helped me to install XRay for the first time.

The template configs are based on these [gRPC](https://github.com/XTLS/Xray-examples/tree/main/VLESS-gRPC-REALITY)
and [XTLS](https://github.com/XTLS/Xray-examples/tree/main/VLESS-TCP-XTLS-Vision-REALITY) examples.

[XRay config reference](https://xtls.github.io/en/config/) is brilliant and helped me much.

