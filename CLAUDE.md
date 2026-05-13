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

- **When authoring or editing an osquery SQL query for a policy, report, or label, verify every table and column name against https://fleetdm.com/tables before committing.** Fleet's table schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.). Look up each table referenced in `FROM` / `JOIN` clauses to confirm the platforms it supports and the columns/types you're selecting on — don't rely on memorized osquery schema. This applies to queries in `platforms/*/policies/*.yml`, `platforms/*/reports/*.yml`, `labels/*.yml`, and any inline `query:` field in fleet or default YAML.

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

