#!/usr/bin/env bash

bold='\033[0;1m'
underl='\033[0;4m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
normal='\033[0m'

export PATH=$PATH:/usr/local/bin/ # for sudo user this can be not in PATH
if command -v xray > /dev/null
then
    xray_version=$(xray --version | head -n 1 | cut -c 6-10)
    echo -e "${yellow}xray ${xray_version} detected${normal}"
fi

if command -v jq > /dev/null
then
    jq_installed=true
    echo -e "${green}jq found${normal}"
else
    jq_installed=false
    echo -e "${red}Warning: jq not installed but needed for operations with configs${normal}"
fi

if [ $(id -u) -eq 0 ]
then
    is_root=true
    echo -e "${green}running as root${normal}"
else
    is_root=false
    echo -e "${red}Warning: you should be root to install xray${normal}"
fi

command="help"
if [ ! -v $1 ]
then
    command=$1
fi

if [ $command = "install" ]
then

    echo -e "${bold}Download and install xray?${normal} (Y/n)"
    read answer_di
    if [ -v $answer_di ] || [ $(echo $answer_di | cut -c 1) != "n" ]
    then
        install_xray=true
        if command -v xray > /dev/null
        then
            echo -e "xray ${version} detected, install anyway? (y/N)"
            read answer_ia
            if [ -v $answer_ia ] || ([ $(echo $answer_ia | cut -c 1) != "y" ] && [ $(echo $answer_ia | cut -c 1) != "Y" ])
            then
                install_xray=false
            fi
        fi
        if $install_xray
        then
            if $is_root
            then
                if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
                then
                    mkdir -p /var/log/xray
                    touch /var/log/xray/error.log
                    echo -e "${green}xray installed${normal}"
                else
                    echo -e "${red}xray not installed, something goes wrong${normal}"
                fi
            else
                echo -e "${red}You should be root, or run this script with sudo
to install xray${normal}"
                exit 1
            fi
        fi
    fi

    echo -e "${bold}Generate configs?${normal} (Y/n)"
    read answer_gc
    if [ -v $answer_gc ] || [ $(echo $answer_gc | cut -c 1) != "n" ]
    then
        if ! $(command -v xray > /dev/null)
        then
            echo -e "${red}xray not installed, can't generate configs"
            exit 1
        fi
        if ! $jq_installed
        then
            echo -e "${red}jq not installed, can't generate configs"
            exit 1
        else
            echo -e "${bold}Enter IPv4 or IPv6 address of your xray server, or its domain name:${normal}"
            read address
            id=$(xray uuid)
            keys=$(xray x25519)
            private_key=$(echo $keys | cut -d " " -f 3)
            public_key=$(echo $keys | cut -d " " -f 6)
            if command -v openssl > /dev/null
            then
                short_id=$(openssl rand -hex 8)
            else
                echo -e "Enter a random (up to) 16-digit hex number,
containing only digits 0-9 and letters a-f, for instance
1234567890abcdef"
                read short_id
                if [ -v $short_id ]
                then
                    echo -e "${red}short id not set${normal}"
                    exit 1
                fi
            fi
            echo -e "${bold}Choose a fake site to mimic.${normal}
It is better if it is hosted by your VPS provider
or is in the same country. Better if it is popular.
(1) www.yahoo.com (default)
(2) www.microsoft.com
(3) www.google.com
(4) www.nvidia.com
(5) www.amd.com
(6) www.samsung.com
(7) your variant"
            read number
            if [ ! -v $number ]
            then
                if [ $number -eq 2 ]
                then
                    fake_site="www.microsoft.com"
                elif [ $number -eq 3 ]
                then
                    fake_site="www.google.com"
                elif [ $number -eq 4 ]
                then
                    fake_site="www.nvidia.com"
                elif [ $number -eq 5 ]
                then
                    fake_site="www.amd.com"
                elif [ $number -eq 6 ]
                then
                    fake_site="www.samsung.com"
                elif [ $number -eq 7 ]
                then
                    echo -e "type your variant:"
                    read fake_site
                    if [ -v $fake_site ]
                    then
                        fake_site="www.yahoo.com"
                    fi
                else
                    fake_site="www.yahoo.com"
                fi
            else
                fake_site="www.yahoo.com"
            fi
            echo -e "${green}mimic ${fake_site}${normal}"
            email="love@xray.com"
            clients=" [
                    {
                        \"id\": \"${id}\",
                        \"email\": \"${email}\",
                        \"flow\": \"\"
                    }
                ]"
            serverRealitySettings=" {
                    \"show\": false,
                    \"dest\": \"${fake_site}:443\",
                    \"xver\": 0,
                    \"serverNames\": [ \"${fake_site}\" ],
                    \"privateKey\": \"${private_key}\",
                    \"shortIds\": [ \"${short_id}\" ]
                }"
            # make server config
            cat template_config_server.json | jq ".inbounds[].settings.clients=${clients} | .inbounds[].streamSettings.realitySettings=${serverRealitySettings}" > config_server.json

            vnext=" [
                    {
                        \"address\": \"${address}\",
                        \"port\": 50051,
                        \"users\": [
                            {
                                \"id\": \"${id}\",
                                \"alterId\": 0,
                                \"email\": \"${email}\",
                                \"security\": \"auto\",
                                \"encryption\": \"none\",
                                \"flow\": \"\"
                            }
                        ]
                    }
                ]"
            clientRealitySettings=" {
                    \"serverName\": \"${fake_site}\",
                    \"fingerprint\": \"chrome\",
                    \"show\": false,
                    \"publicKey\": \"${public_key}\",
                    \"shortId\": \"${short_id}\",
                    \"spiderX\": \"\"
                }"
            # make main client config
            cat template_config_client.json | jq ".outbounds |= map(if .settings.vnext then .settings.vnext=${vnext} else . end) | .outbounds |= map(if .streamSettings.realitySettings then .streamSettings.realitySettings=${clientRealitySettings} else . end)" > config_client.json
        fi
    fi

elif [ $command = "add" ]
then
    echo -e "TODO"

elif [ $command = "del" ]
then
    echo -e "TODO"

elif [ $command = "upgrade" ]
then
    if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    then
        echo -e "${green}xray upgraded${normal}"
    else
        echo -e "${red}xray not upgraded${normal}"
    fi

elif [ $command = "remove" ]
then
    echo -e "Remove xray? (y/N)"
    read answer_rx
    if [ ! -v $answer_rx ] && ([ $(echo $answer_rx | cut -c 1) = "y" ] || [ $(echo $answer_rx | cut -c 1) = "Y" ])
    then
        echo -e "${red}Please type YES to remove${normal}"
        read answer_y
        if [ ! -v $answer_y ] && ([ $answer_y = "YES" ] || [ $answer_y = "yes" ])
        then
            if $is_root
            then
                if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
                then
                    echo -e "${green}xray removed${normal}"
                else
                    echo -e "${red}xray not removed${normal}"
                fi
            else
                echo -e "${red}You should be root, or run this script with sudo
to remove xray${normal}"
                exit 1
            fi
        fi
    fi

else # "help", default
    echo -e "
${green}**** Hi, there! How to use: ****${normal}

    ${bold}./ex.sh ${underl}command${normal}

Here is the list of all available commands:

    ${bold}help${normal}            show this message (default)
    ${bold}install${normal}         run interactive prompt, which asks to download and install
                    XRay and generate configs for server and client
    ${bold}add ${underl}username${normal}    add user with (any, fake) username to configs
    ${bold}del ${underl}username${normal}    delete user with given username from configs
    ${bold}upgrade${normal}         upgrade xray, do not touch configs
    ${bold}remove${normal}          remove xray"
fi

echo -e "
Command is done.

${bold}Important:${normal} It is assumed that configs are stored and updated
locally as config_server.json, config_client.json or
config_client_username.json files. You should manually
start XRay with one of configs, depending
which role - server or client - XRay should play:
    sudo cp config_(role).json /usr/local/etc/xray/config.json
    sudo systemctl start xray
or
    sudo xray run -c config_(role).json

${bold}Important:${normal} Only warnings and errors are logged
by xray for current configs. For logs, see stdout or try
    journalctl -u xray
"

