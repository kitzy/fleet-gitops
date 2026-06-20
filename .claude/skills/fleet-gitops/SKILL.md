---
name: fleet-gitops
description: Authoring, wiring, and apply-behavior guidance for this Fleet GitOps repo — policies vs reports, fleet wiring for profiles/DDM/software/scripts, secret wiring, and schema validation against upstream Apple/Windows/Android/Fleet references. Use for any work on Fleet GitOps YAML, .mobileconfig profiles, DDM declarations, osquery queries, or software entries.
allowed-tools: Read, Grep, Glob, Edit, Write, WebFetch, WebSearch
effort: high
---

# Fleet GitOps

You are helping with Fleet GitOps configuration in this repository. Apply the
following constraints for all work in this session.

## Authoring guidelines

- **Reports collect data; policies assert pass/fail state.** Both are saved osquery queries, but they differ in purpose and file location:
  - **Reports** (`platforms/*/reports/*.yml`) return rows of information — used for inventory, drift detection, and security visibility. They run on an interval (scheduled) with results stored by Fleet, or ad hoc (live) via the UI / `fleetctl`.
  - **Policies** (`platforms/*/policies/*.yml`) wrap a query in a boolean expectation. By Fleet convention, returning a row means the host *passes*; returning no rows means it *fails*.

  Same SQL underpinnings, different intent — pick the directory based on whether you're collecting data or asserting compliance.

- **Prefer Declarative Device Management (DDM) declarations over `.mobileconfig` configuration profiles whenever the desired setting is available as a DDM declaration type.** DDM is Apple's modern, status-aware management model and should be the default choice. Only fall back to a `.mobileconfig` configuration profile when no equivalent DDM declaration type exists for the setting (or when targeting an OS version that predates DDM support for that declaration). When in doubt, check the Apple DDM declarations reference below before authoring a new configuration profile.

- **`path:` and `paths:` values in any YAML are resolved relative to the file that contains them, not the repo root.** Files in `fleets/` reference shared content as `../platforms/...` because they sit one level down; `default.yml` at the repo root uses `./labels/*.yml`. When copy-pasting a `path:` between files at different directory depths, adjust the prefix to match the new file's location.

- **YAML files under `labels/`, `platforms/*/policies/`, and `platforms/*/reports/` are bare top-level lists — no `labels:` / `policies:` / `reports:` wrapper key at the top of the file.** Each entry is a single resource object (label, policy, or report). Wrapping the list in a key will cause `fleetctl gitops` to reject the file.

- **When duplicating an existing `.mobileconfig` or DDM `.json` as a starting point for a new profile/declaration, regenerate its identifiers before editing further:**
  - `.mobileconfig`: regenerate the top-level `PayloadIdentifier` and `PayloadUUID`, and every per-payload `PayloadIdentifier` / `PayloadUUID` inside `PayloadContent`.
  - DDM `.json`: regenerate the top-level `Identifier` (and any nested identifiers if the declaration type uses them).

  Reusing identifiers from the source profile/declaration causes the new one to overwrite the original on-device instead of being delivered alongside it.

- **When adding a Fleet Maintained App (FMA), look up the exact slug at https://fmalibrary.com/ before writing it into YAML.** FMA slugs (e.g. `1password/darwin`, `google-chrome/darwin`) must match the FMA library exactly — guessing or inferring from the app name will cause `fleetctl gitops` to fail. Verify each `slug:` value against fmalibrary.com when introducing or renaming an FMA entry under `software.fleet_maintained_apps`. When adding macOS or Windows software, **check the Fleet-maintained app catalog first** before reaching for a custom package.

- **When remediating a CVE, use Fleet's built-in vulnerability detection to identify the affected software and hosts first, then deploy a fix** — prefer a Fleet-maintained app update where one exists, otherwise a custom package. Wire the resulting software entry into the fleets that need it per the repo's fleet-wiring conventions in CLAUDE.md.

- **When authoring or editing an osquery SQL query for a policy, report, or label, verify every table and column name against https://fleetdm.com/tables before committing.** Fleet's table schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.). Look up each table referenced in `FROM` / `JOIN` clauses to confirm the platforms it supports and the columns/types you're selecting on — don't rely on memorized osquery schema. This applies to queries in `platforms/*/policies/*.yml`, `platforms/*/reports/*.yml`, `labels/*.yml`, and any inline `query:` field in fleet or default YAML. The machine-readable schema source is at https://github.com/fleetdm/fleet/tree/main/schema.

- **Validate every configuration profile and declaration against its upstream platform reference before writing or changing a payload.** Fleet does not validate payload internals — a wrong key, type, or value type ships silently. Pick the reference by profile type:
  - **First-party Apple `.mobileconfig` payloads** → Apple's payload-key reference (https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys) or the machine-readable schema at https://github.com/apple/device-management/tree/release/mdm/profiles.
  - **Third-party Apple `.mobileconfig` payloads** (custom app domains not in Apple's reference) → the ProfileManifests community reference at https://github.com/ProfileManifests/ProfileManifests.
  - **Apple DDM `.json` declarations** → Apple's declarations reference (https://developer.apple.com/documentation/devicemanagement/declarations) or https://github.com/apple/device-management/tree/release/declarative/declarations. Ensure the declaration `Type` matches a supported type from the reference.
  - **Windows `.xml` configuration profiles (CSPs)** → Microsoft's MDM/CSP reference at https://learn.microsoft.com/en-us/windows/client-management/mdm/. Validate CSP paths, formats, and allowed values.
  - **Android `.json` configuration profiles** → the Android Management API `enterprises.policies` reference at https://developers.google.com/android/management/reference/rest/v1/enterprises.policies.

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

- **Fleet REST API** (endpoints, parameters, automation):
  https://fleetdm.com/docs/rest-api/rest-api

- **Fleet Maintained Apps (FMA) catalog** (canonical `slug:` values for `software.fleet_maintained_apps` entries):
  https://fmalibrary.com/ — and the source catalog at https://github.com/fleetdm/fleet/tree/main/ee/maintained-apps

  Consult this whenever introducing or renaming an FMA entry — verify the exact slug against the catalog before writing it into YAML. Guessing or inferring a slug from the app name will cause `fleetctl gitops` to fail.

- **Apple configuration profile payload keys** (`.mobileconfig` payloads under `platforms/macos/configuration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys
  Machine-readable: https://github.com/apple/device-management/tree/release/mdm/profiles

- **Third-party Apple `.mobileconfig` payloads** (custom app domains not covered by Apple's reference):
  https://github.com/ProfileManifests/ProfileManifests

- **Apple Declarative Device Management (DDM)** declarations (`.json` payloads under `platforms/macos/declaration-profiles/`):
  https://developer.apple.com/documentation/devicemanagement/declarations
  Machine-readable: https://github.com/apple/device-management/tree/release/declarative/declarations

- **Windows configuration profiles / CSPs** (`.xml` under `controls.windows_settings`):
  https://learn.microsoft.com/en-us/windows/client-management/mdm/

- **Android configuration profiles** (`.json` under `controls.android_settings`):
  https://developers.google.com/android/management/reference/rest/v1/enterprises.policies

- **Fleet osquery table schema** (tables and columns available to queries in policies, reports, labels, and inline `query:` fields):
  https://fleetdm.com/tables — source at https://github.com/fleetdm/fleet/tree/main/schema

  Consult this whenever authoring or editing an osquery SQL query — verify each table referenced in `FROM` / `JOIN` clauses, the platforms it supports, and the columns/types you're selecting on. Fleet's schema differs from upstream osquery (platform availability, deprecated columns, Fleet-specific extensions like `mdm`, `network_interfaces`, etc.).
