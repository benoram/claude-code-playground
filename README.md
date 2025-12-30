# template
Repository template with a standard tool set

## Development Environment

### Devcontainer

This repository includes a devcontainer configuration for GitHub Codespaces and VS Code Remote Containers.

**Location:** `/.devcontainer/devcontainer.json`

**Installed Software:**
- **Shell Environment:**
  - Bash (with Starship prompt)
  - Zsh with Oh My Zsh (with Starship prompt, set as default)
- **Version Control:**
  - Git (latest version from PPA)
  - GitHub CLI
- **Package Managers:**
  - Homebrew (for additional tooling)
- **Cloud & Infrastructure Tools:**
  - AWS CLI
  - GitHub Copilot CLI
  - Terraform
  - k9s (Kubernetes CLI tool)
- **Development Tools:**
  - .NET SDK
  - 1Password CLI
- **Network Tools:**
  - whois - Domain information lookup
  - wget - File download utility
  - dig (dnsutils) - DNS lookup utility
  - telnet - Telnet client
- **Prompt:**
  - Starship - Cross-shell prompt configured for both bash and zsh

**Features:**
- Automatic package upgrades on container creation
- **Dotfiles Integration:** Automatically clones and applies personal dotfiles from your configured repository
  - **Required:** Set `DOTFILES_REPOSITORY` in your GitHub Codespaces secrets (e.g., `https://github.com/yourusername/dotfiles`)
  - **Required:** Set `DOTFILES_INSTALL_COMMAND` in your GitHub Codespaces secrets (e.g., `bash bootstrap.sh`)
  - Applies shell configurations (bash and zsh) with Starship prompt
  - Applies git configuration and aliases
  - Applies custom environment variables and aliases
- All network and development tools pre-installed and ready to use

## Scripts

### create-repo.sh

Creates a new GitHub repository from the benoram/template repository and automatically configures it with standard settings.

**Location:** `/scripts/create-repo.sh`

**Usage:**
```bash
./scripts/create-repo.sh <owner> <name>
```

**Example:**
```bash
./scripts/create-repo.sh myorg myrepo
```

**What it does:**
- Creates a new private repository from the benoram/template repository
- Automatically runs configure-repo.sh to apply standard settings
- Provides next steps for cloning and using the new repository

**Requirements:**
- [GitHub CLI](https://cli.github.com/) must be installed
- You must be authenticated with GitHub CLI (`gh auth login`)
- You must have permissions to create repositories for the specified owner
- The benoram/template repository must be accessible

**Note:** After running this script, you'll still need to enable Copilot code review manually through the GitHub UI. See the script output for instructions.

### configure-repo.sh

Automates GitHub repository settings and ruleset configuration using the GitHub CLI.

**Location:** `/scripts/configure-repo.sh`

**Usage:**
```bash
./scripts/configure-repo.sh <owner> <repository>
```

**Example:**
```bash
./scripts/configure-repo.sh myorg myrepo
```

**What it does:**
- Disables merge commits and rebase merging (enforces squash-only workflow)
- Enables automatic deletion of head branches after merge
- Enables pull request branch update suggestions
- Creates a "default" ruleset that:
  - Targets the default branch
  - Requires pull requests before merging
  - Dismisses stale pull request approvals when new commits are pushed
- Configures GitHub Codespaces secrets for dotfiles integration:
  - `DOTFILES_REPOSITORY` (default: `https://github.com/benoram/dotfiles`)
  - `DOTFILES_INSTALL_COMMAND` (default: `bash bootstrap.sh`)
  - Prompts for confirmation or custom values for each secret

**Requirements:**
- [GitHub CLI](https://cli.github.com/) must be installed
- You must be authenticated with GitHub CLI (`gh auth login`)
- You must have admin permissions on the target repository

**Note:** Automatic Copilot code review must be enabled manually through the GitHub UI after running the script. See the script output for instructions.

### validate-devcontainer.sh

Validates the devcontainer configuration to ensure it's properly set up.

**Location:** `/scripts/validate-devcontainer.sh`

**Usage:**
```bash
./scripts/validate-devcontainer.sh
```

**What it does:**
- Validates that devcontainer.json is valid JSON
- Checks that required dotfiles configuration fields are present
- Verifies that post-create.sh exists and is executable
- Ensures no conflicting configurations exist (e.g., duplicate Starship setup)

**Requirements:**
- `jq` (recommended) or Python 3 for JSON parsing
- Bash shell

**When to use:**
- After modifying devcontainer.json configuration
- When troubleshooting devcontainer setup issues
- As part of CI/CD validation

