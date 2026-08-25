# Apple DDM declaration audit — macOS configuration profiles (2026-08-25)

Audit of all 18 `.mobileconfig` configuration profiles in this repo against
Apple's current Declarative Device Management (DDM) declaration types, done
ahead of macOS/iOS 27 to catch legacy payloads that either have a DDM
successor available now or are at risk of losing support before one exists.

**Method:** every declaration `Type` under `com.apple.configuration.*`
(plus activations/assets/management types) was enumerated directly from
Apple's schema source of truth,
[apple/device-management](https://github.com/apple/device-management)
(`release` branch, `declarative/declarations/`), cross-checked against
`developer.apple.com/documentation/devicemanagement/declarations`. Each
profile's legacy `PayloadType` was checked against `mdm/profiles/*.yaml` in
the same repo for `deprecated`/`removed` version markers.

## Result

**0 of 18 profiles have a clean DDM mapping today.** None of the ~34
currently published `com.apple.configuration.*` types cover any setting used
in this repo's profiles. Apple's DDM coverage for macOS remains concentrated
in a handful of areas (accounts, passcode, software update, disk management,
Safari, background tasks/services config files, screen sharing, security
certificates/identities) — none of which overlap with Restrictions
(`com.apple.applicationaccess`), MCX, `ManagedClient.preferences`, Service
Management allowlisting, PPPC/TCC, firewall, Gatekeeper/system policy,
login window, Terminal, ad tracking, media sharing, or third-party app
preference domains (Chrome).

Because nothing converts, **no label was created to scope declarations to a
DDM-capable OS version** — there's nothing yet to scope. This decision
should be revisited the next time this audit is repeated (see below).

## Summary table

| Profile | Legacy `PayloadType`(s) | DDM equivalent? | Verdict |
|---|---|---|---|
| [automatic-app-store-updates.mobileconfig](../platforms/macos/configuration-profiles/all-macos/automatic-app-store-updates.mobileconfig) | `com.apple.SoftwareUpdate` | No — `com.apple.configuration.softwareupdate.settings` covers OS update behavior only, not per-app-store-app auto-update | **Needs a decision** — payload is deprecated (see below) |
| [chrome-disable-password-manager.mobileconfig](../platforms/macos/configuration-profiles/all-macos/chrome-disable-password-manager.mobileconfig) | `com.google.Chrome` | No — third-party app preference domain, not an Apple DDM concept | Left alone |
| [date-time.mobileconfig](../platforms/macos/configuration-profiles/all-macos/date-time.mobileconfig) | `com.apple.applicationaccess` | No | Left alone |
| [disable-bluetooth-file-sharing.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-bluetooth-file-sharing.mobileconfig) | `com.apple.ManagedClient.preferences` → `com.apple.Bluetooth` | No | Left alone |
| [disable-content-caching.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-content-caching.mobileconfig) | `com.apple.applicationaccess` | No | Left alone |
| [disable-guest.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-guest.mobileconfig) | `com.apple.MCX`, `com.apple.ManagedClient.preferences` → `com.apple.loginwindow` | No | Left alone |
| [disable-internet-sharing.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-internet-sharing.mobileconfig) | `com.apple.MCX` | No — key isn't even in Apple's official schema (undocumented) | Left alone |
| [disable-media-sharing.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-media-sharing.mobileconfig) | `com.apple.preferences.sharing.SharingPrefsExtension` | No — undocumented payload type, no schema entry | Left alone |
| [disable-safari-safefiles.mobileconfig](../platforms/macos/configuration-profiles/all-macos/disable-safari-safefiles.mobileconfig) | `com.apple.ManagedClient.preferences` → `com.apple.Safari` | No — `com.apple.configuration.safari.settings` (macOS 26.0+) exists but has no key for "auto-open safe downloads" | Left alone |
| [enforce-library-validation.mobileconfig](../platforms/macos/configuration-profiles/all-macos/enforce-library-validation.mobileconfig) | `com.apple.ManagedClient.preferences` → `com.apple.security.libraryvalidation` | No | Left alone |
| [fleet-background-activity.mobileconfig](../platforms/macos/configuration-profiles/all-macos/fleet-background-activity.mobileconfig) | `com.apple.servicemanagement` | No — `services.background-tasks` (macOS 15.0+) lets *you* push a background task, it doesn't allowlist a third party's Service Management item, which is what `Rules` does | Left alone |
| [fleetd-full-disk-access.mobileconfig](../platforms/macos/configuration-profiles/all-macos/fleetd-full-disk-access.mobileconfig) | `com.apple.TCC.configuration-profile-policy` (PPPC) | No — no privacy/TCC declaration type exists | Left alone |
| [google-updater-background-task.mobileconfig](../platforms/macos/configuration-profiles/all-macos/google-updater-background-task.mobileconfig) | `com.apple.servicemanagement` | No — same gap as fleet-background-activity | Left alone |
| [limit-ad-tracking.mobileconfig](../platforms/macos/configuration-profiles/all-macos/limit-ad-tracking.mobileconfig) | `com.apple.AdLib` | No — undocumented payload type, no schema entry | Left alone |
| [macos-firewall.mobileconfig](../platforms/macos/configuration-profiles/all-macos/macos-firewall.mobileconfig) | `com.apple.security.firewall` | No — no firewall declaration type exists | **Needs a decision** — two keys already inert (see below) |
| [prevent-autologon.mobileconfig](../platforms/macos/configuration-profiles/all-macos/prevent-autologon.mobileconfig) | `com.apple.loginwindow` | No | Left alone |
| [secure-terminal-keyboard.mobileconfig](../platforms/macos/configuration-profiles/all-macos/secure-terminal-keyboard.mobileconfig) | `com.apple.Terminal` | No — undocumented payload type, no schema entry | Left alone |
| [enforce-gatekeeper.mobileconfig](../platforms/macos/configuration-profiles/enforce-gatekeeper.mobileconfig) (wired only in `fleets/testing.yml`) | `com.apple.systempolicy.control` | No — no Gatekeeper/system-policy declaration type exists | Left alone |

## Needs a decision

1. **`automatic-app-store-updates.mobileconfig` — payload deprecated as of
   macOS 26.0.** Apple's schema marks the entire `com.apple.SoftwareUpdate`
   legacy payload `deprecated: '26.0'`. `fleets/workstations.yml` already
   sets `macos_updates.minimum_version: '26.6.2'`, so every workstation this
   profile applies to is on a macOS release where the payload is flagged
   deprecated. There is no DDM successor for the specific "auto-install App
   Store app updates" toggle — `com.apple.configuration.app.managed` (macOS
   26.0+) has `UpdateBehavior.AutomaticAppUpdates`, but it's scoped per
   individually-declared managed app, not a system-wide setting, so it isn't
   a drop-in replacement. Recommend monitoring Apple's release notes each
   cycle; nothing to change today since no migration path exists yet.
2. **`macos-firewall.mobileconfig` — two keys already silently ignored.**
   `EnableLogging` and `LoggingOption` were removed from
   `com.apple.security.firewall` as of macOS 15.0 ("Available in macOS 12
   through macOS 14.6" per Apple's schema). Since `fleets/workstations.yml`
   targets macOS 26.6.2 minimum, these two keys have had no effect on any
   in-scope host for several OS cycles. This isn't a DDM gap — it's a
   pre-existing dead setting this audit surfaced. Left the file unchanged
   pending a decision on whether to strip the two inert keys (out of scope
   for a DDM-mapping audit).

## Full current DDM configuration type catalog

For reference, the complete list of `com.apple.configuration.*` types
published today (macOS minimum in parentheses where supported on macOS;
`n/a` = not supported on macOS): `account.caldav` (13.0), `account.carddav`
(13.0), `account.exchange` (13.0), `account.google` (13.0), `account.ldap`
(13.0), `account.mail` (13.0), `account.subscribed-calendar` (14.0),
`app.managed` (26.0), `audio-accessory.settings` (n/a),
`diskmanagement.settings` (15.0), `external-intelligence.settings` (26.4),
`intelligence.settings` (26.4), `keyboard.settings` (26.4), `legacy` (13.0),
`legacy.interactive` (13.0), `management.status-subscriptions` (13.0),
`management.test` (13.0), `math.settings` (15.0),
`migration-assistant.settings` (26.4), `package` (26.0), `passcode.settings`
(13.0, already in use — [passcode-settings-ddm.json](../platforms/macos/declaration-profiles/all-macos/passcode-settings-ddm.json)),
`safari.bookmarks` (26.0), `safari.extensions.settings` (15.0),
`safari.settings` (26.0), `screensharing.connection` (14.0),
`screensharing.connection.group` (14.0), `screensharing.host.settings`
(14.0), `security.certificate` (14.0), `security.identity` (14.0),
`security.passkey.attestation` (14.0), `services.background-tasks` (15.0),
`services.configuration-files` (14.0), `siri.settings` (26.4),
`softwareupdate.enforcement.specific` (14.0), `softwareupdate.settings`
(15.0, already in use — [softwareupdate-settings-ddm.json](../platforms/macos/declaration-profiles/all-macos/softwareupdate-settings-ddm.json)),
`watch.enrollment` (n/a).

None of these cover firewall, Gatekeeper/system policy, PPPC/TCC, guest
account, Bluetooth, login window, Terminal, ad tracking, media sharing,
content caching, internet sharing, date/time enforcement, or third-party
app preferences — the areas this repo's remaining `.mobileconfig` profiles
handle.

## Re-running this audit

Apple has been expanding DDM coverage steadily (five new configuration
types shipped for macOS 26.4 alone: `external-intelligence.settings`,
`intelligence.settings`, `keyboard.settings`, `siri.settings`,
`migration-assistant.settings`). Worth re-checking this list against
`apple/device-management` each time a new macOS major ships. If a future
audit finds a clean mapping, follow the pattern already established by
`passcode-settings-ddm.json` and `softwareupdate-settings-ddm.json`: add
the declaration under `platforms/macos/declaration-profiles/`, and — per
the original ask behind this audit — create an OS-version label and scope
the new declaration to it with `labels_include_all` so hosts not yet on a
DDM-capable OS keep receiving the legacy profile instead of silently
losing the setting.
