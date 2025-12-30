# GitHub Copilot Instructions

This file provides guidance to GitHub Copilot for working with this repository.

## Tech Stack

### Development Platform
- **Primary Development**: GitHub Copilot (via GitHub Issues assignment or GitHub Codespaces)
- **Operating Systems**: Mac (Apple Silicon) and Ubuntu-based Codespaces
- **Version Control**: Git with GitHub

### Deployment Platforms
- Mac (Apple Silicon)
- Ubuntu
- Docker
- Kubernetes
- **Supported Architectures**: x64 and ARM64

## Development Workflow

Follow this workflow for all development tasks:

1. Create a GitHub issue
2. Create a branch using the branch naming conventions (see below)
3. Write code
4. Test locally
5. Commit tested code
6. Create a pull request (update the GitHub issue appropriately)
7. Review code
8. Merge to default branch

## Secrets Management

**Critical**: Secrets are never allowed in the repository.

Secrets must be stored in one of the following locations:
- GitHub Secrets (for GitHub Actions)
- GitHub Codespaces Secrets
- 1Password

## Branch Naming Conventions

Follow these conventions when creating branches:

1. **Lowercase and Hyphen-separated**: Use lowercase for branch names and hyphens to separate words
   - Example: `feature/new-login` or `bugfix/header-styling`

2. **Alphanumeric Characters**: Use only lowercase alphanumeric characters (a-z, 0-9) and hyphens
   - Avoid punctuation, spaces, underscores, or any non-alphanumeric character

3. **Descriptive**: The name should be descriptive and concise, ideally reflecting the work done on the branch

4. **Branch Prefixes**:
   - **Feature Branches**: `feature/` - For developing new features
     - Example: `feature/login-system`
   - **Bugfix Branches**: `bugfix/` - For fixing bugs in the code
     - Example: `bugfix/header-styling`
   - **Documentation Branches**: `docs/` - For writing, updating, or fixing documentation (e.g., README.md)
     - Example: `docs/api-endpoints`

## Project and Code Guidelines

- Always follow good security practices
- Use scripts to perform actions when available
- Always keep documentation up-to-date with the code

## Project Structure

The repository follows this structure:

- `scripts/` - Development, deployment and testing scripts
- `docs/` - Project documentation to be kept in sync at all times
- `infra/` - Source code for Terraform and other infrastructure-as-code tools
- `src/` - Source code for projects/apps

## Documentation Guidelines

- The project `README.md` should be clean and concise and act as a table of contents for documentation stored in the `docs/` directory
- Keep all documentation synchronized with code changes
- Update relevant documentation when making code changes
