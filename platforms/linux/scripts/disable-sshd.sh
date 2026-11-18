#!/bin/bash
set -euo pipefail

# Stops and disables sshd on hosts administered over Tailscale SSH only
# (homelab-vps). Tailscale SSH is served by tailscaled and does not use sshd.
# Safe to run more than once.

for unit in ssh.socket ssh.service; do
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
        if systemctl is-enabled --quiet "$unit" 2>/dev/null || systemctl is-active --quiet "$unit"; then
            echo "Disabling and stopping $unit"
            systemctl disable --now "$unit"
        else
            echo "$unit already disabled and stopped"
        fi
    fi
done
