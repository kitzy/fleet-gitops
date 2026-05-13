# fleet-gitops

**This is the actual repository I use in production to manage my personal devices via [Fleet](https://fleetdm.com).**  

The repo contains all Fleet configuration (policies, queries, scripts, and GitHub Actions) needed to keep my macOS, Windows, and Linux hosts in compliance using a GitOps workflow.

---

## Overview

- **Fleet GitOps** leverages version-controlled YAML to define desired host state.
- **GitHub Actions** (in `.github/workflows`) run `fleetctl gitops` automatically on every push, pull request, nightly schedule, or manual trigger.
- **`.github/fleet-gitops/gitops.sh`** orchestrates dry-run and real runs of `fleetctl` using configuration files in `default.yml` and `fleets/*.yml`.

---

## Repository Structure

```
.
├── default.yml              # Global org settings & agent options
├── platforms/               # Shared policies, reports, scripts, profiles
│   ├── agent-options.yml
│   ├── all/                 # Content shared across platforms
│   ├── android/
│   ├── ios/
│   ├── ipados/
│   ├── linux/
│   ├── macos/
│   └── windows/
├── fleets/                  # Fleet-specific configuration
│   ├── mobile-devices.yml
│   ├── servers.yml
│   ├── unassigned.yml
│   └── workstations.yml
└── .github/
    ├── fleet-gitops/        # Composite action + gitops.sh wrapper for fleetctl
    └── workflows/           # CI pipeline applying config to Fleet
```

- **`platforms/`** holds reusable content referenced via `path` to avoid duplication. For example, `platforms/all/reports/collect-usb-devices.reports.yml` is included in multiple fleets.
- **`fleets/`** defines per-fleet policies, reports, scripts, and secrets. Each YAML file represents a Fleet.

---

## Getting Started

1. **Prerequisites**
   - `fleetctl` installed (or allow GitHub Action to install automatically).
   - Access to a Fleet server (`FLEET_URL`) with an API token (`FLEET_API_TOKEN`).
   - GitHub repository secrets set for every environment variable referenced in the YAML files (e.g., `GLOBAL_ENROLL_SECRET`, `FLEET_WORKSTATIONS_ENROLL_SECRET`, etc.).

2. **Apply configuration locally**
   ```bash
   export FLEET_URL="https://fleet.example.com"
   export FLEET_API_TOKEN="..."
   export GLOBAL_ENROLL_SECRET="..."
   # plus any fleet secrets referenced in fleets/*.yml

   ./.github/fleet-gitops/gitops.sh
   ```
   - The script performs a dry run first (`fleetctl gitops ... --dry-run`) and then applies the configuration.

3. **CI/CD**
   - `.github/workflows/workflow.yml` runs the GitOps pipeline:
     - On pushes to `main`
     - On pull requests (dry run only)
     - Nightly at 06:00 UTC
     - Manually via the *Run workflow* button

---

## Customizing Configuration

### Adding or Modifying Fleets

1. Copy an existing file under `fleets/` (e.g., `workstations.yml`).
2. Adjust `name`, `policies`, `reports`, `controls`, `scripts`, and `settings`.
3. Create a corresponding enroll secret in Fleet and add it to your GitHub repository secrets.
4. Reference the secret in `.github/workflows/workflow.yml` if needed.

### Shared Resources in `platforms/`

- **Policies**: `platforms/{os}/policies/*.policies.yml`
- **Reports/Queries**: `platforms/all/reports/*.yml`
- **Scripts**: `platforms/{os}/scripts/*.sh` or `*.ps1`
- **Configuration Profiles**: `platforms/{os}/configuration-profiles/*`

Files in `platforms/` can be reused across multiple fleets by referencing them with `path:` in the YAML.

---

## SSO Metadata Handling

Because raw SAML metadata often breaks YAML formatting, `.github/fleet-gitops/gitops.sh` re-indents multiline metadata stored in the `GOOGLE_SSO_METADATA` secret. This ensures values expand correctly when Fleet reads the configuration.

---

## Contributing / Notes to Self

- All changes are applied automatically, be cautious when merging to `main`.
- Use pull requests and review dry-run output before merging.
- Remember that this repo is **live** for my device fleet; test changes carefully.

---

## License

This repository contains my production configuration. Reuse at your own risk.

