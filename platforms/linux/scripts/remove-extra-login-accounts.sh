#!/bin/bash
set -euo pipefail

# Removes the known extra login accounts on homelab-vps:
#   linuxuser  - created by Vultr's Ubuntu image (sudo group, no keys)
#   kitzy      - created by the SSH user baseline before homelab-vps was excluded
# Only these names are removed. Any other account is left in place, so the
# policy keeps failing until a person looks at it. Safe to run more than once.
#
# Never kill processes by UID here. Containers run with host UIDs (no user
# namespace remapping), so "the user's processes" can be container processes
# that only share the UID: an earlier version killed Authentik (UID 1000, the
# same as linuxuser). If userdel refuses because the UID is in use, this
# script fails and the policy stays failing for a person to look at.

failed=0
for user in linuxuser kitzy; do
    if id "$user" &>/dev/null; then
        echo "Removing $user and its home directory"
        if ! userdel -r "$user"; then
            echo "Could not remove $user (UID $(id -u "$user") may be in use by a process); leaving it" >&2
            failed=1
        fi
    else
        echo "$user not present"
    fi
    if [[ -f "/etc/sudoers.d/$user" ]]; then
        echo "Removing /etc/sudoers.d/$user"
        rm -f "/etc/sudoers.d/$user"
    fi
done

visudo -c >/dev/null
exit "$failed"
