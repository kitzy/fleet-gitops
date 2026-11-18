#!/bin/bash
set -euo pipefail

# Sets "live-restore": true in /etc/docker/daemon.json, keeping every other
# key, then reloads dockerd. live-restore is a reloadable option, so running
# containers are not restarted. Safe to run more than once.

DAEMON_JSON=/etc/docker/daemon.json

if ! command -v dockerd >/dev/null 2>&1; then
    echo "Docker Engine not installed" >&2
    exit 1
fi

mkdir -p /etc/docker
[[ -f "$DAEMON_JSON" ]] || echo '{}' > "$DAEMON_JSON"

changed=$(python3 - "$DAEMON_JSON" <<'PY'
import json, os, sys, tempfile
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
if cfg.get("live-restore") is True:
    print("no")
    sys.exit(0)
cfg["live-restore"] = True
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.chmod(tmp, 0o644)
os.replace(tmp, path)
print("yes")
PY
)

if [[ "$changed" == "yes" ]]; then
    echo "Set live-restore in $DAEMON_JSON; reloading dockerd"
    systemctl reload docker
else
    echo "live-restore already enabled"
fi
