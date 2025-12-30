#!/usr/bin/env bash

# post-create.sh
# Script to configure devcontainer after creation
# Installs additional packages

set -euo pipefail

echo "Installing system packages..."
sudo apt-get update
sudo apt-get install -y whois wget dnsutils telnet

echo "Installing 1password-cli via homebrew..."
# Ensure Homebrew is available in the current shell
if ! command -v brew >/dev/null 2>&1; then
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

if command -v brew >/dev/null 2>&1; then
    brew install 1password-cli
else
    echo "Homebrew not found; skipping 1password-cli installation." >&2
fi

echo "Devcontainer setup complete!"
echo "Note: Shell configurations (bash/zsh) and Starship prompt are managed by dotfiles repository."
