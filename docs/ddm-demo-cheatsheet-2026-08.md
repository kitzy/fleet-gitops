# DDM conversion demo — cheat sheet (2026-08-25)

Four legacy `.mobileconfig` profiles staged in the **Testing** fleet
(`fleets/testing.yml`), picked because each has a confirmed clean DDM
declaration equivalent — for live-converting during tomorrow's demo. All
four validate clean against Apple's schema (via `contour profile validate`).

This follows up on an earlier audit of the 18 production `.mobileconfig`
profiles in this repo, which found none of them have a clean DDM mapping
today. Two of the four categories originally considered for this demo set
turned out not to have one either after checking field-level detail — noted
at the bottom so the demo doesn't trip over them live.

## The four profiles

| # | Legacy profile | Legacy `PayloadType` | DDM declaration type | Field mapping |
|---|---|---|---|---|
| 1 | [ddm-demo-safari-settings.mobileconfig](../platforms/macos/configuration-profiles/ddm-demo-safari-settings.mobileconfig) | `com.apple.Safari` | `com.apple.configuration.safari.settings` | `WarnAboutFraudulentWebsites` → `AllowDisablingFraudWarning` (inverted sense — legacy warns, DDM allows disabling the warning) · `...WebKit2JavaScriptEnabled` → `AllowJavaScript` · `...WebKit2JavaScriptCanOpenWindowsAutomatically` → `AllowPopups` · `...WebKit2PrivateBrowsingEnabled` → `AllowPrivateBrowsing` |
| 2 | [ddm-demo-caldav-account.mobileconfig](../platforms/macos/configuration-profiles/ddm-demo-caldav-account.mobileconfig) | `com.apple.caldav.account` | `com.apple.configuration.account.caldav` | `CalDAVHostName` → `HostName` · `CalDAVPort` → `Port` · `CalDAVAccountDescription` → `VisibleName` · `CalDAVPrincipalURL` → `Path` · `CalDAVUsername`/`CalDAVPassword` → `AuthenticationCredentialsAssetReference` (credentials move out of the declaration into a separate Asset) |
| 3 | [ddm-demo-exchange-account.mobileconfig](../platforms/macos/configuration-profiles/ddm-demo-exchange-account.mobileconfig) | `com.apple.eas.account` | `com.apple.configuration.account.exchange` | `Host` → `HostName` · `EnableMail`/`EnableContacts`/`EnableCalendars`/`EnableReminders`/`EnableNotes` → `MailServiceActive`/`ContactsServiceActive`/`CalendarServiceActive`/`RemindersServiceActive`/`NotesServiceActive` (near-verbatim rename) · `OAuth`/`OAuthSignInURL`/`OAuthTokenRequestURL` → `OAuth.Enabled`/`OAuth.SignInURL`/`OAuth.TokenRequestURL` (nested) · `EmailAddress`/`UserName`/`Password` → `UserIdentityAssetReference`/`AuthenticationCredentialsAssetReference` |
| 4 | [ddm-demo-root-certificate.mobileconfig](../platforms/macos/configuration-profiles/ddm-demo-root-certificate.mobileconfig) | `com.apple.security.root` | `com.apple.configuration.security.certificate` + `com.apple.asset.credential.certificate` | Apple's own canonical DDM pattern: the legacy profile embeds the DER cert bytes directly in `PayloadContent`; DDM splits this into an **asset** (`com.apple.asset.credential.certificate`, cert delivered by reference — URL + SHA-256 hash — not embedded) and a thin **configuration** (`com.apple.configuration.security.certificate`) that just points at the asset via `CredentialAssetReference`. Good example of DDM's data/policy split, not just a key rename. The embedded cert is a throwaway self-signed "Kitzy DDM Demo Root CA" — not used for anything real. |

## Confirmed via `contour profile validate`

Running `contour` locally surfaced something worth mentioning live: its
deprecation lint flags `com.apple.caldav.account` and `com.apple.eas.account`
explicitly —

> legacy payload still works on macOS ≤25 but stops working on macOS 26+

— i.e. these two aren't just "DDM is nicer," they're on a real clock. That's
a stronger demo hook than "Apple recommends migrating."

## Two categories from the original ask that did NOT make it in

Checked while assembling this and worth saying out loud if asked:

- **FileVault** — `com.apple.MCX.FileVault2` (legacy) does **not** map to
  `com.apple.configuration.diskmanagement.settings`. That DDM type only
  covers external/network storage restrictions (`Restrictions.ExternalStorage`,
  `Restrictions.NetworkStorage`) — a different feature entirely. FileVault
  enablement itself has no DDM declaration; it's handled by Fleet's own
  `controls.enable_disk_encryption`, not a profile at all.
- **Screen sharing** — `com.apple.configuration.screensharing.host.settings`
  has no legacy profile predecessor to convert from; screen-sharing host
  policy wasn't configurable via `.mobileconfig` before DDM, so there's no
  "before" state to show.

## Post-demo audit corrections (2026-08-25)

Ahead of converting these for real, each of the four was re-checked against
Apple's own `device-management` schema (not just `contour profile validate`,
which only checks payload shape — it doesn't check per-OS-platform field
availability). Two corrections to the table above:

- **Safari settings is *not* clean on macOS.** Of the four fields this
  profile sets, three (`AllowDisablingFraudWarning`, `AllowJavaScript`,
  `AllowPopups`) are marked `macOS: introduced: n/a` in Apple's
  `declarative/declarations/configurations/safari.settings.yaml` — they
  exist on iOS/visionOS only. Only `AllowPrivateBrowsing` has a macOS
  equivalent today. Converting as originally planned would silently drop
  fraud-warning/JS/popup enforcement, so this one is **not** converted —
  see the PR for the actual disposition.
- **Root certificate is a clean field mapping but not a clean conversion
  here.** `com.apple.asset.credential.certificate` requires the cert bytes
  at a real `https://` URL with a SHA-256 hash — Fleet does not host asset
  payloads for you (per Fleet's own DDM guide: "host the manifest and
  package on your own infrastructure"), and this repo has no such hosting
  today. Needs a decision on where to host it before this converts.
- **The "stops working on macOS 26+" deprecation claim (CalDAV/EAS) could
  not be confirmed against Apple's own documentation.** Checked Apple's
  `device-management` GitHub schema (no `deprecated` marker on either
  payload type), the WWDC26 device management updates support page, and
  Apple's developer docs — none corroborate a hard cutoff for these two.
  The claim appears to be `contour`'s own lint heuristic, not an
  Apple-sourced fact. CalDAV/Exchange still convert to DDM because it's the
  right architecture regardless — Exchange in particular gains macOS support
  DDM never had via the legacy payload (`com.apple.eas.account` was iOS/visionOS
  only; `com.apple.configuration.account.exchange` supports macOS 13+).

## Cleanup after the demo

These are demo-only and have no real backing services — safe to delete from
`fleets/testing.yml` and `platforms/macos/configuration-profiles/` (all four
`ddm-demo-*.mobileconfig` files) whenever you're done with them. Removing
the file and its `path:` entry together removes the profile from any
enrolled testing hosts on the next `fleetctl gitops` apply.
