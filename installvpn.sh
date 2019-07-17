#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit
fi

apt update
apt -y upgrade
apt install openvpn easy-rsa -y
cp /usr/share/zoneinfo/America/New_York /etc/localtime

mkdir /etc/openvpn
cd /etc/openvpn
mkdir ccd

public_ip=$(ifconfig eth0 | grep 'inet ' | cut -d ' ' -f 10)

echo "dev tun0
tls-server
user nobody
group nogroup

# Openvpn tunnel network
server 10.254.254.0 255.255.255.0

# IP Address we listen on
local $public_ip

# Port and Protocol
port 1194 
proto tcp

comp-lzo
cipher AES-256-CBC

# IPP allows you to statically assign tunnel network IPs to dropboxes
#ifconfig-pool-persist /etc/sysconfig/openvpn/ruvpn-ip-pool.txt

# mgmt & log settings
management 127.0.0.1 1196
log /var/log/openvpn/openvpn.log
mute-replay-warnings
# verbose level, turn up if troubleshooting for more logs. 6 is usually good.
verb 3

# Maximum number of simultaneous clients
# enabling this allows multiple connections using the same cert. However, this is insecure.
# if someone steals your certs from a dropbox both the legit and malicious connections could exist simultaneously.
max-clients 50
duplicate-cn

client-to-client
client-config-dir ccd

#Option, set renegotiation time
#reneg-sec 86400

#location of cert files
dh /etc/openvpn/easy-rsa/keys/dh2048.pem
cert /etc/openvpn/easy-rsa/keys/pttunnel.crt
ca /etc/openvpn/easy-rsa/keys/ca.crt
key /etc/openvpn/easy-rsa/keys/pttunnel.key
# set this up upon first revoke
#crl-verify /etc/openvpn/easy-rsa/keys/crl.pem

#Timeout for restarting the tunnel on client end if it loses connection
keepalive 10 60
persist-tun
persist-key

#keep mtus low to account for additional encapsulation
link-mtu 1250
mssfix 1250" > pttunnel.conf

cp -a /usr/share/easy-rsa /etc/openvpn/
cd /etc/openvpn/easy-rsa
cp openssl-1.0.0.cnf openssl.cnf

. vars
./clean-all
./build-ca
./build-dh
./build-key-server pttunnel
touch keys/crl.pem

update-rc.d openvpn enable
/etc/init.d/openvpn start

echo "[Unit]
Before=network.target
[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 1194
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 1194
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 1194
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/openvpn-iptables.service
systemctl enable --now openvpn-iptables.service
