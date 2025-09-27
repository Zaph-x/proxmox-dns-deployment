#!/usr/bin/env bash
# Usage:
#   add-zone example.lan 192.168.100.10 [--ns-ipv6 2001:db8::10] [--reverse 192.168.100.0/24]
# Creates forward zone and (optional) reverse zone, validates, and rndc reconfig.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: add-zone <domain> <ns_ipv4> [--ns-ipv6 <ip>] [--reverse <cidr>]"
  exit 1
fi

DOMAIN="$1"
NS_IPV4="$2"
NS_IPV6=""
REVERSE_CIDR=""

shift 2
while (( "$#" )); do
  case "$1" in
    --ns-ipv6)
      NS_IPV6="$2"; shift 2;;
    --reverse)
      REVERSE_CIDR="$2"; shift 2;;
    *)
      echo "Unknown arg: $1"; exit 1;;
  esac
done

ZONES_DIR="/etc/bind/zones"
TEMPL_DIR="/etc/bind/templates"
CONF_LOCAL="/etc/bind/named.conf.local"

SERIAL="$(date +%Y%m%d01)"

# 1) Forward zone
FWD_FILE="${ZONES_DIR}/db.${DOMAIN}"
if [ -f "$FWD_FILE" ]; then
  echo "[!] Forward zone file exists: $FWD_FILE"
  exit 1
fi

cp "${TEMPL_DIR}/zone-forward.template" "$FWD_FILE"
sed -i \
  -e "s/%ZONE%/${DOMAIN}/g" \
  -e "s/%SERIAL%/${SERIAL}/g" \
  -e "s/%NS_IPV4%/${NS_IPV4}/g" \
  "$FWD_FILE"

if [ -n "$NS_IPV6" ]; then
  sed -i "s/^; ns1 IN AAAA .*/ns1 IN AAAA ${NS_IPV6}/" "$FWD_FILE"
  sed -i "s/^; @  IN AAAA .*/@   IN AAAA ${NS_IPV6}/" "$FWD_FILE"
fi

chown bind:bind "$FWD_FILE"
chmod 640 "$FWD_FILE"

if ! grep -q "zone \"${DOMAIN}\"" "$CONF_LOCAL"; then
cat >> "$CONF_LOCAL" <<EOF

zone "${DOMAIN}" {
    type master;
    file "${FWD_FILE}";
    allow-update { none; };
};
EOF
fi

# 2) Optional reverse zone
if [ -n "$REVERSE_CIDR" ]; then
  # Only supports IPv4 /24 convenience (common homelab case)
  NET="$(echo "$REVERSE_CIDR" | cut -d'/' -f1)"
  CIDR="$(echo "$REVERSE_CIDR" | cut -d'/' -f2)"
  if [ "$CIDR" != "24" ]; then
    echo "[!] Reverse helper currently supports /24 only"
    exit 1
  fi
  IFS='.' read -r O1 O2 O3 O4 <<< "$NET"
  REV_ZONE="${O3}.${O2}.${O1}.in-addr.arpa"
  REV_FILE="${ZONES_DIR}/db.${REV_ZONE}"

  if [ -f "$REV_FILE" ]; then
    echo "[!] Reverse zone file exists: $REV_FILE"
    exit 1
  fi

  cp "${TEMPL_DIR}/zone-reverse.template" "$REV_FILE"
  sed -i \
    -e "s/%FQDN_ZONE%/${DOMAIN}/g" \
    -e "s/%SERIAL%/${SERIAL}/g" \
    "$REV_FILE"

  chown bind:bind "$REV_FILE"
  chmod 640 "$REV_FILE"

  if ! grep -q "zone \"${REV_ZONE}\"" "$CONF_LOCAL"; then
cat >> "$CONF_LOCAL" <<EOF

zone "${REV_ZONE}" {
    type master;
    file "${REV_FILE}";
    allow-update { none; };
};
EOF
  fi
fi

# 3) Validate and reload
echo "[+] Validating config"
named-checkconf

echo "[+] Checking forward zone"
named-checkzone "$DOMAIN" "$FWD_FILE"

if [ -n "${REV_ZONE:-}" ]; then
  echo "[+] Checking reverse zone"
  named-checkzone "$REV_ZONE" "$REV_FILE"
fi

echo "[+] Reloading Bind"
rndc reconfig || systemctl reload bind9

echo "[✓] Zone '${DOMAIN}' added."
if [ -n "${REV_ZONE:-}" ]; then
  echo "[✓] Reverse zone '${REV_ZONE}' added."
fi

