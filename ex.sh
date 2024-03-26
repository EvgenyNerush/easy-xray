#!/usr/bin/env bash

# stdout styles
bold='\033[0;1m'
italic='\033[0;3m'
underl='\033[0;4m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
normal='\033[0m'

#################
### Functions ###
#################

# delete lines with comments from jsonC
jsonc2json () {
    if [ ! -v $1 ]
    then
        filename=$1
        cat $filename | grep -v \/\/
    else
        echo "${red}jsonc2json: no argument is given${red}"
        exit 1
    fi
}

# convert string with number of bytes to pretty form
bytes2MB () {
    if [ -v $1 ]
    then
        echo ""
    else
        bytes=$1
        length=${#bytes}
        if [ $length -gt 9 ]
        then
            head=${bytes::-9}
            tail=${bytes: -9}
            echo "${head}.${tail::2} GB"
        elif [ $length -gt 6 ]
        then
            head=${bytes::-6}
            tail=${bytes: -6}
            echo "${head}.${tail::2} MB"
        elif [ $length -gt 3 ]
        then
            head=${bytes::-3}
            tail=${bytes: -3}
            echo "${head}.${tail::2} kB"
        else
            echo "$bytes bytes"
        fi
    fi
}

# drop quotes (") at the start and at the end of a string
strip_quotes () {
    if [ -v $1 ] || [ ${#1} -lt 2 ]
    then
        echo ""
    else
        s=$1
        s=${s: 1} # from 1 to the end
        s=${s:: -1} # from 0 to that is before the last one
        echo $s
    fi
}

# convert json string with statistics to pretty form;
# use with pipe | to deal with multiline strings correctly!
pretty_stats () {
    read stats
    if [ -v "$stats" ]
    then
        echo ""
    else
        bytes=$(echo $stats | jq ".stat.value")
        echo "$(bytes2MB $(strip_quotes $bytes))"
    fi
}

# check if the mandatory command exists
check_command () {
    cmd=$1
    cmd_aim=$2
    comment=$3
    if command -v $cmd > /dev/null
    then
        echo -e "${green}${cmd} found${normal}"
    else
        echo -e "${red}${cmd} not found; ${cmd_aim}${normal}"
        echo -e "${comment}"
        exit 1
    fi
}

# make directory `dir`; if it already exists, first move it to dir.backup;
# if dir.backup already exists, first move it to dir.backup.backup; if it exists,
# first delete it
unsafe_mkdir () {
    dir=$1
    if [ -d "$dir" ]
    then
        if [ -d "${dir}.backup" ]
        then
            if [ -d "${dir}.backup.backup" ]
            then
                rm -r "${dir}.backup.backup"
            fi
            mv "${dir}.backup" "${dir}.backup.backup"
            [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" "${dir}.backup.backup"
        fi
        mv "$dir" "${dir}.backup"
        [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" "${dir}.backup"
    fi
    mkdir "$dir"
    [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" "${dir}"
}

# copy file to file.backup with the same logic as in `unsafe_mkdir`
cp_to_backup () {
    file=$1
    if [ -f "${file}.backup" ]
    then
        cp "${file}.backup" "${file}.backup.backup"
        [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" "${file}.backup.backup"
    fi
    cp "$file" "${file}.backup"
    [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" "${file}.backup"
}

# the main part of `./ex.sh conf` command, generates config files for server and clients
conf () {
    export PATH=$PATH:/usr/local/bin/ # brings xray to the path for sudo user
    check_command xray "needed for config generation" "to install xray, try: sudo ./ex.sh install"
    check_command jq "needed for operations with configs"
    check_command openssl "needed for strong random numbers excluding some types of attacks"
    #
    echo -e "Enter domain name to use with IPv6 and CDN (e.g. Cloudflare),
or leave blank for simple default configuration:"
    read server_name4cdn
    #
    if [ -v $server_name4cdn ]
    then
        echo -e "Enter IPv4 or IPv6 address of your xray server, or its domain name:"
    else
        check_command sed "needed to make nginx's site to use cdn"
        echo -e "Enter IPv4 address of your xray server:"
    fi
    read address
    if [ -v $address ]
    then
        echo -e "${red}no address given${normal}"
        exit 1
    fi
    id=$(xray uuid) # random uuid for VLESS
    echo -e "Generate xray private and public keys? (Y/n)"
    read answer
    if [ ! -v $answer ] && [ $answer = 'n' ]
    then
        echo -e "Enter xray private and public keys delimited by a space:"
        read answer
        private_key=$(echo $answer | cut -d " " -f 1) # get the first field of fields delimited by spaces
        public_key=$(echo $answer | cut -d " " -f 2)
    fi
    if [ -v $private_key ] || [ -v $public_key ]
    then
        keys=$(xray x25519) # string "Private key: Abc... Public key: Xyz..."
        private_key=$(echo $keys | cut -d " " -f 3) # get 3rd field of fields delimited by spaces
        public_key=$(echo $keys | cut -d " " -f 6) # get 6th field
    fi
    short_id=$(openssl rand -hex 8) # random short_id for REALITY
    #
    echo -e "Choose a fake site to mimic.
Better if it is quite popular and not blocked in your country:
(1) www.youtube.com (default)
(2) www.microsoft.com
(3) www.google.com
(4) www.bing.com
(5) www.yahoo.com
(6) www.adobe.com
(7) aws.amazon.com
(8) discord.com
(9) your variant"
    read number
    default_fake_site="www.youtube.com"
    if [ -v $number ]
    then
        fake_site=$default_fake_site
    else
        if [ $number -eq 2 ]
        then
            fake_site="www.microsoft.com"
        elif [ $number -eq 3 ]
        then
            fake_site="www.google.com"
        elif [ $number -eq 4 ]
        then
            fake_site="www.bing.com"
        elif [ $number -eq 5 ]
        then
            fake_site="www.yahoo.com"
        elif [ $number -eq 6 ]
        then
            fake_site="www.adobe.com"
        elif [ $number -eq 7 ]
        then
            fake_site="aws.amazon.com"
        elif [ $number -eq 8 ]
        then
            fake_site="discord.com"
        elif [ $number -eq 9 ]
        then
            echo -e "type your variant:"
            read fake_site
            if [ -v $fake_site ]
            then
                fake_site=$default_fake_site
            fi
        else
            fake_site=$default_fake_site
        fi
    fi
    echo -e "${green}mimic ${fake_site}${normal}"
    server_names="[ \"$fake_site\" ]"
    email="love@xray.com"
    #
    unsafe_mkdir conf
    #
    if [ -v $server_name4cdn ]
    then
        listen="0.0.0.0"
    else
        listen=$address # otherwise xray will listen also at ip6
        # grpc service name (location); letters and digits only
        echo -e "Enter grpc service name or hit Enter to autogenerate:"
        read service_name
        if [ -v ${service_name} ]
        then
            service_name=$(openssl rand -base64 9 | sed 's![^[:alnum:]]!!g')
        fi
        # config for nginx; `!` in sed allows not to escape special characters such as dot and plus sign
        cat ./template_site4cdn.conf \
            | sed "s!server_domain_name!${server_name4cdn}!" \
            | sed "s!www.youtube.com!${fake_site}!" \
            | sed "s!your_service_name!${service_name}!" \
            > ./conf/site4cdn.conf
        cp ./conf/site4cdn.conf /etc/nginx/sites-enabled/
    fi
    #
    ## Make server config ##
    jsonc2json template_config_server.jsonc \
        | jq ".inbounds[1].settings.clients[0].id=\"${id}\"
            | .inbounds[2].settings.clients[0].id=\"${id}\"
            | .inbounds[1].listen=\"${listen}\"
            | .inbounds[1].settings.clients[0].email=\"${email}\"
            | .inbounds[2].settings.clients[0].email=\"${email}\"
            | .inbounds[1].streamSettings.realitySettings.dest=\"${fake_site}:443\"
            | .inbounds[2].streamSettings.realitySettings.dest=\"${fake_site}:80\"
            | .inbounds[1].streamSettings.realitySettings.serverNames=${server_names}
            | .inbounds[2].streamSettings.realitySettings.serverNames=${server_names}
            | .inbounds[1].streamSettings.realitySettings.privateKey=\"${private_key}\"
            | .inbounds[2].streamSettings.realitySettings.privateKey=\"${private_key}\"
            | .inbounds[1].streamSettings.realitySettings.shortIds=[ \"${short_id}\" ]
            | .inbounds[2].streamSettings.realitySettings.shortIds=[ \"${short_id}\" ]
            | .inbounds[3].settings.clients[0].id=\"${id}\"
            | .inbounds[3].streamSettings.grpcSettings.serviceName=\"${service_name}\" " \
        > ./conf/config_server.json
    # make the user (not root) the owner of the file
    [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_server.json
    vnext=" [
            {
                \"address\": \"${address}\",
                \"port\": 443,
                \"users\": [
                    {
                        \"id\": \"${id}\",
                        \"email\": \"${email}\",
                        \"encryption\": \"none\",
                        \"flow\": \"xtls-rprx-vision\"
                    }
                ]
            }
        ]"
    clientRealitySettings=" {
            \"fingerprint\": \"chrome\",
            \"serverName\": \"${fake_site}\",
            \"show\": false,
            \"publicKey\": \"${public_key}\",
            \"shortId\": \"${short_id}\",
        }"
    ## Make main client config ##
    jsonc2json template_config_client.jsonc \
        | jq ".outbounds
            |= map(if .settings.vnext then .settings.vnext=${vnext} else . end)
            | .outbounds
            |= map(if .streamSettings.realitySettings then .streamSettings.realitySettings=${clientRealitySettings} else . end)" \
        > ./conf/config_client.json
    # make the user (not root) an owner of a file
    [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_client.json
    if [ -f "./conf/config_client.json" ] && [ -f "./conf/config_server.json" ]
    then
        echo -e "${green}config files are generated${normal}"
    else
        echo -e "${red}config files are not generated${normal}"
        exit 1
    fi
    ## Make main client config_cdn ##
    if [ ! -v $server_name4cdn ]
    then
        jsonc2json template_config_client_cdn.jsonc \
            | jq ".outbounds[0].settings.vnext[0].address=\"${server_name4cdn}\"
                | .outbounds[0].settings.vnext[0].users[0].id=\"${id}\"
                | .outbounds[0].streamSettings.grpcSettings.serviceName=\"${service_name}\"" \
            > ./conf/config_client_cdn.json
        # make the user (not root) an owner of a file
        [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_client_cdn.json
        if [ -f "./conf/config_client_cdn.json" ]
        then
            echo -e "${green}config_cdn file is generated${normal}"
        else
            echo -e "${red}config_cdn file is not generated${normal}"
            exit 1
        fi
    fi
}

# the main part of `./ex.sh add` command, adds config for given users and updates server config
add () {
    export PATH=$PATH:/usr/local/bin/ # brings xray to the path for sudo user
    check_command xray "needed for config generation" "to install xray, try: sudo ./ex.sh install"
    check_command jq "needed for operations with configs"
    check_command openssl "needed for strong random numbers excluding some types of attacks"
    if [ ! -f "./conf/config_client.json" ] || [ ! -f "./conf/config_server.json" ]
    then
        echo -e "${red}server config and config for default user are needed
but not present; to generate them, try
    ./ex.sh conf${normal}"
        exit 1
    fi
    if $1
    then
        resume=false
    else
        resume=true
    fi
    if [ -v $2 ]
    then
        echo -e "${red}usernames not set${normal}
For default user, use config_client.json generated
by ${underl}install${normal} command. Otherwise use non-void usernames,
preferably of letters and digits only."
        exit 1
    fi
    # backup server config
    cp_to_backup ./conf/config_server.json
    # loop over usernames
    for username in "${@:2}"
    do
        username_exists=false
        client_emails=$(jq ".inbounds[1].settings.clients[].email" ./conf/config_server.json)
        for email in ${client_emails[@]}
        do
            # convert "name@example.com" to name
            name=$(echo $email | cut -d "@" -f 1 | cut -c 2-)
            if [ $username = $name ]
            then
                username_exists=true
            fi
        done
        if $username_exists
        then
            echo -e "${yellow}username ${username} already exists is the server config,
no new config created fot it${normal}"
        else
            if $resume
            then
                if [ ! -f "./conf/config_client_$username.json" ]
                then
                    echo -e "${red}no ./conf/config_client_${username}.json found, can't resume${normal}"
                    exit 1
                fi
                id=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].users[0].id" ./conf/config_client_${username}.json))
                short_id=$(strip_quotes $(jq ".outbounds[0].streamSettings.realitySettings.shortId" ./conf/config_client_${username}.json))
                ok1=true
            else
                id=$(xray uuid) # generate random uuid for vless
                # generate random short_id for grpc-reality
                short_id=$(openssl rand -hex 8)
                # make new user config from default user config
                ok1=$(cat ./conf/config_client.json | jq ".outbounds[0].settings.vnext[0].users[0].id=\"${id}\" | .outbounds[0].settings.vnext[0].users[0].email=\"${username}@example.com\" | .outbounds[0].streamSettings.realitySettings.shortId=\"${short_id}\"" > ./conf/config_client_${username}.json)
                # then make the user (not root) an owner of a file
                [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_client_${username}.json
                if [ -f "./conf/config_client_cdn.json" ]
                then
                    cat ./conf/config_client_cdn.json | jq ".outbounds[0].settings.vnext[0].users[0].id=\"${id}\"" > ./conf/config_client_${username}_cdn.json
                [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_client_${username}_cdn.json
                fi
            fi
            # update server config
            client="
              {
                \"id\": \"${id}\",
                \"email\": \"${username}@example.com\",
                \"flow\": \"xtls-rprx-vision\"
              }
            "
            grpc_client_id="
          {
            \"id\": \"${id}\"
          }
            "
            cp ./conf/config_server.json ./conf/tmp_server_config.json
            ok2=$(cat ./conf/tmp_server_config.json | jq ".inbounds[1].settings.clients += [${client}] | .inbounds[1].streamSettings.realitySettings.shortIds += [\"${short_id}\"] | .inbounds[3].settings.clients += [${grpc_client_id}]" > ./conf/config_server.json)
            # then make the user (not root) an owner of a file
            [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_server.json
            if $ok1 && $ok2
            then
                rm ./conf/tmp_server_config.json
                if [ ! $resume ]
                then
                    echo -e "${green}config_client_${username}.json is written,${normal}"
                fi
                echo -e "${green}config_server.json is updated${normal}"
            else
                echo -e "${yellow}something went wrong with username ${username}${normal}"
                exit 1
            fi
        fi
    done
}

# `./ex.sh push` command, copies config to xray's dir and restarts xray
push () {
    if [ $(id -u) -ne 0 ] # not root
    then
        echo -e "${red}you should have root privileges for that, try
sudo ./ex.sh push${normal}"
        exit 1
    fi
    echo -e "Which config to use, server/client/other? (S/c/o)"
    read answer
    if [ ! -v $answer ] && [ ${answer::1} = "c" ]
    then
        # use main client config
        config="config_client.json"
    elif [ ! -v $answer ] && [ ${answer::1} = "o" ]
    then
        # use config of some other user
        echo -e "Which config from ./conf/ to use? (write the filename)"
        read answer
        config="$answer"
    else
        # use server config
        config="config_server.json"
    fi
    if $(cp ./conf/${config} /usr/local/etc/xray/config.json && systemctl restart xray)
    then
        sleep 1s # gives time to xray restart
        journalctl -u xray | tail -n 5 # message about xray start
    else
        echo -e "${red}can't copy config or start xray, try
sudo xray run -c ./conf/${config}${normal}"
    fi
}

echo_stats () {
    echo -e $1 | tee -a "stats.log"
}

#############
### MAIN ####
#############

command="help" # default
if [ ! -v $1 ]
then
    command=$1
fi

if [ $command = "install" ]
then
    if [ $(id -u) -ne 0 ] # not root
    then
        echo -e "${red}you should have root privileges to install xray, try
sudo ./ex.sh install${normal}"
        exit 1
    fi
    #
    if command -v xray > /dev/null # xray already installed
    then
        echo -e "${yellow}xray ${version} detected, install anyway?${normal} (y/N)"
        read answer
        # default answer, answer not set or it's first letter is not `y` or `Y`
        if [ -v $answer ] || ([ ${answer::1} != "y" ] && [ ${answer::1} != "Y" ])
        then
            exit 1
        fi
    fi
    #
    if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    then
        echo -e "${green}xray installed${normal}"
        dat_dir="/usr/local/share/xray/"
        mkdir -p $dat_dir
        if cp customgeo.dat ${dat_dir}
        then
            echo -e "${green}customgeo.dat copied to ${dat_dir}${normal}"
        else
            echo -e "${red}customgeo.dat not copied to ${dat_dir}${normal}"
            exit 1
        fi
        # for cert.pem
        mkdir -p /etc/ssl/certs/
        # for cert.key
        mkdir -p /etc/ssl/private/
        # for nginx's 'site'
        mkdir -p /etc/nginx/sites-enabled/
        #
        cp -b ./cert.pem /etc/ssl/certs/
        cp -b ./cert.key /etc/ssl/private/
        cp -b ./nginx.conf /etc/nginx/nginx.conf
    else
        echo -e "${red}xray not installed, something goes wrong${normal}"
        exit 1
    fi
    #
    echo -e "Generate configs? (Y/n)"
    read answer
    if [ ! -v $answer ] && [ ${answer::1} = "n" ]
    then
        # config generation is not requested
        echo -e "If you have a config file for xray, you can manually
start xray with the following commands:
    sudo cp yourconfig.json /usr/local/etc/xray/config.json
    sudo systemctl start xray
or
    sudo xray run -c yourconfig.json"
        exit 0
    else
        # config generation is requested
        conf
    fi
    #
    echo -e "Add other users? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        echo -e "Enter usernames separated by spaces"
        read usernames
        add true $usernames
    fi
    #
    echo -e "Copy config to xray's dir and restart xray? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        push
    fi

elif [ $command = "conf" ]
then
    conf
    #
    echo -e "Add other users? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        echo -e "Enter usernames separated by spaces"
        read usernames
        add true $usernames
    fi
    #
    echo -e "Copy config to xray's dir and restart xray? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        push
    fi

elif [ $command = "add" ] || [ $command = "resume" ]
then
    if [ $command = "add" ]
    then
        add true "${@:2}"
    else
        add false "${@:2}"
    fi
    #
    echo -e "Copy config to xray's dir and restart xray? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        push
    fi

elif [ $command = "del" ] || [ $command = "suspend" ]
then
    if [ -v $2 ]
    then
        echo -e "${red}usernames not set${normal}"
        exit 1
    fi
    check_command jq "needed for operations with configs"
    if [ ! -f "./conf/config_server.json" ]
    then
        echo -e "${red}server config not found"
        exit 1
    fi
    # backup server config
    cp_to_backup ./conf/config_server.json
    # loop over usernames
    for username in "${@:2}"
    do
        config="./conf/config_client_${username}.json"
        if [ ! -f $config ]
        then
            echo -e "${yellow}no config for user ${username}${normal}"
        else
            short_id=$(jq ".outbounds[0].streamSettings.realitySettings.shortId" $config)
            id=$(jq ".outbounds[0].settings.vnext[0].users[0].id" $config)
            cp ./conf/config_server.json ./conf/tmp_server_config.json
            # update server config
            ok1=$(cat ./conf/tmp_server_config.json | jq "del(.inbounds[1].settings.clients[] | select(.email == \"${username}@example.com\")) | del(.inbounds[1].streamSettings.realitySettings.shortIds[] | select(. == ${short_id})) | del(.inbounds[3].settings.clients[] | select(.id == ${id}))" > ./conf/config_server.json)
            # then make the user (not root) an owner of a file
            [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_server.json
            if [ $command = "del" ]
            then
                ok2=$(rm ./conf/config_client_${username}.json)
                if [ -f "./conf/config_client_${username}_cdn.json" ]
                then
                    rm ./conf/config_client_${username}_cdn.json
                fi
                if $ok1 && $ok2
                then
                    rm ./conf/tmp_server_config.json
                    echo -e "${green}config_client_${username}.json is deleted,
    config_server.json is updated${normal}"
                else
                    echo -e "${red}something went wrong with username ${username}${normal}"
                    exit 1
                fi
            else
                if $ok1
                then
                    rm ./conf/tmp_server_config.json
                    echo -e "${green}user ${username} is suspended,
config_server.json is updated${normal}"
                else
                    echo -e "${red}something went wrong with username ${username}${normal}"
                    exit 1
                fi
            fi
        fi
    done
    echo -e "Copy config to xray's dir and restart xray? (Y/n)"
    read answer
    if [ -v $answer ] || [ ${answer::1} != "n" ]
    then
        push
    fi

elif [ $command = "push" ]
then
    push

elif [ $command = "link" ]
then
    conf_file=$2
    if [ -v $conf_file ]
    then
        echo -e "${red}no config is given${normal}"
        exit 1
    fi
    if [ ! -f $conf_file ]
    then
        echo -e "${red}file ${conf_file} does not exist${normal}"
        exit 1
    fi
    check_command jq "needed for operations with configs"
    network=$(strip_quotes $(jq ".outbounds[0].streamSettings.network" $conf_file))
    if [ $network = "tcp" ] # tls-vless-reality config
    then
        id=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].users[0].id" $conf_file))
        address=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].address" $conf_file))
        if [[ $address == *":"* ]] # address contains ':', as IPv6 does
        then
            address="[${address}]"
        fi
        port=$(jq ".outbounds[0].settings.vnext[0].port" $conf_file)
        public_key=$(strip_quotes $(jq ".outbounds[0].streamSettings.realitySettings.publicKey" $conf_file))
        server_name=$(strip_quotes $(jq ".outbounds[0].streamSettings.realitySettings.serverName" $conf_file))
        short_id=$(strip_quotes $(jq ".outbounds[0].streamSettings.realitySettings.shortId" $conf_file))
        link="vless://${id}@${address}:${port}?fragment=&security=reality&encryption=none&pbk=${public_key}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${server_name}&sid=${short_id}#easy-xray+%F0%9F%97%BD"
    else # grpc config
        id=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].users[0].id" $conf_file))
        address=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].address" $conf_file))
        service_name=$(strip_quotes $(jq ".outbounds[0].streamSettings.grpcSettings.serviceName" $conf_file))
        link="vless://${id}@${address}:443?security=tls&encryption=none&type=grpc&serviceName=${service_name}#easy-xray+%F0%9F%97%BD+CDN"
    fi
    echo -e "${yellow}don't forget to share misc/customgeo4hiddify.txt or misc/customgeo4nekoray.txt as well
${green}here is your link:${normal}"
    echo $link

elif [ $command = "stats" ]
then
    client_stats_proxy_down=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>proxy>>>traffic>>>downlink" 2> /dev/null)
    server_stats_direct_down=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>direct>>>traffic>>>downlink" 2> /dev/null)
    if [ ! -z "$client_stats_proxy_down" ] # output is not a zero string, hence script is running on a client
    then
        ## Client statistics ##
        echo "" >> "stats.log"
        echo "----------" >> "stats.log"
        date >> "stats.log"
        echo_stats "Downloaded via server: $(echo $client_stats_proxy_down | pretty_stats)"
        #
        client_stats_proxy_up=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>proxy>>>traffic>>>uplink" 2> /dev/null)
        echo_stats "Uploaded via server: $(echo $client_stats_proxy_up | pretty_stats)"
        #
        client_stats_direct_down=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>direct>>>traffic>>>downlink" 2> /dev/null)
        echo_stats "Downloaded via client directly: $(echo $client_stats_direct_down | pretty_stats)"
        #
        client_stats_direct_up=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>direct>>>traffic>>>uplink" 2> /dev/null)
        echo_stats "Uploaded via client directly: $(echo $client_stats_direct_up | pretty_stats)"
    elif [ ! -z "$server_stats_direct_down" ] # output is not a zero string, hence script is running on a server
    then
        ## Server statistics ##
        echo "" >> "stats.log"
        echo "----------\n" >> "stats.log"
        date >> -a "stats.log"
        echo_stats "Downloaded in total: $(echo $server_stats_direct_down | pretty_stats)"
        #
        server_stats_direct_up=$(xray api stats -server=127.0.0.1:8080 -name "outbound>>>direct>>>traffic>>>uplink" 2> /dev/null)
        echo_stats "Uploaded in total: $(echo $server_stats_direct_up | pretty_stats)"
        #
        # Per user statistics
        conf_file="./conf/config_server.json" # assuming xray is running with this config
        qemails=$(cat $conf_file | jq ".inbounds[1].settings.clients[].email")
        for qemail in ${qemails[@]}
        do
            echo_stats ""
            email=$(strip_quotes $qemail)
            user_stats_down=$(xray api stats -server=127.0.0.1:8080 -name "user>>>${email}>>>traffic>>>downlink" 2> /dev/null)
            echo_stats "Downloaded by ${email}: $(echo $user_stats_down | pretty_stats)"
            user_stats_up=$(xray api stats -server=127.0.0.1:8080 -name "user>>>${email}>>>traffic>>>uplink" 2> /dev/null)
            echo_stats "Uploaded by ${email}: $(echo $user_stats_up | pretty_stats)"
        done
    else
        echo -e "${red}xray should be running to aquire or reset statistics${normal}"
        exit 1
    fi
    #
    if [ ! -v $2 ] && [ $2 = "reset" ]
    then
        echo ""
        xray api statsquery -server=127.0.0.1:8080 -reset > /dev/null \
            && echo -e "${green}statistics reset successfully${normal}" \
            || echo -e "${red}statistics reset failed${normal}"
    fi

elif [ $command = "import" ]
then
    if [ -v $2 ] || [ -v $3 ]
    then
        echo -e "${red}both directories (from and to) should be set${normal}"
        exit 1
    fi
    from=$2
    to=$3
    # backup the server and the main client configs
    cp_to_backup ${to}/config_server.json
    #
    configs="${from}/config_client_*.json"
    for c in $configs
    do
        if [ -f $c ]
        then
            uname_with_json=$(echo $c | cut -d "_" -f 3-) # remove "config_client_"
            uname_from_filename=${uname_with_json:: -5} # remove ".json"
            email=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].users[0].email" $c))
            uname_from_email=${email%@*} # remove "@example.com"
            if [ $uname_from_filename != $uname_from_email ]
            then
                echo -e "${yellow}username ${uname_from_filename} (from filename) inconsistent with username ${uname_from_email} (from email),
    continue with name from email${normal}"
            fi
            if [ -f ${to}/config_client_${uname_from_email}.json ] # username already exists
            then
                echo -e "${yellow}username ${uname_from_email} already exists in ${to}, no new config created fot it${normal}"
            else
                id=$(strip_quotes $(jq ".outbounds[0].settings.vnext[0].users[0].id" $c))
                short_id=$(strip_quotes $(jq ".outbounds[0].streamSettings.realitySettings.shortId" $c))
                # make new user config
                ok1=$(cat ${to}/config_client.json | jq ".outbounds[0].settings.vnext[0].users[0].id=\"${id}\" | .outbounds[0].settings.vnext[0].users[0].email=\"${uname_from_email}@example.com\" | .outbounds[0].streamSettings.realitySettings.shortId=\"${short_id}\"" > ${to}/config_client_${uname_from_email}.json)
                # then make the user (not root) an owner of a file
                [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ${to}/config_client_${uname_from_email}.json
                #
                if [ -f "./conf/config_client_cdn.json" ]
                then
                    cat ./conf/config_client_cdn.json | jq ".outbounds[0].settings.vnext[0].users[0].id=\"${id}\"" > ./conf/config_client_${uname_from_email}_cdn.json
                [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ./conf/config_client_${username}_cdn.json
                fi
                # update server config
                client="
                  {
                    \"id\": \"${id}\",
                    \"email\": \"${uname_from_email}@example.com\",
                    \"flow\": \"xtls-rprx-vision\"
                  }
                "
                grpc_client_id="
          {
            \"id\": \"${id}\"
          }
                "
                cp ${to}/config_server.json ${to}/tmp_server_config.json
                ok2=$(cat ${to}/tmp_server_config.json | jq ".inbounds[1].settings.clients += [${client}] | .inbounds[1].streamSettings.realitySettings.shortIds += [\"${short_id}\"] | .inbounds[3].settings.clients += [${grpc_client_id}]" > ${to}/config_server.json)
                # then make the user (not root) an owner of a file
                [[ $SUDO_USER ]] && chown "$SUDO_USER:$SUDO_USER" ${to}/config_server.json
                if $ok1 && $ok2
                then
                    rm ${to}/tmp_server_config.json
                    echo -e "${green}${to}/config_client_${uname_from_email}.json is written, ${to}/config_server.json is updated${normal}"
                else
                    echo -e "${yellow}something went wrong with username ${uname_from_email}${normal}"
                    exit 1
                fi
            fi
        fi
    done

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
    read answer
    if [ ! -v $answer ] && [ ${answer::1} = "y" ]
    then
        if [ $(id -u) -ne 0 ] # not root
        then
            echo -e "${red}you should have root privileges for that, try
sudo ./ex.sh push${normal}"
            exit 1
        fi
        if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
        then
            echo -e "${green}xray removed${normal}"
        else
            echo -e "${red}xray not removed${normal}"
        fi
    fi

else # "help", default
    echo -e "
${green}**** Hi, there! ****${normal}

The aim of ${italic}easy-xray${normal} is to help to administrate an xray server.
It's all about ${italic}conf${normal} directory that contains the server config
${italic}config_server.json${normal}, the main client config ${italic}config_client.json${normal} and
configs for other users ${italic}config_client_*.json${normal}. How to use it:

    ${bold}./ex.sh ${underl}command${normal}

Here is a list of all the commands available:

    ${bold}help${normal}            show this message (default)
    ${bold}install${normal}         run interactive prompt, that asks to download and
                    install XRay, and to generate configs
    ${bold}conf${normal}            generate config files for server and clients  
    ${bold}add ${underl}usernames${normal}   add users with given usernames to configs,
                    usernames should by separated by spaces
    ${bold}del ${underl}usernames${normal}   delete users with given usernames from configs
    ${bold}suspend ${underl}usernames${normal} delete users with given usernames from the server config
                      but don't delete the user configs
    ${bold}resume ${underl}usernames${normal}  add users from suspended configs to the server config
    ${bold}push${normal}            copy config to xray's dir and restart xray
    ${bold}link ${underl}config${normal}     convert user config to a link acceptable by
                    client applications such as Hiddify or V2ray
    ${bold}stats${normal}           print some traffic statistics and write to stats.log
    ${bold}stats reset${normal}     print statistics then set them to zero
    ${bold}import ${underl}from${normal} ${underl}to${normal}  import users from one directory that contains
                    user configs to another directory that contains
                    server config and the main client config
    ${bold}upgrade${normal}         upgrade xray, do not touch configs
    ${bold}remove${normal}          remove xray"
fi

