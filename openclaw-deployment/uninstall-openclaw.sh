#!/usr/bin/env bash
set -euo pipefail

read -p "This will stop and remove OpenClaw. Are you sure? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "Stopping Gateway service..."
systemctl --user stop openclaw-gateway || true
systemctl --user disable openclaw-gateway || true

echo "Uninstalling OpenClaw CLI..."
sudo npm uninstall -g openclaw

echo "Removing Gateway service files..."
rm -f ~/.config/systemd/user/openclaw-gateway.service
systemctl --user daemon-reload

read -p "Do you want to delete ~/.openclaw configuration and logs? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.openclaw
    echo "~/.openclaw removed."
fi

read -p "Do you want to delete the workspace directory (~/openclaw-workspace)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/openclaw-workspace
    echo "Workspace removed."
fi

echo "Uninstallation complete."
