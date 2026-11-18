#!/bin/bash
set -euo pipefail

# Lets unattended-upgrades install Docker Engine updates from Docker's apt
# repository (release o=Docker, a=<codename>). 50unattended-upgrades only
# allows Ubuntu origins. Reopening Allowed-Origins in a later file adds to the
# list instead of replacing it. Safe to run more than once.

CONF=/etc/apt/apt.conf.d/53unattended-upgrades-docker
CONTENT='// Managed by fleet-gitops (enable-docker-unattended-upgrades.sh)
Unattended-Upgrade::Allowed-Origins {
    "Docker:${distro_codename}";
};'

if [[ -f "$CONF" ]] && [[ "$(cat "$CONF")" == "$CONTENT" ]]; then
    echo "$CONF already in place"
else
    echo "Writing $CONF"
    printf '%s\n' "$CONTENT" > "$CONF"
fi
