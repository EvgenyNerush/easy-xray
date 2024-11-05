echo -e "Read carefully throughout this script and correct it for your needs.
Then run it as root. Are you ready? (y/N)"
read ready
# default answer: answer not set or it's first letter is not `y` or `Y`
if [ -v $ready ] || ([ ${ready::1} != "y" ] && [ ${ready::1} != "Y" ])
then
    exit 1
fi

dnf update --assumeyes

# - vim is a cool text editor
# - iproute is needed for `ss` command, to see which ports are already in use
# - you need podman if plan to use Cloudflare CDN
# - jq and openssl are needed for easy-xray
dnf install --assumeyes podman openssl jq vim iproute
