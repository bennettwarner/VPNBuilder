#!/bin/bash
current_path=$(pwd)
echo "Input username for new cert"
read user
echo "Input server domain name or ip address to connect back to"
read server
cd /etc/openvpn/easy-rsa/
. vars
./build-key $user
cd $current_path
echo "client
dev tun
proto tcp
remote-cert-tls server
remote $server 443
remote $server 80
remote $server 53
remote $server 1194
persist-key
persist-tun
verb 3
cipher AES-256-CBC
comp-lzo
<ca>
" > $user.ovpn
cat /etc/openvpn/easy-rsa/keys/ca.crt >> $user.ovpn
echo "</ca>
<cert>" >> $user.ovpn
cat /etc/openvpn/easy-rsa/keys/$user.crt >> $user.ovpn
echo "</cert>
<key>" >> $user.ovpn
cat /etc/openvpn/easy-rsa/keys/$user.key >> $user.ovpn
echo "</key>" >> $user.ovpn

echo "
Config Created...
$current_path/$user.ovpn"
