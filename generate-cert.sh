#!/bin/bash

echo "Start generation certificates with generate-cert.sh..."

mkdir -p ~/tmp/{cacerts,certs,private}

echo "Generate CA certificate..."
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/tmp/private/ca-key.pem
ipsec pki --self --ca --lifetime 3650 --in ~/tmp/private/ca-key.pem --type rsa --dn "C=US, O=$ORG_NAME, CN=$ORG_NAME" --outform pem > ~/tmp/cacerts/ca-cert.pem

echo "Generate server certificate..."
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/tmp/private/server-key.pem

ipsec pki --pub --in ~/tmp/private/server-key.pem --type rsa \
    | ipsec pki --issue --lifetime 1200 --cacert ~/tmp/cacerts/ca-cert.pem --cakey ~/tmp/private/ca-key.pem \
    --dn "C=US, O=$ORG_NAME, CN=$VPN_PUBLIC_IP" --san $VPN_PUBLIC_IP --flag serverAuth \
    --flag ikeIntermediate --outform pem > ~/tmp/certs/server-cert.pem

echo "Generate client certificate..."
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/tmp/private/client-key.pem

ipsec pki --pub --in ~/tmp/private/client-key.pem --type rsa \
    | ipsec pki --issue --lifetime 1200 --cacert ~/tmp/cacerts/ca-cert.pem --cakey ~/tmp/private/ca-key.pem \
    --dn "C=US, O=$ORG_NAME, CN=$VPN_PUBLIC_IP" --san @IP_address --san $VPN_PUBLIC_IP --outform pem > ~/tmp/certs/client-cert.pem


echo "Copy certificates..."
cp -r ~/tmp/* /etc/ipsec.d/
mv /etc/ipsec.conf{,.original}

echo "Remove tmp files..."
rm -rf ~/tmp

echo "End generation certificates"