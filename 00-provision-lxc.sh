#!/usr/bin/env bash
# 00-provision-lxc.sh
set -euo pipefail

CTID="${CTID:-}"
LXC_HOSTNAME="${LXC_HOSTNAME:-dns01}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
TEMPLATE="${TEMPLATE:-debian-12-standard_12.2-1_amd64.tar.zst}"  # Make sure it's downloaded
BRIDGE="${BRIDGE:-vmbr0}"
IP_CIDR="${IP_CIDR:-192.168.100.10/24}"
GW_IP="${GW_IP:-192.168.100.1}"
NAMESERVER="${NAMESERVER:-192.168.100.1}"
MEM_MB="${MEM_MB:-512}"
DISK_GB="${DISK_GB:-8}"
CORES="${CORES:-1}"

if [[ -z "$CTID" ]]; then
  echo "[e] You must set CTID environment variable"
  exit 1
fi

if ! pct status "$CTID" &>/dev/null; then
  echo "[+] Creating LXC $CTID ($LXC_HOSTNAME)"
  pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
    -hostname "$LXC_HOSTNAME" \
    -net0 name=eth0,bridge="$BRIDGE",ip="$IP_CIDR",gw="$GW_IP" \
    -storage "$VM_STORAGE" \
    -rootfs "${VM_STORAGE}:${DISK_GB}" \
    -memory "$MEM_MB" -cores "$CORES" \
    -features keyctl=1,nesting=1
else
  echo "[e] LXC $CTID already exists"
  exit 1
fi

echo "[+] Starting LXC"
pct start "$CTID"
sleep 5

echo "[+] Setting temporary resolv.conf"
pct exec "$CTID" -- bash -lc "printf 'nameserver ${NAMESERVER}\n' > /etc/resolv.conf"

echo "[+] Updating and installing baseline tools"
pct exec "$CTID" -- bash -lc "apt-get update && apt-get install -y vim less curl ca-certificates"

echo "[+] Copying bootstrap files"
pct push "$CTID" files/named.conf.options /root/named.conf.options
pct push "$CTID" files/named.conf.log      /root/named.conf.log
pct push "$CTID" files/zone-forward.template /root/zone-forward.template
pct push "$CTID" files/zone-reverse.template /root/zone-reverse.template
pct push "$CTID" 10-bootstrap-bind9.sh /root/10-bootstrap-bind9.sh

echo "[+] Running bootstrap inside the container"
pct exec "$CTID" -- bash -lc "bash /root/10-bootstrap-bind9.sh"

echo "[+] Copying zone tools into the container"
pct push "$CTID" tools/add-zone.sh /usr/local/bin/add-zone
pct push "$CTID" tools/delete-zone.sh /usr/local/bin/delete-zone
pct push "$CTID" tools/list-zones.sh /usr/local/bin/list-zones
pct exec "$CTID" -- chmod +x /usr/local/bin/{add-zone,delete-zone,list-zones}

echo "[✓] Done. LXC $CTID ready. Use: pct exec $CTID -- add-zone example.lan 192.168.100.10 --reverse 192.168.100.0/24"

