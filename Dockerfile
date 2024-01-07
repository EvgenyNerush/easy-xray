FROM almalinux:latest

WORKDIR /easy-xray

COPY ex.sh .
RUN chmod +x ex.sh
COPY template_config_client.jsonc .
COPY template_config_server.jsonc .
COPY customgeo.dat .

RUN dnf update --assumeyes
RUN dnf install --assumeyes jq openssl

# Ports
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["bash"]
