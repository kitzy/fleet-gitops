# fleet-gitops

**This is the actual repository I use in production to manage my personal devices via [Fleet](https://fleetdm.com).**  

The repo contains all Fleet configuration (policies, reports, scripts, software, profiles, and GitHub Actions) needed to keep my macOS, Linux, and mobile (iOS/iPadOS/Android) hosts in compliance using a GitOps workflow. There are no Windows hosts enrolled today, so no `platforms/windows/` directory or Windows fleet exists yet — the wiring conventions below still apply to Windows whenever that changes.

---

## Overview

- **Fleet GitOps** leverages version-controlled YAML to define desired host state.
- **GitHub Actions** (in `.github/workflows`) validate and apply that state automatically.
- **`.github/fleet-gitops/gitops.sh`** orchestrates dry-run and real runs of `fleetctl gitops` using `default.yml` and `fleets/*.yml`. It also runs with `--delete-other-fleets`, so removing a fleet's YAML file deletes that fleet in Fleet on the next apply — see the `fleet-gitops` skill below for the full declarative apply/delete behavior.
- **[contour](https://github.com/macadmins/contour)** generates and validates Apple `.mobileconfig` profiles and DDM declarations against Apple's schema, instead of hand-writing them.

---

## Repository Structure

```
.
├── default.yml              # Global org settings, agent options, label glob
├── platforms/                # Shared policies, reports, scripts, software, profiles
│   ├── agent-options.yml
│   ├── all/                  # Content shared across platforms (policies, reports, scripts, declaration-profiles, icons)
│   ├── android/              # configuration-profiles/, managed-app-configurations/
│   ├── ios/                  # configuration-profiles/, declaration-profiles/
│   ├── ipados/                # configuration-profiles/, declaration-profiles/
│   ├── linux/                # policies/, reports/, scripts/, software/
│   └── macos/                 # policies/, reports/, scripts/, software/, commands/,
│                              # configuration-profiles/, declaration-profiles/, enrollment-profiles/
├── labels/                    # Label definitions grouped by purpose (auto-loaded, see below)
├── fleets/                    # Fleet-specific configuration
│   ├── autopkg-testing.yml
│   ├── mobile-devices.yml
│   ├── servers.yml
│   ├── testing.yml
│   ├── unassigned.yml
│   └── workstations.yml
├── .contour/                  # contour CLI config for Apple profile/DDM authoring & validation
├── .claude/skills/             # fleet-gitops & contour skills used for AI-assisted authoring
└── .github/
    ├── fleet-gitops/           # Composite action + gitops.sh wrapper for fleetctl
    └── workflows/              # CI: profile validation, lint, and apply
```

- **`platforms/`** holds reusable content referenced via `path` (or a `paths:` glob) to avoid duplication. For example, `platforms/all/reports/collect-usb-devices.reports.yml` is included in multiple fleets.
- **`labels/`** holds global label definitions grouped into logical files (currently: hardware, operating systems, virtualization, Tailscale, k3s, and a couple of one-off/testing labels). They're picked up by `default.yml` via `paths: ./labels/*.yml`, so any new file in this directory is automatically included repo-wide.
- **`fleets/`** defines per-fleet policies, reports, controls, software, and secrets. Each YAML file represents a Fleet. `unassigned.yml` configures the built-in "Unassigned" team; the others (`autopkg-testing`, `mobile-devices`, `servers`, `testing`, `workstations`) are Fleet Premium teams.

The full rules for wiring a new file into a fleet — which directories auto-load via glob vs. which need an explicit `path:` entry — live in [CLAUDE.md](CLAUDE.md) and the `fleet-gitops` skill, so they're documented in one place instead of drifting out of sync here.

---

## Getting Started

1. **Prerequisites**
   - `fleetctl` installed (or allow GitHub Actions to install it automatically).
   - Access to a Fleet server (`FLEET_URL`) with an API token (`FLEET_API_TOKEN`).
   - Every other secret referenced by `${...}` in `default.yml` / `fleets/*.yml` — see the `Load secrets from 1Password` step in [.github/workflows/workflow.yml](.github/workflows/workflow.yml) for the current full list (enroll secrets per fleet, `SSO_METADATA_URL`, `FLEET_SECRET_SSH_USER`/`FLEET_SECRET_SSH_PUBLIC_KEY`, `FLEET_VULNERABILITY_WEBHOOK_URL`, etc.).

2. **Apply configuration locally**
   ```bash
   export FLEET_URL="https://fleet.example.com"
   export FLEET_API_TOKEN="..."
   export GLOBAL_ENROLL_SECRET="..."
   # plus every other secret referenced in default.yml and fleets/*.yml

   ./.github/fleet-gitops/gitops.sh
   ```
   - The script performs a dry run first (`fleetctl gitops ... --dry-run`) and then applies the configuration.

3. **CI/CD** — two workflows run in `.github/workflows/`:
   - **`workflow.yml`** — validates every Apple `.mobileconfig`/DDM JSON with `contour` (job `validate-apple-profiles`), then loads secrets from 1Password and runs `gitops.sh` (job `fleet-gitops`). Triggers: pushes to `main`, pull requests (dry run only), nightly at 06:00 UTC, and manual dispatch.
   - **`lint.yml`** — runs [Flint](https://github.com/headmin/fleet-editor-extensions) against the whole repo on pull requests and manual dispatch. Currently non-blocking (`continue-on-error`) while Flint's schema catches up with Fleet's — see the comments in that file for the tracked upstream issues.

---

## Customizing Configuration

### Adding or Modifying Fleets

1. Copy an existing file under `fleets/` (e.g., `workstations.yml`).
2. Adjust `name`, `policies`, `reports`, `controls`, `software`, and `settings`.
3. Create a corresponding enroll secret in Fleet and add it to your GitHub repository secrets (or 1Password vault, since this repo loads secrets via the `op-secrets` step).
4. Wire the secret into **both** the `Load secrets from 1Password` and `Apply latest configuration to Fleet` env blocks in [.github/workflows/workflow.yml](.github/workflows/workflow.yml) — missing either wiring causes the variable to expand to empty at runtime.

### Shared Resources in `platforms/`

Each platform directory only contains the subfolders it currently uses — e.g. `macos/` has `policies/`, `reports/`, `scripts/`, `software/`, `commands/`, `configuration-profiles/`, `declaration-profiles/`, and `enrollment-profiles/`; `android/` currently has just `configuration-profiles/` and `managed-app-configurations/`. Files here are reused across fleets by referencing them with `path:` (single file) or `paths:` (glob) in fleet YAML — see [CLAUDE.md](CLAUDE.md) for exactly which `controls:`/`software:` key each file type goes under, and which directories are auto-loaded vs. need explicit wiring.

### Authoring Apple Profiles & DDM Declarations

Don't hand-write `.mobileconfig` or DDM JSON — use the **`contour`** CLI (see the `contour` skill in [.claude/skills/contour](.claude/skills/contour)), which validates against Apple's schema. CI re-validates every profile under `platforms/macos/configuration-profiles/` and every declaration under `platforms/macos/declaration-profiles/` and `platforms/all/declaration-profiles/` on every push, so a hand-edited file that doesn't validate will fail the `validate-apple-profiles` job.

### Adding or Modifying Labels

1. Pick the appropriate file under `labels/` (e.g., `operating-systems.yml` for OS labels) or create a new logical grouping if none fits.
2. Add the label entry as a top-level list item — no `labels:` wrapper, since each file is itself a YAML list of label definitions.
3. Reference the label by its `name` in `labels_include_any` / `labels_include_all` / `labels_exclude_any` keys in fleet or default YAML.

The glob `paths: ./labels/*.yml` in `default.yml` picks up every file automatically, so new files don't require additional wiring.

---

## SSO Metadata Handling

SSO is configured via a metadata **URL** rather than pasted-in metadata: `org_settings.sso_settings.metadata_url` in [default.yml](default.yml) is set to `${SSO_METADATA_URL}`, a secret holding the IdP's metadata URL. This avoids the YAML-formatting problems that come with multiline secrets. If you ever need to fall back to pasting raw metadata instead of a URL, `.github/fleet-gitops/gitops.sh` has (currently unused, commented-out) logic for re-indenting a multiline metadata secret so it stays valid YAML.

---

## Contributing / Notes to Self

- All changes are applied automatically, be cautious when merging to `main`.
- Removing a `fleets/*.yml` file deletes that fleet in Fleet on the next apply (`--delete-other-fleets` is on by default in `gitops.sh`).
- Use pull requests and review dry-run output before merging.
- Remember that this repo is **live** for my device fleet; test changes carefully.

---

## License

This repository contains my production configuration. Reuse at your own risk.
