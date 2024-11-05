echo -e "Read carefully throughout this script and correct it for your needs.
Then run it as root. Are you ready? (y/N)"
read ready
# default answer: answer not set or it's first letter is not `y` or `Y`
if [ -v $ready ] || ([ ${ready::1} != "y" ] && [ ${ready::1} != "Y" ])
then
    exit 1
fi

## Add user to system ##
echo -e "Enter username if you want to create new user or
add existing user to 'wheel' group; enter nothing to skip"
read username
if [ ! -v $username ]
then
    if ! getent passwd $username >/dev/null # user doesn't exist yet
    then
        useradd -m $username
        password=$(openssl rand -base64 9)
        echo -e "password\npassword" | passwd $username --stdin
    fi
    # if wheel group exists, add the user to it
    if getent group wheel > /dev/null
    then
        usermod -aG wheel $username
    else
        no_wheel=true
    fi
fi

## Configure ssh ##
echo -e "Enter new ssh port (> 1024 and < 65535)"
read port
if [ ! -v $port ]
then
    if ss -tunlp | grep :${port} > /dev/null
    then
        echo -e "port ${port} is already in use, aborting"
        exit 1
    else
        ssh_port=$port
        # sometimes port 22 is already commented in config,
        # but 22 port can be needed if new port is not available
        echo "Port 22" | tee -a /etc/ssh/sshd_config
        echo "Port ${port}" | tee -a /etc/ssh/sshd_config
        sshd -t && systemctl restart sshd
    fi
else
    echo -e "sshPort not set, aborting"
    exit 1
fi

## Configure firewall ##
if [ $(command -v firewall-cmd > /dev/null) ] && [ $(firewall-cmd --state) = "running" ]
then
    firewall-cmd --list-all
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=${ssh_port}/tcp
    firewall-cmd --reload
fi

## Configure SELinux ##
command -v semanage > /dev/null && semanage port -a -t ssh_port_t -p tcp ${ssh_port}

## for podman ##
# allow user apps (including podman) use ports from 80 and above
echo "net.ipv4.ip_unprivileged_port_start=80" > /etc/sysctl.d/unprivileged-ports.conf
sysctl --system
if [ -v $username ]
then
    echo -e "Enter username for which to enable long-running services"
    read username
fi
# allow non-logged user to run long-running services, such as podman container
if [ ! -v $username ]
then
    loginctl enable-linger $username
else
    echo -e "username not set, aborting"
    exit 1
fi

## Summary ##
echo -e "
---- Summary ----
"
if [ ! -v $password ]
then
    echo -e "New user ${username} is created with password:
    ${password}
don't forget to change it with
    passwd ${username}
"
fi

echo -e "Check that ssh is available at port ${ssh_port} then close
port 22 commenting line(s)
    Port 22
in /etc/ssh/sshd_config and running
    systemctl restart sshd
"

echo -e "Then you are ready to log out from the server, then log in as ${username}
with new ssh port ${ssh_port}.
"

