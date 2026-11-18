#!/bin/bash
set -euo pipefail

# Purges snapd from hosts that run no snaps (homelab-vps) and pins it so apt
# never reinstalls it as a dependency. snapd carries critical CVEs that Ubuntu
# has not fixed, and an unused daemon is attack surface for nothing.
# Safe to run more than once.

PIN=/etc/apt/preferences.d/no-snapd
PIN_CONTENT='# Managed by fleet-gitops (remove-snapd.sh)
Package: snapd
Pin: release a=*
Pin-Priority: -10'

if dpkg-query -W -f='${Status}' snapd 2>/dev/null | grep -q ' installed$'; then
    if command -v snap &>/dev/null; then
        installed_snaps=$(snap list 2>/dev/null | tail -n +2 || true)
        if [[ -n "$installed_snaps" ]]; then
            echo "Snaps are installed, not removing snapd:"
            echo "$installed_snaps"
            exit 1
        fi
    fi

    # Refuse to go ahead if purging snapd would take any other package with it.
    others=$(DEBIAN_FRONTEND=noninteractive apt-get -s purge snapd \
        | awk '/^(Purg|Remv) / {print $2}' | grep -vx snapd || true)
    if [[ -n "$others" ]]; then
        echo "Purging snapd would also remove these packages, not removing:"
        echo "$others"
        exit 1
    fi

    echo "Stopping snapd"
    systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true

    echo "Purging snapd"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq snapd
else
    echo "snapd already removed"
fi

for dir in /snap /var/snap /var/lib/snapd /var/cache/snapd; do
    if [[ -e "$dir" ]]; then
        echo "Removing $dir"
        rm -rf "$dir"
    fi
done

if [[ -f "$PIN" ]] && [[ "$(cat "$PIN")" == "$PIN_CONTENT" ]]; then
    echo "$PIN already in place"
else
    echo "Writing $PIN so apt never reinstalls snapd"
    printf '%s\n' "$PIN_CONTENT" > "$PIN"
fi
