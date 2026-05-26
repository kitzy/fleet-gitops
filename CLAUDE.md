# Fleet GitOps

## Authoring guidelines

- **Reports collect data; policies assert pass/fail state.** Both are saved osquery queries, but they differ in purpose and file location:
  - **Reports** (`platforms/*/reports/*.yml`) return rows of information — used for inventory, drift detection, and security visibility. They run on an interval (scheduled) with results stored by Fleet, or ad hoc (live) via the UI / `fleetctl`.
  - **Policies** (`platforms/*/policies/*.yml`) wrap a query in a boolean expectation. By Fleet convention, returning a row means the host *passes*; returning no rows means it *fails*.

  Same SQL underpinnings, different intent — pick the directory based on whether you're collecting data or asserting compliance.

- **Prefer Declarative Device Management (DDM) declarations over `.mobileconfig` configuration profiles whenever the desired setting is available as a DDM declaration type.** DDM is Apple's modern, status-aware management model and should be the default choice. Only fall back to a `.mobileconfig` configuration profile when no equivalent DDM declaration type exists for the setting (or when targeting an OS version that predates DDM support for that declaration). When in doubt, check the Apple DDM declarations reference below before authoring a new configuration profile.

- **`path:` and `paths:` values in any YAML are resolved relative to the file that contains them, not the repo root.** Files in `fleets/` reference shared content as `../platforms/...` because they sit one level down; `default.yml` at the repo root uses `./labels/*.yml`. When copy-pasting a `path:` between files at different directory depths, adjust the prefix to match the new file's location.

- **YAML files under `labels/`, `platforms/*/policies/`, and `platforms/*/reports/` are bare top-level lists — no `labels:` / `policies:` / `reports:` wrapper key at the top of the file.** Each entry is a single resource object (label, policy, or report). Wrapping the list in a key will cause `fleetctl gitops` to reject the file.

- **A few collection directories auto-load via `paths:` globs; everything else under `platforms/*/` must be wired into each `fleets/*.yml` that should receive it with an explicit `path:`.** The auto-loading globs in this repo today are:
  - `labels/*.yml` → globbed by `default.yml` (`labels: - paths: ./labels/*.yml`). Labels are global, so a new file in `labels/` is live repo-wide on next apply.
  - `platforms/macos/configuration-profiles/all-macos/*.mobileconfig` → globbed by `fleets/workstations.yml` under `controls.apple_settings.configuration_profiles:`. Drop a `.mobileconfig` into `all-macos/` and every workstation gets it.
  - `platforms/macos/declaration-profiles/all-macos/*.json` → globbed by `fleets/workstations.yml` under the same key. Same behavior for DDM declarations.

  These globs are *scoped to the file that declares them* — the `all-macos/` globs only fire into `workstations`, not into `servers` or `mobile-devices`. To auto-load a directory into a different fleet, add the `paths:` glob to that fleet's YAML too.

  Every other resource type is opted in fleet-by-fleet through an explicit `path:` (or a new `paths:` glob) entry:
  - **Policies** → under `policies:` (e.g. `- path: ../platforms/macos/policies/macos-device-health.policies.yml`)
  - **Reports** → under `reports:`
  - **Apple configuration profiles & DDM declarations** — macOS, iOS, and iPadOS share a *single* list; Fleet routes by file contents → `controls.apple_settings.configuration_profiles:`. Declarations that apply to multiple Apple platforms are conventionally staged under `platforms/all/declaration-profiles/` so they can be referenced from any fleet (e.g. [platforms/all/declaration-profiles/disable-beta-updates-ddm.json](platforms/all/declaration-profiles/disable-beta-updates-ddm.json)).
  - **Windows configuration profiles** (`.xml`) → `controls.windows_settings.configuration_profiles:`
  - **Android configuration profiles** (`.json`) → `controls.android_settings.configuration_profiles:`
  - **Run-on-enrollment / on-demand scripts** (macOS `.sh`, Linux `.sh`, Windows `.ps1` — Fleet routes by file extension) → `controls.scripts:` as one mixed list.
  - **Scripts surfaced as installable Software** (self-service install in Fleet Software) → `software.packages:` with `path:` to the script. This is a *different* wiring from `controls.scripts:` — same file extension, different lifecycle.
  - **Agent options** → `agent_options.path:` (typically `../platforms/agent-options.yml`)
  - **Apple Automated Device Enrollment (ADE/DEP) profiles** (`.json` staged under `platforms/macos/enrollment-profiles/`) → per-fleet `setup_experience.apple_setup_assistant:` path. Applies to macOS and iOS/iPadOS hosts enrolling via Apple Business Manager. Other `setup_experience` keys (`bootstrap_package`, `script`, `enable_end_user_authentication`, `lock_end_user_info`, `apple_enable_release_device_manually`) live alongside it in the same per-fleet block — see Fleet's GitOps YAML reference for the full shape.

  A new file added under `platforms/*/` *outside an auto-loading glob directory* with no fleet wiring is silent: it sits in the repo, but no host ever receives it. When introducing a resource, decide which fleets it applies to — if it belongs in an `all-macos/` glob directory, drop it there and you're done for the fleets that glob it; otherwise add an explicit `path:` entry to each fleet that should receive it.

- **When duplicating an existing `.mobileconfig` or DDM `.json` as a starting point for a new profile/declaration, regenerate its identifiers before editing further:**
  - `.mobileconfig`: regenerate the top-level `PayloadIdentifier` and `PayloadUUID`, and every per-payload `PayloadIdentifier` / `PayloadUUID` inside `PayloadContent`.
  - DDM `.json`: regenerate the top-level `Identifier` (and any nested identifiers if the declaration type uses them).

  Reusing identifiers from the source profile/declaration causes the new one to overwrite the original on-device instead of being delivered alongside it.

- **When introducing a new `${SECRET_NAME}` reference in any YAML, wire it up in two places in [.github/workflows/workflow.yml](.github/workflows/workflow.yml):**
  1. The `Load secrets from 1Password` step's `env:` block, mapping the secret name to its `op://...` 1Password path.
  2. The `Apply latest configuration to Fleet` step's `env:` block, mapping it from `${{ steps.op-secrets.outputs.SECRET_NAME }}`.

  Missing either wiring causes the variable to expand to empty at runtime — Fleet usually accepts the empty value silently, which is a quiet way to ship a broken config.

- **When adding a Fleet Maintained App (FMA), look up the exact slug at https://fmalibrary.com/ before writing it into YAML.** FMA slugs (e.g. `1password/darwin`, `google-chrome/darwin`) must match the FMA library exactly — guessing or inferring from the app name will cause `fleetctl gitops` to fail. Verify each `slug:` value against fmalibrary.com when introducing or renaming an FMA entry under `software.fleet_maintained_apps`.

- **When authoring or editing an osquery SQL query for a policy, report, or label, verify every table and column name against https://fleetdm.com/tables before committing.** Fleet's table schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.). Look up each table referenced in `FROM` / `JOIN` clauses to confirm the platforms it supports and the columns/types you're selecting on — don't rely on memorized osquery schema. This applies to queries in `platforms/*/policies/*.yml`, `platforms/*/reports/*.yml`, `labels/*.yml`, and any inline `query:` field in fleet or default YAML.

- **Do not verify DDM-delivered settings with the `managed_policies` table, and be cautious with the `preferences` table.** `managed_policies` only reflects legacy `.mobileconfig` profiles — DDM declarations are enforced through a separate channel and never populate it. The `preferences` table is also unreliable for DDM-delivered settings: enforced values may be absent from `/Library/Preferences/*.plist` entirely, or diverge from the declaration. For each DDM-managed setting, pick a verification approach in this order:
  1. A native osquery table that exposes the effective on-device state — e.g. `filevault_status`, `sip_config`, `password_policy` (for passcode policy). These reflect the realized state regardless of delivery channel.
  2. If no such table exists, verify *declaration presence* by querying the relevant DDM state persistence plist for the declaration's identifier — e.g. for `com.apple.configuration.softwareupdate.settings`, query `/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist`. See [platforms/macos/policies/macos-device-health.policies.yml](platforms/macos/policies/macos-device-health.policies.yml) for a worked example. Fleet's MDM verification UI is the right place to catch per-key declaration drift; osquery only confirms the declaration was accepted and persisted.

- **When in doubt about any GitOps YAML key, controls option, or nested field that no rule above covers, consult https://fleetdm.com/docs/configuration/yaml-files before writing it.** Fleet does not error on unrecognized or misspelled keys — per the docs, "any settings not defined in your YAML files (including missing or misspelled keys) will be reset to the default values or deleted." A typo therefore silently undoes a previous setting on the next apply rather than failing loudly. The same caution applies to nested keys under `controls`, `software`, `settings`, `agent_options`, `setup_experience`, and `org_settings`. When verifying the shape of an unfamiliar key, prefer the GitOps YAML reference over inferring from existing files (which may have been written before a key was renamed).

## Apply behavior

- **Fleet GitOps is declarative: the YAML is the desired state.** Anything not present in the repo after a `fleetctl gitops` run is removed from Fleet on the next apply. The specific consequence varies by resource type:
  - **Fleets** (`fleets/*.yml`) — `fleetctl gitops` runs with `--delete-other-fleets` enabled by default (see [.github/fleet-gitops/gitops.sh](.github/fleet-gitops/gitops.sh)), so removing a fleet file actively deletes that team in Fleet, wiping enrollment secrets and host membership.
  - **Configuration and declaration profiles** — removing the file (and any `paths:` entry that referenced it) removes the profile from hosts on the next apply.
  - **Policies** — removing the policy entry deletes the policy from Fleet entirely, taking its historical pass/fail data with it.
  - **Software entries under `software:`** — removing an entry stops Fleet from managing the package and drops Fleet's record of it, but does **not** automatically uninstall the binary from already-enrolled hosts. Full removal from hosts requires a separate uninstall policy/automation.

  When renaming or restructuring any of these, edit the existing file in place rather than delete-and-recreate, to avoid an unintended round-trip of removal and reinstall — or, for fleets, outright loss of enrollment secrets and host membership.

## References

- **Fleet GitOps YAML keys** (org settings, team settings, controls, policies, queries, software, etc.):
  https://fleetdm.com/docs/configuration/yaml-files

  Consult these when adding, renaming, or validating any key before guessing at structure.

- **Fleet Maintained Apps (FMA) catalog** (canonical `slug:` values for `software.fleet_maintained_apps` entries):
  https://fmalibrary.com/

  Consult this whenever introducing or renaming an FMA entry — verify the exact slug against the catalog before writing it into YAML. Guessing or inferring a slug from the app name will cause `fleetctl gitops` to fail.

- **Apple configuration profile payload keys** (`.mobileconfig` payloads under `platforms/macos/configuration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys

  Consult this whenever authoring or editing a configuration profile — verify the payload type, keys, value types, and supported OS versions before writing or changing any payload.

- **Apple Declarative Device Management (DDM)** declarations (`.json` payloads under `platforms/macos/declaration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/declarations

  Consult this whenever authoring or editing a DDM declaration — verify the declaration type, payload schema, and required/optional fields before writing or changing any declaration.

- **Fleet osquery table schema** (tables and columns available to queries in policies, reports, labels, and inline `query:` fields):
  https://fleetdm.com/tables

  Consult this whenever authoring or editing an osquery SQL query — verify each table referenced in `FROM` / `JOIN` clauses, the platforms it supports, and the columns/types you're selecting on. Fleet's schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.).
