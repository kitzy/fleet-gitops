# Fleet GitOps

The **hard technical requirements** for this repo — Fleet/Apple/Windows/Android
schema validation, DDM-vs-`.mobileconfig` rules, identifier regeneration,
osquery verification caveats, and the declarative apply/delete behavior — live
in the **`fleet-gitops` skill**
([.claude/skills/fleet-gitops/SKILL.md](.claude/skills/fleet-gitops/SKILL.md)).
Invoke it with **`/fleet-gitops`** for any GitOps YAML work.

The **repo-specific conventions** below are always in effect.

## Fleet wiring & auto-loading

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

## Secrets

- **When introducing a new `${SECRET_NAME}` reference in any YAML, wire it up in two places in [.github/workflows/workflow.yml](.github/workflows/workflow.yml):**
  1. The `Load secrets from 1Password` step's `env:` block, mapping the secret name to its `op://...` 1Password path.
  2. The `Apply latest configuration to Fleet` step's `env:` block, mapping it from `${{ steps.op-secrets.outputs.SECRET_NAME }}`.

  Missing either wiring causes the variable to expand to empty at runtime — Fleet usually accepts the empty value silently, which is a quiet way to ship a broken config.
