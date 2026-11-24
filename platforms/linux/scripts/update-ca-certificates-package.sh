#!/bin/sh
# Upgrades the ca-certificates package so the system CA bundle drops the compromised eMudhra roots
# (eMudhra intermediate CA compromise, https://emudhra.we-have-a-problem.com/#linux).
# Only upgrades ca-certificates (never installs it or other packages). Safe to run more than once.
# Supports apt-based distributions; other package managers exit non-zero so the policy keeps failing visibly.

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found. Update ca-certificates with this host's package manager." >&2
  exit 1
fi

if ! dpkg -s ca-certificates >/dev/null 2>&1; then
  echo "ca-certificates isn't installed on this host, nothing to upgrade." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

before=$(dpkg-query -W -f='${Version}' ca-certificates)

apt-get update -qq || exit 1
apt-get install -y -qq --only-upgrade \
  -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
  ca-certificates || exit 1

after=$(dpkg-query -W -f='${Version}' ca-certificates)

if [ "$before" = "$after" ]; then
  echo "ca-certificates is already the newest available version ($after). If the policy still fails, the distribution hasn't shipped the fix; see https://emudhra.we-have-a-problem.com/#linux."
else
  echo "Upgraded ca-certificates $before -> $after."
fi
