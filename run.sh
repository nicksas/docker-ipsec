#!/bin/bash





echo '
Public DNS servers include:

176.103.130.130,176.103.130.131  AdGuard               https://adguard.com/en/adguard-dns/overview.html
176.103.130.132,176.103.130.134  AdGuard Family        https://adguard.com/en/adguard-dns/overview.html
1.1.1.1,1.0.0.1                  Cloudflare/APNIC      https://1.1.1.1
84.200.69.80,84.200.70.40        DNS.WATCH             https://dns.watch
8.8.8.8,8.8.4.4                  Google                https://developers.google.com/speed/public-dns/
208.67.222.222,208.67.220.220    OpenDNS               https://www.opendns.com
208.67.222.123,208.67.220.123    OpenDNS FamilyShield  https://www.opendns.com
9.9.9.9,149.112.112.112          Quad9                 https://quad9.net
77.88.8.8,77.88.8.1              Yandex                https://dns.yandex.com
77.88.8.88,77.88.8.2             Yandex Safe           https://dns.yandex.com
77.88.8.7,77.88.8.3              Yandex Family         https://dns.yandex.com
'

VPN_DNS=${VPN_DNS:-'8.8.8.8,8.8.4.4'}

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
onespace() { printf '%s' "$1" | tr -s ' '; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }
noquotes2() { printf '%s' "$1" | sed -e 's/" "/ /g' -e "s/' '/ /g"; }

VPN_USERS=$(nospaces "$VPN_USERS")
VPN_USERS=$(noquotes "$VPN_USERS")
VPN_USERS=$(onespace "$VPN_USERS")
VPN_USERS=$(noquotes2 "$VPN_USERS")
VPN_PASSWORDS=$(nospaces "$VPN_PASSWORDS")
VPN_PASSWORDS=$(noquotes "$VPN_PASSWORDS")
VPN_PASSWORDS=$(onespace "$VPN_PASSWORDS")
VPN_PASSWORDS=$(noquotes2 "$VPN_PASSWORDS")
if [ -n "$VPN_DNS" ]; then
  VPN_DNS=$(nospaces "$VPN_DNS")
  VPN_DNS=$(noquotes "$VPN_DNS")
fi


files=("cacerts/ca-cert.pem" "certs/server-cert.pem" "private/server-key.pem")

# Check if any of the files do not exist
for file in "${files[@]}"; do
    if [ ! -f "/etc/ipsec.d/$file" ]; then
        echo "Required file $file not found. Running generate-cert.sh..."
        /usr/local/bin/generate-cert.sh
        break
    fi
done

if [ -z "$VPN_PASSWORDS" ] || [ -z "$VPN_PASSWORDS" ]; then
  exiterr "All VPN credentials must be specified. Edit your 'env' file and re-enter them."
fi

case "$VPN_USERS $VPN_PASSWORDS" in
  *[\\\"\']*)
    exiterr "VPN credentials must not contain these special characters: \\ \" '"
    ;;
esac

if printf '%s' "$VPN_USERS" | tr ' ' '\n' | sort | uniq -c | grep -qv '^ *1 '; then
  exiterr "VPN usernames must not contain duplicates."
fi


if ip link add dummy0 type dummy 2>&1 | grep -q "not permitted"; then
cat 1>&2 <<'EOF'
Error: This Docker image should be run in privileged mode.
EOF
  exit 1
fi

ip link delete dummy0 >/dev/null 2>&1

NET_IFACE=$(route 2>/dev/null | grep -m 1 '^default' | grep -o '[^ ]*$')
[ -z "$NET_IFACE" ] && NET_IFACE=$(ip -4 route list 0/0 2>/dev/null | grep -m 1 -Po '(?<=dev )(\S+)')
[ -z "$NET_IFACE" ] && NET_IFACE=eth0

# Create VPN configuration file
cat > /etc/ipsec.conf <<EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=start
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=restart
    dpddelay=30
    dpdtimeout=300
    ikelifetime=1h
    lifetime=8h
    rekey=no
    left=%any
    leftid=$VPN_PUBLIC_IP
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=$VPN_DNS
    rightsendcert=never
    eap_identity=%identity
    ike=aes256gcm16-prfsha384-ecp384,aes256-aes128-sha256-sha1-modp2048-modp4096-modp1024!
    esp=aes256gcm16-ecp384,aes128-aes256-sha1-sha256-modp2048-modp4096-modp1024!

EOF

/usr/local/bin/update-secrets.sh

# Update sysctl settings
syt='sysctl -e -q -w'
$syt net.ipv4.ip_forward=1 2>/dev/null
$syt net.ipv4.conf.all.accept_redirects=0 2>/dev/null
$syt net.ipv4.conf.all.send_redirects=0 2>/dev/null
$syt net.ipv4.ip_no_pmtu_disc=1 2>/dev/null

# Reload sysctl configurations
sysctl -p

#set up ip forward
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# iptables -A INPUT -p tcp --dport 52525 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
#allow IKE traffic
iptables -A INPUT -p udp --dport  500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
#allow forward ESP traffic
iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT
#setting up ip masquerading
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o "$NET_IFACE" -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o "$NET_IFACE" -j MASQUERADE
#set_mss (tcpmss)
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o "$NET_IFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
# iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP

sleep infinity