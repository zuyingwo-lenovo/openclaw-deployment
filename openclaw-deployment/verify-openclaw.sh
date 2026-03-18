#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo -e "\e[32m[OK]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
info() { echo -e "\e[34m[INFO]\e[0m $1"; }

info "Starting OpenClaw Verification..."

# 1. Version check
if command -v openclaw &> /dev/null; then
    VERSION=$(openclaw --version)
    log "OpenClaw installed: $VERSION"
else
    error "openclaw command not found."
    exit 1
fi

# 2. Doctor check
info "Running openclaw doctor..."
if openclaw doctor > /dev/null 2>&1; then
    log "openclaw doctor passed."
else
    warn "openclaw doctor reported issues. Run 'openclaw doctor' manually for details."
fi

# 3. Gateway status
info "Checking Gateway status..."
if systemctl --user is-active --quiet openclaw-gateway; then
    log "Gateway systemd service is active."
else
    warn "Gateway systemd service is NOT active."
fi

if openclaw gateway status > /dev/null 2>&1; then
    log "Gateway is responding to CLI."
else
    warn "Gateway CLI check failed. Is it running?"
fi

# 4. Skills list
info "Checking Skills..."
openclaw skills list > /dev/null 2>&1 && log "Skills list retrievable." || warn "Failed to retrieve skills list."
info "Eligible skills:"
openclaw skills list --eligible | head -n 5
echo "..."

# 5. Browser check
info "Checking Browser configuration..."
if openclaw browser --browser-profile openclaw status > /dev/null 2>&1; then
    log "OpenClaw managed browser is accessible."
else
    warn "OpenClaw managed browser check failed. Ensure 'browser.enabled: true' in config."
fi

info "Verification complete."
