#!/bin/bash
set -euo pipefail

# Removes the known extra login accounts on homelab-vps:
#   linuxuser  - created by Vultr's Ubuntu image (sudo group, no keys)
#   kitzy      - created by the SSH user baseline before homelab-vps was excluded
# Only these names are removed. Any other account is left in place, so the
# policy keeps failing until a person looks at it. Safe to run more than once.

for user in linuxuser kitzy; do
    if id "$user" &>/dev/null; then
        if pgrep -u "$user" >/dev/null; then
            echo "Ending processes owned by $user"
            pkill -KILL -u "$user" || true
        fi
        echo "Removing $user and its home directory"
        userdel -r "$user" 2>/dev/null || userdel "$user"
    else
        echo "$user not present"
    fi
    if [[ -f "/etc/sudoers.d/$user" ]]; then
        echo "Removing /etc/sudoers.d/$user"
        rm -f "/etc/sudoers.d/$user"
    fi
done

visudo -c >/dev/null
