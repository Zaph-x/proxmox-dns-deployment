#!/usr/bin/env bash
# 10-bootstrap-bind9.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[+] Installing bind9"
apt-get update
apt-get install -y bind9 bind9-utils bind9-dnsutils

install -o bind -g bind -d /var/log/named

if [ ! -f /etc/bind/rndc.key ]; then
  rndc-confgen -a -b 256
  chown bind:bind /etc/bind/rndc.key
  chmod 640 /etc/bind/rndc.key
fi

install -m 644 /root/named.conf.options /etc/bind/named.conf.options
install -m 644 /root/named.conf.log /etc/bind/named.conf.log

# Ensure the logging file is included from named.conf
if ! grep -q 'named.conf.log' /etc/bind/named.conf; then
  sed -i '1s;^;include "/etc/bind/named.conf.log";\n;' /etc/bind/named.conf
fi

install -o bind -g bind -m 755 -d /etc/bind/zones
install -o root -g root -m 644 -D /root/zone-forward.template /etc/bind/templates/zone-forward.template
install -o root -g root -m 644 -D /root/zone-reverse.template /etc/bind/templates/zone-reverse.template

touch /etc/bind/named.conf.local

named-checkconf /etc/bind/named.conf

systemctl enable --now bind9

echo "[+] Bind9 is up. Try: add-zone example.lan <dns_server_ip> --reverse 192.168.100.0/24"

