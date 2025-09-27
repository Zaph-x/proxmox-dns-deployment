#!/usr/bin/env bash
# Usage: delete-zone example.lan [--reverse 192.168.100.0/24]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: delete-zone <domain> [--reverse <cidr>]"
  exit 1
fi

DOMAIN="$1"
REVERSE_CIDR=""

shift 1
while (( "$#" )); do
  case "$1" in
    --reverse) REVERSE_CIDR="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

ZONES_DIR="/etc/bind/zones"
CONF_LOCAL="/etc/bind/named.conf.local"

FWD_FILE="${ZONES_DIR}/db.${DOMAIN}"

# Remove forward stanza
if grep -q "zone \"${DOMAIN}\"" "$CONF_LOCAL"; then
  awk -v zone="$DOMAIN" '
    BEGIN{skip=0}
    {
      if ($0 ~ "zone \""zone"\"") {skip=1}
      if (skip && $0 ~ /^};/){skip=0; next}
      if (!skip) print
    }' "$CONF_LOCAL" > "${CONF_LOCAL}.tmp"
  mv "${CONF_LOCAL}.tmp" "$CONF_LOCAL"
fi

[ -f "$FWD_FILE" ] && rm -f "$FWD_FILE"

# Reverse (optional)
if [ -n "$REVERSE_CIDR" ]; then
  NET="$(echo "$REVERSE_CIDR" | cut -d'/' -f1)"
  CIDR="$(echo "$REVERSE_CIDR" | cut -d'/' -f2)"
  if [ "$CIDR" != "24" ]; then
    echo "[!] Reverse helper supports /24 only"
    exit 1
  fi
  IFS='.' read -r O1 O2 O3 O4 <<< "$NET"
  REV_ZONE="${O3}.${O2}.${O1}.in-addr.arpa"
  REV_FILE="${ZONES_DIR}/db.${REV_ZONE}"

  if grep -q "zone \"${REV_ZONE}\"" "$CONF_LOCAL"; then
    awk -v zone="$REV_ZONE" '
      BEGIN{skip=0}
      {
        if ($0 ~ "zone \""zone"\"") {skip=1}
        if (skip && $0 ~ /^};/){skip=0; next}
        if (!skip) print
      }' "$CONF_LOCAL" > "${CONF_LOCAL}.tmp"
    mv "${CONF_LOCAL}.tmp" "$CONF_LOCAL"
  fi
  [ -f "$REV_FILE" ] && rm -f "$REV_FILE"
fi

named-checkconf
rndc reconfig || systemctl reload bind9
echo "[✓] Zone '${DOMAIN}' removed."

