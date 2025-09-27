#!/usr/bin/env bash
set -euo pipefail
echo "[Zones in /etc/bind/named.conf.local]"
grep -E '^zone "' /etc/bind/named.conf.local | awk -F'"' '{print " - " $2}'

