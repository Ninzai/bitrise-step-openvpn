#!/bin/bash
set -eu

echo "Configs:"
echo "host: $host"
echo "port: $port"
echo "proto: $proto"
echo "ca_crt: $(if [ ! -z "$ca_crt" ]; then echo "***"; fi)"
echo "client_crt: $(if [ ! -z "$client_crt" ]; then echo "***"; fi)"
echo "client_key: $(if [ ! -z "$client_key" ]; then echo "***"; fi)"
echo "user: $(if [ ! -z "$user" ]; then echo "***"; fi)"
echo "password: $(if [ ! -z "$password" ]; then echo "***"; fi)"
echo ""

log_path=$(mktemp)

envman add --key "OPENVPN_LOG_PATH" --value "$log_path"
echo "Log path exported (\$OPENVPN_LOG_PATH=$log_path)"
echo ""

case "$OSTYPE" in
  linux*)
    echo "Configuring for Ubuntu"

    cat <<EOF > /etc/openvpn/client.conf
client
dev tun
proto ${proto}
remote ${host} ${port}
remote-cert-eku "TLS Web Server Authentication"
persist-key
persist-tun
verb 11
mute 20
keepalive 10 60
cipher AES-256-CBC
auth SHA512
float
reneg-sec 28800
nobind
mute-replay-warnings
auth-user-pass auth.txt
explicit-exit-notify 2
resolv-retry infinite
nobind
ca ca.crt
cert client.crt
key client.key
status /var/log/openvpn-status-log
log /var/log/openvpn.log

EOF
    echo ${ca_crt} | base64 -d > /etc/openvpn/ca.crt
    echo ${client_crt} | base64 -d > /etc/openvpn/client.crt
    echo ${client_key} | base64 -d > /etc/openvpn/client.key
    echo ${user} > /etc/openvpn/auth.txt
    echo ${password} >> /etc/openvpn/auth.txt

    echo ""
    echo "Run openvpn"
      service openvpn start client > $log_path 2>&1
    echo "Done"
    echo ""

    echo "Check status"
    sleep 5
    if ! ifconfig | grep tun0 > /dev/null ; then
      echo "No open VPN tunnel found"
      cat "$log_path"
      exit 1
    fi
    echo "Done"
    ;;
  darwin*)
    echo "Configuring for Mac OS"

    echo ${ca_crt} | base64 -D -o ca.crt
    echo ${client_crt} | base64 -D -o client.crt
    echo ${client_key} | base64 -D -o client.key
    echo ${user} > auth.txt
    echo ${password} >> auth.txt
    echo ""

    echo "Run openvpn"
      sudo openvpn --client --dev tun --proto ${proto} --remote ${host} ${port} --remote-cert-eku "TLS Web Server Authentication" --persist-key --persist-tun --verb 11 --mute 20 --keepalive 10 60 --cipher AES-256-CBC --auth SHA512 --float --reneg-sec 28800 --nobind --mute-replay-warnings --auth-user-pass auth.txt --explicit-exit-notify 2 --resolv-retry infinite --nobind --ca ca.crt --cert client.crt --key client.key --status /var/log/openvpn-status-log --log /var/log/openvpn.log > $log_path 2>&1 &
    echo "Done"
    echo ""

    echo "Check status"
    sleep 5
    if ! ps -p $! >&-; then
      echo "Process exited"
      cat "$log_path"
      exit 1
    fi
    echo "Done"
    ;;
  *)
    echo "Unknown operative system: $OSTYPE, exiting"
    exit 1
    ;;
esac