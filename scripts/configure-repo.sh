#!/usr/bin/env bash

# configure-repo.sh
# Script to configure GitHub repository settings and rulesets
# Usage: ./configure-repo.sh <owner> <repository>

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
    echo "  ./scripts/configure-repo.sh <owner> <repository>"
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
    echo "Repository Configuration"
    echo "======================="
    echo ""
    OWNER=$(prompt_with_default "Repository owner:" "benoram")
    echo ""
    REPO=$(prompt_with_default "Repository name:" "")
    echo ""
elif [ $# -eq 1 ]; then
    # Only one parameter provided, prompt for the missing one
    echo "Repository Configuration"
    echo "======================="
    echo ""
    OWNER=$(prompt_with_default "Repository owner:" "benoram")
    echo ""
    REPO="$1"
else
    # Both parameters provided
    OWNER="$1"
    REPO="$2"
fi

# Validate that we have both values
if [ -z "${OWNER}" ] || [ -z "${REPO}" ]; then
    echo "Error: Both owner and repository name are required."
    echo "Usage: $0 [owner] [repository]"
    echo "Example: $0 benoram myrepo"
    exit 1
fi
REPO_FULL="${OWNER}/${REPO}"

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

echo "Configuring repository: ${REPO_FULL}"
echo "========================================"

# Step 1: Configure repository settings using gh repo edit
echo ""
echo "Step 1: Configuring repository settings..."

if ! gh repo edit "${REPO_FULL}" \
    --enable-merge-commit=false \
    --enable-rebase-merge=false \
    --delete-branch-on-merge=true \
    --allow-update-branch=true; then
    echo "✗ Failed to configure repository settings for ${REPO_FULL}"
    echo "  This may happen if:"
    echo "  - The repository doesn't exist or the name is incorrect"
    echo "  - You don't have sufficient permissions to edit this repository"
    echo "  - Your GitHub CLI version doesn't support one of the specified flags"
    exit 1
fi

echo "✓ Repository settings configured successfully"

# Step 2: Create ruleset named "default"
echo ""
echo "Step 2: Creating ruleset 'default'..."

# Get the default branch name
if ! DEFAULT_BRANCH=$(gh api "repos/${REPO_FULL}" --jq '.default_branch'); then
    echo "Error: Failed to fetch default branch for repository '${REPO_FULL}'." >&2
    echo "       Ensure the repository exists and that you have the necessary permissions." >&2
    exit 1
fi

if [ -z "${DEFAULT_BRANCH}" ]; then
    echo "Error: Default branch name for repository '${REPO_FULL}' is empty or could not be determined." >&2
    exit 1
fi
echo "  Default branch: ${DEFAULT_BRANCH}"

# Create the ruleset JSON payload
# Note: Copilot code review auto-request should be added via GitHub UI
# Settings → Rules → Rulesets → "Automatically request Copilot code review"
# as the API structure for this feature is not fully documented
RULESET_PAYLOAD=$(cat <<EOF
{
  "name": "default",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/${DEFAULT_BRANCH}"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": 0,
        "required_review_thread_resolution": false
      }
    }
  ],
  "bypass_actors": []
}
EOF
)

# Create the ruleset
if ! gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "repos/${REPO_FULL}/rulesets" \
    --input - <<< "${RULESET_PAYLOAD}"; then
    echo "✗ Failed to create ruleset 'default'"
    echo "  This may happen if:"
    echo "  - A ruleset with this name already exists"
    echo "  - You don't have sufficient permissions"
    echo "  - The repository doesn't exist"
    exit 1
fi

echo "✓ Ruleset 'default' created successfully"

# Add Copilot code review to the ruleset
echo ""
echo "Step 3: Configuring Copilot code review..."
echo "  Note: Copilot code review must be enabled through GitHub UI"
echo "  1. Go to repository Settings → Rules → Rulesets"
echo "  2. Edit the 'default' ruleset"
echo "  3. Enable 'Automatically request Copilot code review'"
echo "  4. Optionally enable review on each push or for draft PRs"

echo ""
echo "========================================"
echo "Repository configuration completed!"
echo ""
echo "Summary:"
echo "  - Merge commits: disabled"
echo "  - Rebase merging: disabled"
echo "  - Squash merging: enabled (default)"
echo "  - Delete head branch on merge: enabled"
echo "  - Allow updating PR branches: enabled"
echo "  - Ruleset 'default': created and active"
echo "    - Target: ${DEFAULT_BRANCH} branch"
echo "    - Requires: pull request before merging"
echo "    - Dismisses: stale reviews on new commits"
echo ""
echo "Next steps:"
echo "  - Enable Copilot code review in the ruleset via GitHub UI"
echo "  - Review and test the configuration"

# Step 4: Information about GitHub Codespaces secrets for dotfiles
echo ""
echo "Step 4: Configuring GitHub Codespaces secrets for dotfiles..."
echo ""
echo "To enable dotfiles in GitHub Codespaces, you need to configure the following secrets:"
echo ""
echo "  Secret Name: DOTFILES_REPOSITORY"
echo "  Description: URL of your dotfiles repository"
echo "  Example: https://github.com/benoram/dotfiles"
echo ""
echo "  Secret Name: DOTFILES_INSTALL_COMMAND"
echo "  Description: Command to run to install dotfiles"
echo "  Example: bash bootstrap.sh"
echo ""
echo "========================================"