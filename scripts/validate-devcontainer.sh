#!/usr/bin/env bash
#
# validate-devcontainer.sh
# Validates the devcontainer.json configuration
# Usage: ./validate-devcontainer.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVCONTAINER_JSON="$REPO_ROOT/.devcontainer/devcontainer.json"

echo "Validating devcontainer configuration..."

# Check if devcontainer.json exists
if [[ ! -f "$DEVCONTAINER_JSON" ]]; then
    echo "❌ Error: devcontainer.json not found at $DEVCONTAINER_JSON"
    exit 1
fi

# Validate JSON syntax
if ! python3 -m json.tool "$DEVCONTAINER_JSON" > /dev/null 2>&1; then
    echo "❌ Error: devcontainer.json is not valid JSON"
    exit 1
fi

echo "✅ devcontainer.json is valid JSON"

# Parse devcontainer.json using jq or python
if command -v jq >/dev/null 2>&1; then
    DOTFILES_REPO=$(jq -r '.dotfilesRepository // empty' "$DEVCONTAINER_JSON")
    DOTFILES_INSTALL_CMD=$(jq -r '.dotfilesInstallCommand // empty' "$DEVCONTAINER_JSON")
else
    # Python fallback with better readability
    DOTFILES_REPO=$(python3 -c \
        "import json; data=json.load(open('$DEVCONTAINER_JSON')); print(data.get('dotfilesRepository', ''))" \
        2>/dev/null || echo "")
    DOTFILES_INSTALL_CMD=$(python3 -c \
        "import json; data=json.load(open('$DEVCONTAINER_JSON')); print(data.get('dotfilesInstallCommand', ''))" \
        2>/dev/null || echo "")
fi

# Check for required dotfiles configuration
if [[ -z "$DOTFILES_REPO" || "$DOTFILES_REPO" == "null" ]]; then
    echo "❌ Error: dotfilesRepository is not configured in devcontainer.json"
    exit 1
fi

echo "✅ dotfilesRepository is configured"

# Check for dotfilesInstallCommand (required, no default)
if [[ -z "$DOTFILES_INSTALL_CMD" || "$DOTFILES_INSTALL_CMD" == "null" ]]; then
    echo "❌ Error: dotfilesInstallCommand is not configured in devcontainer.json"
    exit 1
fi

echo "✅ dotfilesInstallCommand is configured: $DOTFILES_INSTALL_CMD"

# Verify dotfiles repository URL is set (but not hardcoded to specific value)
if [[ "$DOTFILES_REPO" == *'${localEnv:'* ]]; then
    echo "✅ dotfilesRepository is configured to use environment variable"
    echo "   Note: Set DOTFILES_REPOSITORY in your Codespaces secrets or local environment"
else
    echo "✅ dotfilesRepository URL is set to: $DOTFILES_REPO"
fi

# Check if post-create.sh exists and is executable
POST_CREATE="$REPO_ROOT/.devcontainer/post-create.sh"
if [[ ! -f "$POST_CREATE" ]]; then
    echo "❌ Error: post-create.sh not found"
    exit 1
fi

if [[ ! -x "$POST_CREATE" ]]; then
    echo "❌ Error: post-create.sh is not executable"
    exit 1
fi

echo "✅ post-create.sh exists and is executable"

# Verify post-create.sh does not duplicate Starship configuration
if grep -q 'starship init' "$POST_CREATE"; then
    echo "❌ Error: post-create.sh contains Starship initialization, which conflicts with dotfiles"
    echo "   Starship should be configured via the dotfiles repository only"
    exit 1
fi

echo ""
echo "✅ All validations passed!"
echo ""
echo "Devcontainer configuration is correctly set up to:"
echo "  - Clone dotfiles from: $DOTFILES_REPO"
echo "  - Run install command: $DOTFILES_INSTALL_CMD"
echo "  - Execute post-create.sh for additional setup"
