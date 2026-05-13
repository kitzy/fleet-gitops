#!/bin/bash
set -euo pipefail

# Ubuntu 24.04 Baseline Configuration - User and SSH
# Configures non-root user with sudo access and hardens SSH daemon

# Configuration variables
SSH_USER="${FLEET_SECRET_SSH_USER}"
SSH_PUBLIC_KEY="${FLEET_SECRET_SSH_PUBLIC_KEY}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

validate_inputs() {
    if [[ -z "$SSH_PUBLIC_KEY" ]]; then
        log_error "SSH_PUBLIC_KEY environment variable is required"
        exit 1
    fi

    if [[ ! "$SSH_PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        log_error "SSH_PUBLIC_KEY does not appear to be a valid SSH public key"
        exit 1
    fi
}

create_SSH_USER() {
    if id "$SSH_USER" &>/dev/null; then
        log_warn "User $SSH_USER already exists, skipping creation"
    else
        log_info "Creating user $SSH_USER"
        useradd -m -s /bin/bash "$SSH_USER"
    fi

    if groups "$SSH_USER" | grep -q '\bsudo\b'; then
        log_warn "User $SSH_USER already in sudo group, skipping"
    else
        log_info "Adding $SSH_USER to sudo group"
        usermod -aG sudo "$SSH_USER"
    fi
}

configure_passwordless_sudo() {
    local sudoers_file="/etc/sudoers.d/$SSH_USER"
    local sudoers_content="$SSH_USER ALL=(ALL) NOPASSWD:ALL"

    if [[ -f "$sudoers_file" ]]; then
        if grep -q "^$sudoers_content$" "$sudoers_file"; then
            log_warn "Passwordless sudo already configured for $SSH_USER, skipping"
            return
        fi
    fi

    log_info "Configuring passwordless sudo for $SSH_USER"
    echo "$sudoers_content" > "$sudoers_file"
    chmod 0440 "$sudoers_file"
    
    if ! visudo -c -f "$sudoers_file" &>/dev/null; then
        log_error "Sudoers file validation failed"
        rm -f "$sudoers_file"
        exit 1
    fi
}

deploy_ssh_key() {
    local ssh_dir="/home/$SSH_USER/.ssh"
    local authorized_keys="$ssh_dir/authorized_keys"

    if [[ ! -d "$ssh_dir" ]]; then
        log_info "Creating $ssh_dir"
        mkdir -p "$ssh_dir"
    fi

    if [[ -f "$authorized_keys" ]] && grep -qF "$SSH_PUBLIC_KEY" "$authorized_keys"; then
        log_warn "SSH key already present in authorized_keys, skipping"
    else
        log_info "Adding SSH public key to authorized_keys"
        echo "$SSH_PUBLIC_KEY" >> "$authorized_keys"
    fi

    log_info "Setting correct permissions on $ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$authorized_keys"
    chown -R "$SSH_USER:$SSH_USER" "$ssh_dir"
}

harden_sshd_config() {
    local sshd_config="/etc/ssh/sshd_config"
    local needs_restart=false

    log_info "Hardening SSH daemon configuration"

    declare -A ssh_settings=(
        ["PermitRootLogin"]="no"
        ["PasswordAuthentication"]="no"
        ["ChallengeResponseAuthentication"]="no"
        ["PubkeyAuthentication"]="yes"
        ["ClientAliveInterval"]="60"
        ["ClientAliveCountMax"]="3"
    )

    for setting in "${!ssh_settings[@]}"; do
        local value="${ssh_settings[$setting]}"
        
        if grep -qE "^#?${setting}\s+" "$sshd_config"; then
            local current_value
            current_value=$(grep -E "^#?${setting}\s+" "$sshd_config" | tail -1 | awk '{print $2}')
            
            if [[ "$current_value" == "$value" ]] && ! grep -qE "^#${setting}\s+" "$sshd_config"; then
                log_warn "$setting already set to $value, skipping"
            else
                log_info "Setting $setting to $value"
                sed -i "s/^#\?${setting}\s.*/${setting} ${value}/" "$sshd_config"
                needs_restart=true
            fi
        else
            log_info "Adding $setting $value to sshd_config"
            echo "$setting $value" >> "$sshd_config"
            needs_restart=true
        fi
    done

    if sshd -t; then
        log_info "SSH configuration validation passed"
    else
        log_error "SSH configuration validation failed"
        exit 1
    fi

    if [[ "$needs_restart" == true ]]; then
        log_info "Restarting SSH daemon"
        systemctl restart sshd || systemctl restart ssh
    else
        log_warn "No SSH configuration changes needed, skipping restart"
    fi
}

main() {
    log_info "Starting Ubuntu 24.04 baseline user and SSH configuration"
    
    check_root
    validate_inputs
    create_SSH_USER
    configure_passwordless_sudo
    deploy_ssh_key
    harden_sshd_config
    
    log_info "Configuration complete"
    log_info "Verify SSH access with: ssh $SSH_USER@<hostname>"
}

main "$@"