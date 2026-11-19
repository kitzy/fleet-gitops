#!/usr/bin/env bash
# Pins the fleetctl package to the Fleet server's version.
#
# Updates the package URL + SHA-256 in platforms/macos/software/fleetctl.package.yml and the
# version in platforms/macos/policies/macos-fleetctl.policies.yml, together.
#
# Usage: bump-fleetctl.sh [VERSION]
#   With no VERSION, reads it from $FLEET_URL/api/v1/fleet/version using $FLEET_API_TOKEN.
# Prints the new version on the last line of stdout when it changed; prints nothing and exits 0
# when the files are already current.
set -euo pipefail

PACKAGE=platforms/macos/software/fleetctl.package.yml
POLICY=platforms/macos/policies/macos-fleetctl.policies.yml

version="${1:-}"
if [[ -z "$version" ]]; then
  : "${FLEET_URL:?FLEET_URL is required when no version is given}"
  : "${FLEET_API_TOKEN:?FLEET_API_TOKEN is required when no version is given}"
  version="$(curl --fail --silent --show-error "$FLEET_URL/api/v1/fleet/version" \
    --header "Authorization: Bearer $FLEET_API_TOKEN" | jq --raw-output '.version')"
fi

# Release builds only (4.95.0). Refuse anything else (e.g. a -rc or a dev build) rather than
# pin a package that doesn't exist.
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing to pin fleetctl to non-release version '$version'" >&2
  exit 1
fi

current="$(sed -n 's#.*/fleet-v\([0-9.]*\)/fleetctl_v.*#\1#p' "$PACKAGE")"
if [[ "$current" == "$version" ]]; then
  exit 0
fi

url="https://github.com/fleetdm/fleet/releases/download/fleet-v${version}/fleetctl_v${version}_mac.pkg"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl --fail --location --silent --show-error --output "$work/fleetctl.pkg" "$url"
sha="$(shasum -a 256 "$work/fleetctl.pkg" | awk '{print $1}')"

sed -i.bak -e "s#^- url: .*#- url: ${url}#" -e "s#^  hash_sha256: .*#  hash_sha256: ${sha}#" "$PACKAGE"
sed -i.bak -e "s#AND version = '[0-9.]*'#AND version = '${version}'#" "$POLICY"
rm -f "$PACKAGE.bak" "$POLICY.bak"

echo "$version"
