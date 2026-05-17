#!/bin/bash
# Installs a LaunchDaemon that re-asserts GuestEnabled=false on the
# loginwindow preferences plist whenever it is modified.
#
# Why this exists: on macOS 26 (Tahoe) the System Settings -> Users &
# Groups -> "Allow guests to log in to this computer" toggle writes
# directly to /Library/Preferences/com.apple.loginwindow GuestEnabled,
# and the OS honors that user-level write even when a managed
# preference (com.apple.loginwindow Forced GuestEnabled=false, delivered
# by disable-guest.mobileconfig) says otherwise. The com.apple.MCX
# DisableGuestAccount key is still honored by loginwindow itself, but
# nothing prevents the toggle from flipping in the UI. This daemon
# closes that gap by reverting the plist within ~1s of any change.

set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo "[disable-guest-enforce] must run as root (Fleet scripts run as root)"
  exit 1
fi

DAEMON_LABEL="net.kitzy.disable-guest-enforce"
DAEMON_PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
HELPER_SCRIPT="/usr/local/bin/disable-guest-enforce.sh"

mkdir -p /usr/local/bin

cat > "$HELPER_SCRIPT" <<'HELPER'
#!/bin/bash
# Reverts the guest-related preferences that the macOS 26 Users & Groups
# UI lets the local user toggle on despite the managed configuration
# profile. Triggered by the WatchPaths in net.kitzy.disable-guest-enforce.
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false 2>/dev/null || true
defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool false 2>/dev/null || true
HELPER
chmod 755 "$HELPER_SCRIPT"
chown root:wheel "$HELPER_SCRIPT"

cat > "$DAEMON_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${DAEMON_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HELPER_SCRIPT}</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>/Library/Preferences/com.apple.loginwindow.plist</string>
    <string>/Library/Preferences/com.apple.AppleFileServer.plist</string>
    <string>/Library/Preferences/SystemConfiguration/com.apple.smb.server.plist</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>2</integer>
  <key>StandardOutPath</key>
  <string>/var/log/disable-guest-enforce.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/disable-guest-enforce.log</string>
</dict>
</plist>
PLIST
chmod 644 "$DAEMON_PLIST"
chown root:wheel "$DAEMON_PLIST"

launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
launchctl bootstrap system "$DAEMON_PLIST"
launchctl kickstart -k "system/${DAEMON_LABEL}"

echo "[disable-guest-enforce] installed ${DAEMON_LABEL} and re-asserted guest preferences"
