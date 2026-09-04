#!/bin/bash
set -euo pipefail

# Ubuntu unattended OS patching
# Installs and configures unattended-upgrades for automatic security updates,
# with reboots staggered via systemd's timer randomization so a cluster's
# nodes don't all restart in the same window.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

OVERRIDES_CONF="/etc/apt/apt.conf.d/51unattended-upgrades-fleet-overrides"
GENERAL_UPDATES_CONF="/etc/apt/apt.conf.d/52unattended-upgrades-general-updates"
TIMER_DROPIN_DIR="/etc/systemd/system/apt-daily-upgrade.timer.d"
TIMER_DROPIN="$TIMER_DROPIN_DIR/override.conf"
REBOOT_WINDOW="4h"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

is_k3s_node() {
    pgrep -x 'k3s-server|k3s-agent' &>/dev/null
}

install_unattended_upgrades() {
    if dpkg -s unattended-upgrades &>/dev/null; then
        log_warn "unattended-upgrades already installed, skipping"
    else
        log_info "Installing unattended-upgrades"
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades
    fi
}

enable_periodic_updates() {
    local conf="/etc/apt/apt.conf.d/20auto-upgrades"
    local content='APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";'

    if [[ -f "$conf" ]] && [[ "$(cat "$conf")" == "$content" ]]; then
        log_warn "Periodic update/upgrade already enabled, skipping"
    else
        log_info "Enabling daily apt update + unattended upgrade"
        echo "$content" > "$conf"
    fi
}

configure_auto_reboot() {
    # A separate file, not an edit to the package-owned 50unattended-upgrades,
    # so apt package upgrades never trigger a conffile prompt.
    local content='// Managed by fleet-gitops (enable-unattended-upgrades.sh) - do not edit 50unattended-upgrades directly
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";'

    if [[ -f "$OVERRIDES_CONF" ]] && [[ "$(cat "$OVERRIDES_CONF")" == "$content" ]]; then
        log_warn "Automatic reboot already configured, skipping"
    else
        log_info "Enabling automatic reboot after unattended upgrades"
        echo "$content" > "$OVERRIDES_CONF"
    fi
}

enable_general_updates() {
    # 50unattended-upgrades' default Allowed-Origins only covers the
    # -security pocket. Reopening the scope in a later-loaded file adds to
    # it rather than replacing it (apt.conf lists can only be cleared with
    # #clear, never overridden), so this only needs the one extra origin.
    local content='Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-updates";
};'

    if [[ -f "$GENERAL_UPDATES_CONF" ]] && [[ "$(cat "$GENERAL_UPDATES_CONF")" == "$content" ]]; then
        log_warn "General updates already enabled, skipping"
    else
        log_info "Enabling general (non-security) updates via unattended-upgrades"
        echo "$content" > "$GENERAL_UPDATES_CONF"
    fi
}

stagger_reboot_window() {
    mkdir -p "$TIMER_DROPIN_DIR"
    local content="[Timer]
RandomizedDelaySec=$REBOOT_WINDOW"

    if [[ -f "$TIMER_DROPIN" ]] && [[ "$(cat "$TIMER_DROPIN")" == "$content" ]]; then
        log_warn "Reboot staggering already configured, skipping"
    else
        log_info "Widening apt-daily-upgrade.timer's randomized delay to $REBOOT_WINDOW so hosts don't reboot together"
        printf '%s\n' "$content" > "$TIMER_DROPIN"
        systemctl daemon-reload
    fi
}

enable_timers() {
    log_info "Ensuring apt timers are enabled and running"
    systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
}

main() {
    log_info "Configuring unattended OS patching"

    check_root
    install_unattended_upgrades
    enable_periodic_updates
    configure_auto_reboot

    if is_k3s_node; then
        log_warn "k3s node detected, skipping general (non-security) updates"
    else
        enable_general_updates
    fi

    stagger_reboot_window
    enable_timers

    log_info "Unattended OS patching configured"
}

main "$@"
