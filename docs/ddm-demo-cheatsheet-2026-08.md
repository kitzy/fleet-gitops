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

## Update — converted ahead of macOS 27 (2026-08-26)

The demo is over, but instead of deleting these four profiles they became
the seed for the real macOS 27 readiness work: each now has a DDM
declaration counterpart (`ddm-demo-*-ddm.json` in
[../platforms/macos/declaration-profiles/](../platforms/macos/declaration-profiles/)),
and the Testing fleet targets the legacy `.mobileconfig` to hosts on
`macOS < 27` and the DDM declaration to hosts on `macOS 27` via the new
labels in [../labels/operating-systems.yml](../labels/operating-systems.yml).
The two field-mapping tables above still describe the conversions
accurately — they were generated and schema-validated with `contour`. **Do
not delete the `ddm-demo-*.mobileconfig` files** — they're the live
pre-macOS-27 fallback, not demo cruft.

Outstanding finding from this pass, unresolved: `contour`'s deprecation
lint (section above) says the CalDAV and Exchange legacy payloads stop
working on macOS 26+, not just 27+ — so any macOS 26 Testing host is
already silently receiving a dead profile for those two. The macOS 27
split requested for this change was implemented as asked; whether to move
the CalDAV/Exchange cutover back to macOS 26 is a follow-up decision, not
made here.

Gatekeeper enforcement (`enforce-gatekeeper.mobileconfig`) has no DDM
declaration type as of this writing (checked against `contour profile ddm
list`) and was left untouched, targeting all macOS versions.
