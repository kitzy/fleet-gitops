#!/bin/bash
set -euo pipefail

# Network sysctls for a host that is not a router. IP forwarding (Docker needs
# it) and rp_filter=2 (Tailscale needs loose mode) are deliberately not set.
# Safe to run more than once.

CONF=/etc/sysctl.d/60-fleet-network-hardening.conf
CONTENT='# Managed by fleet-gitops (harden-network-sysctls.sh)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1'

if [[ -f "$CONF" ]] && [[ "$(cat "$CONF")" == "$CONTENT" ]]; then
    echo "$CONF already in place"
else
    echo "Writing $CONF"
    printf '%s\n' "$CONTENT" > "$CONF"
fi

sysctl -p "$CONF"
