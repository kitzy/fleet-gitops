#!/bin/bash
set -euo pipefail

# Locks root's password on homelab-vps. Root still logs in over Tailscale SSH,
# which does not use the password. Safe to run more than once.

status=$(passwd -S root | awk '{print $2}')
if [[ "$status" == "L" ]]; then
    echo "root password already locked"
else
    passwd -l root
    echo "root password locked"
fi
