#!/usr/bin/env bash

# create-repo.sh
# Script to create a new GitHub repository from the benoram/template and configure it
# Usage: ./create-repo.sh <owner> <name>

set -euo pipefail

# Check if running in Codespaces
if [ -n "${CODESPACES:-}" ]; then
    echo "Error: This script cannot be run in GitHub Codespaces."
    echo ""
    echo "Please clone the repository and run this script locally:"
    echo ""
    echo "  # Clone the repository"
    echo "  git clone https://github.com/benoram/template.git"
    echo "  cd template"
    echo ""
    echo "  # Run the script"
    echo "  ./scripts/create-repo.sh <owner> <name>"
    echo ""
    exit 1
fi

# Function to prompt for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    echo "${prompt}" >&2
    if [ -n "${default}" ]; then
        echo "Default: ${default}" >&2
        read -r -p "Enter value (or press Enter to accept default): " value
    else
        read -r -p "Enter value: " value
    fi
    
    # If no value entered, use the default
    if [ -z "${value}" ]; then
        echo "${default}"
    else
        echo "${value}"
    fi
}

# Check if parameters are provided, otherwise prompt
if [ $# -eq 0 ]; then
    # No parameters provided, prompt for both
    echo "Repository Creation"
    echo "==================="
    echo ""
    OWNER=$(prompt_with_default "Repository owner:" "benoram")
    echo ""
    NAME=$(prompt_with_default "Repository name:" "")
    echo ""
elif [ $# -eq 1 ]; then
    # Only one parameter provided, prompt for the missing one
    echo "Repository Creation"
    echo "==================="
    echo ""
    OWNER=$(prompt_with_default "Repository owner:" "benoram")
    echo ""
    NAME="$1"
else
    # Both parameters provided
    OWNER="$1"
    NAME="$2"
fi

# Validate that we have both values
if [ -z "${OWNER}" ] || [ -z "${NAME}" ]; then
    echo "Error: Both owner and repository name are required."
    echo "Usage: $0 [owner] [name]"
    echo "Example: $0 benoram myrepo"
    exit 1
fi

REPO_FULL="${OWNER}/${NAME}"
TEMPLATE_REPO="benoram/template"

# Ensure GitHub CLI is installed
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not installed or not found in PATH."
    echo "Please install GitHub CLI from https://cli.github.com/ and try again."
    exit 1
fi

# Ensure the user is authenticated with GitHub CLI
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not authenticated."
    echo "Please run 'gh auth login' to authenticate, then re-run this script."
    exit 1
fi

echo "Creating repository: ${REPO_FULL}"
echo "========================================"

# Step 1: Create repository from template
echo ""
echo "Step 1: Creating repository from template ${TEMPLATE_REPO}..."

if ! gh repo create "${REPO_FULL}" \
    --template "${TEMPLATE_REPO}" \
    --private \
    --clone=false; then
    echo "✗ Failed to create repository ${REPO_FULL}"
    echo "  This may happen if:"
    echo "  - A repository with this name already exists"
    echo "  - You don't have sufficient permissions to create a repository for ${OWNER}"
    echo "  - The template repository ${TEMPLATE_REPO} doesn't exist or is not accessible"
    exit 1
fi

echo "✓ Repository ${REPO_FULL} created successfully from template"

# Step 2: Run configure-repo.sh to apply standard settings
echo ""
echo "Step 2: Configuring repository with standard settings..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURE_SCRIPT="${SCRIPT_DIR}/configure-repo.sh"

# Check if configure-repo.sh exists
if [ ! -f "${CONFIGURE_SCRIPT}" ]; then
    echo "✗ Error: configure-repo.sh not found at ${CONFIGURE_SCRIPT}"
    echo "  The repository was created but could not be configured."
    echo "  Please run configure-repo.sh manually."
    exit 1
fi

# Run configure-repo.sh
if ! "${CONFIGURE_SCRIPT}" "${OWNER}" "${NAME}"; then
    echo "✗ Failed to configure repository ${REPO_FULL}"
    echo "  The repository was created but configuration failed."
    echo "  You can try running configure-repo.sh manually:"
    echo "  ${CONFIGURE_SCRIPT} ${OWNER} ${NAME}"
    exit 1
fi

echo ""
echo "========================================"
echo "Repository creation and configuration completed successfully!"
echo ""
echo "Repository: ${REPO_FULL}"
echo "Template: ${TEMPLATE_REPO}"
echo ""
echo "Next steps:"
echo "  - Clone the repository: gh repo clone ${REPO_FULL}"
echo "  - Enable Copilot code review in the ruleset via GitHub UI"
echo "  - Start developing!"