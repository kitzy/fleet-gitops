# Fleet GitOps

## Authoring guidelines

- **Prefer Declarative Device Management (DDM) declarations over `.mobileconfig` configuration profiles whenever the desired setting is available as a DDM declaration type.** DDM is Apple's modern, status-aware management model and should be the default choice. Only fall back to a `.mobileconfig` configuration profile when no equivalent DDM declaration type exists for the setting (or when targeting an OS version that predates DDM support for that declaration). When in doubt, check the Apple DDM declarations reference below before authoring a new configuration profile.

- **When adding a Fleet Maintained App (FMA), look up the exact slug at https://fmalibrary.com/ before writing it into YAML.** FMA slugs (e.g. `1password/darwin`, `google-chrome/darwin`) must match the FMA library exactly — guessing or inferring from the app name will cause `fleetctl gitops` to fail. Verify each `slug:` value against fmalibrary.com when introducing or renaming an FMA entry under `software.fleet_maintained_apps`.

- **When introducing a new `${SECRET_NAME}` reference in any YAML, wire it up in two places in [.github/workflows/workflow.yml](.github/workflows/workflow.yml):**
  1. The `Load secrets from 1Password` step's `env:` block, mapping the secret name to its `op://...` 1Password path.
  2. The `Apply latest configuration to Fleet` step's `env:` block, mapping it from `${{ steps.op-secrets.outputs.SECRET_NAME }}`.

  Missing either wiring causes the variable to expand to empty at runtime — Fleet usually accepts the empty value silently, which is a quiet way to ship a broken config.

- **When duplicating an existing `.mobileconfig` or DDM `.json` as a starting point for a new profile/declaration, regenerate its identifiers before editing further:**
  - `.mobileconfig`: regenerate the top-level `PayloadIdentifier` and `PayloadUUID`, and every per-payload `PayloadIdentifier` / `PayloadUUID` inside `PayloadContent`.
  - DDM `.json`: regenerate the top-level `Identifier` (and any nested identifiers if the declaration type uses them).

  Reusing identifiers from the source profile/declaration causes the new one to overwrite the original on-device instead of being delivered alongside it.

- **`path:` and `paths:` values in any YAML are resolved relative to the file that contains them, not the repo root.** Files in `fleets/` reference shared content as `../platforms/...` because they sit one level down; `default.yml` at the repo root uses `./labels/*.yml`. When copy-pasting a `path:` between files at different directory depths, adjust the prefix to match the new file's location.

- **Files in `labels/` are top-level YAML lists of label definitions — no `labels:` key wrapper at the top of the file.** Each entry is a label object with `name`, `description`, `query`, and `label_membership_type`. `default.yml` aggregates the directory via `labels: - paths: ./labels/*.yml`, so any new file in `labels/` is picked up automatically — no wiring required, but the file must be a bare list to parse correctly.

- **When authoring or editing an osquery SQL query for a policy, report, or label, verify every table and column name against https://fleetdm.com/tables and https://fleetdm.com/vitals before committing.** Fleet's table schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.). Look up each table referenced in `FROM` / `JOIN` clauses to confirm the platforms it supports and the columns/types you're selecting on — don't rely on memorized osquery schema. This applies to queries in `platforms/*/policies/*.yml`, `platforms/*/reports/*.yml`, `labels/*.yml`, and any inline `query:` field in fleet or default YAML.

- **Do not verify DDM-delivered settings with the `managed_policies` table, and be cautious with the `preferences` table.** `managed_policies` only reflects legacy `.mobileconfig` profiles — DDM declarations are enforced through a separate channel and never populate it. The `preferences` table is also unreliable for DDM-delivered settings: enforced values may be absent from `/Library/Preferences/*.plist` entirely, or diverge from the declaration. For each DDM-managed setting, pick a verification approach in this order:
  1. A native osquery table that exposes the effective on-device state — e.g. `filevault_status`, `sip_config`, `password_policy` (for passcode policy). These reflect the realized state regardless of delivery channel.
  2. If no such table exists, verify *declaration presence* by querying the relevant DDM state persistence plist for the declaration's identifier — e.g. for `com.apple.configuration.softwareupdate.settings`, query `/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist`. See [platforms/macos/policies/macos-device-health.policies.yml](platforms/macos/policies/macos-device-health.policies.yml) for a worked example. Fleet's MDM verification UI is the right place to catch per-key declaration drift; osquery only confirms the declaration was accepted and persisted.

## Apply behavior

- **`fleetctl gitops` runs with `--delete-other-fleets` enabled by default** (see [.github/fleet-gitops/gitops.sh](.github/fleet-gitops/gitops.sh)). Removing a fleet file from `fleets/` actively deletes that team in Fleet on the next apply — it does not just orphan the config. When renaming or restructuring fleets, edit the existing file in place rather than delete-and-recreate, to avoid wiping enrollment secrets and host membership.

## References

- **Fleet GitOps YAML keys** (org settings, team settings, controls, policies, queries, software, etc.):
  https://fleetdm.com/docs/configuration/yaml-files

  Consult these when adding, renaming, or validating any key before guessing at structure.

- **Apple configuration profile payload keys** (`.mobileconfig` payloads under `platforms/macos/configuration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys

  Consult this whenever authoring or editing a configuration profile — verify the payload type, keys, value types, and supported OS versions before writing or changing any payload.

- **Apple Declarative Device Management (DDM)** declarations (`.json` payloads under `platforms/macos/declaration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/declarations

  Consult this whenever authoring or editing a DDM declaration — verify the declaration type, payload schema, and required/optional fields before writing or changing any declaration.

- **Fleet osquery table schema** (tables and columns available to queries in policies, reports, labels, and inline `query:` fields):
  https://fleetdm.com/tables

  Consult this whenever authoring or editing an osquery SQL query — verify each table referenced in `FROM` / `JOIN` clauses, the platforms it supports, and the columns/types you're selecting on. Fleet's schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.).

- **Fleet host vitals table schema** (tables and columns available to queries in policies, reports, labels, and inline `query:` fields):
  https://fleetdm.com/vitals

  Consult this whenever authoring or editing an osquery SQL query — verify each table referenced in `FROM` / `JOIN` clauses, the platforms it supports, and the columns/types you're selecting on. Fleet's schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.).
