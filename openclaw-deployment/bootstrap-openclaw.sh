#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="bootstrap-openclaw.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log "Starting OpenClaw WSL2 Bootstrap..."

# 1. Update and install system dependencies
log "Installing system dependencies..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget git zip unzip jq ripgrep fd-find build-essential \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libgbm1 libasound2 ffmpeg imagemagick sqlite3 p7zip-full

# Link fdfind to fd if needed
if ! command -v fd &> /dev/null && command -v fdfind &> /dev/null; then
    mkdir -p ~/.local/bin
    ln -s $(command -v fdfind) ~/.local/bin/fd
    export PATH="$HOME/.local/bin:$PATH"
fi

# 2. Install Python tooling (uv, pipx)
log "Setting up Python tooling..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip pipx
pipx ensurepath

# 3. Install Node.js (v24 recommended by OpenClaw)
log "Installing Node.js 24..."
if ! command -v node &> /dev/null || [[ $(node -v) != v24* ]]; then
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

# Install pnpm and bun
log "Installing Node package managers..."
sudo npm install -g pnpm bun

# 4. Install OpenClaw
log "Installing OpenClaw CLI..."
# Using npm install as it's more predictable for scripting than the interactive bash installer
sudo npm install -g openclaw@latest

# 5. Initialize OpenClaw Directories
log "Initializing OpenClaw directories..."
OPENCLAW_HOME="$HOME/.openclaw"
WORKSPACE_DIR="$HOME/openclaw-workspace"

mkdir -p "$OPENCLAW_HOME"/{skills,logs,tmp}
mkdir -p "$WORKSPACE_DIR"/{skills,data}

# 6. Generate Base Configuration
log "Generating base configuration..."
cp openclaw.base.json "$OPENCLAW_HOME/openclaw.json"
cp .env.example "$OPENCLAW_HOME/.env"

# 7. Configure Systemd Gateway Service
log "Setting up OpenClaw Gateway service..."
# Enable linger so user services start at boot without login
sudo loginctl enable-linger "$(whoami)"

# Install daemon non-interactively
openclaw onboard --non-interactive --install-daemon --skip-health || true

# Wait for service to start
sleep 5
if systemctl --user is-active --quiet openclaw-gateway; then
    log "Gateway service is running."
else
    error "Gateway service failed to start. Check logs with: journalctl --user -u openclaw-gateway"
fi

# 8. Setup Chromium for OpenClaw-managed browser
log "Ensuring Chromium is available for OpenClaw browser tool..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser

log "Bootstrap completed successfully."
log "Next steps:"
log "1. Review and fill out ~/.openclaw/.env"
log "2. Run ./install-skills.sh to provision skills"
log "3. Run ./verify-openclaw.sh to confirm setup"
