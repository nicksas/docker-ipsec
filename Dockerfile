
FROM debian:bookworm-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/src
ENV ORG_NAME="Custom Name"
ENV VPN_USERS=""
ENV VPN_PASSWORDS=""
ENV VPN_PUBLIC_IP=""
# Update and install necessary packages
RUN apt-get -yqq update && apt-get -yqq  --no-install-recommends install \
    strongswan \
    wget nano dnsutils openssl ca-certificates kmod iproute2 net-tools procps \
    strongswan-pki \
    libssl-dev \
    libcharon-extra-plugins \
    libcharon-extauth-plugins \
    libstrongswan-standard-plugins \
    strongswan-libcharon \
    iptables \
    && update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && rm -rf /var/lib/apt/lists/*

# Copy the setup script into the container
COPY run.sh /usr/local/bin/run.sh
COPY generate-cert.sh /usr/local/bin/generate-cert.sh
COPY update-secrets.sh /usr/local/bin/update-secrets.sh

# Make the script executable
RUN chmod +x /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/generate-cert.sh
RUN chmod +x /usr/local/bin/update-secrets.sh

EXPOSE 500/udp 4500/udp

# Run the setup script
CMD ["/usr/local/bin/run.sh"]