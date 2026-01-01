# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a devcontainer-based development environment for Claude Code with secure AWS access via IAM Roles Anywhere. It supports both GitHub Codespaces and local development.

## AWS Infrastructure Commands

### Generate Certificates (required for initial setup)
```bash
cd aws-infrastructure
./generate-certificates.sh
```

### Deploy CloudFormation Stack
```bash
aws cloudformation deploy \
  --template-file aws-infrastructure/roles-anywhere-infrastructure.yml \
  --stack-name devcontainer-claude-code-playground \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CACertificateBody="$(cat aws-infrastructure/certificates/ca-cert.pem)"
```

### Verify AWS Access
```bash
aws sts get-caller-identity
```

## Architecture

### Devcontainer Setup
- **Base image**: Ubuntu Jammy with Node.js LTS, AWS CLI, Go, and Claude Code pre-installed
- **Credential handling**: `.devcontainer/setup-aws-credentials.sh` runs on container start and auto-detects the environment:
  - **Codespaces**: Uses IAM Roles Anywhere with certificates from GitHub secrets
  - **Local with host credentials**: Copies from mounted `~/.aws-host` directory
  - **Local with Roles Anywhere**: Uses `ROLES_ANYWHERE_*` environment variables

### AWS IAM Roles Anywhere Flow
```
Devcontainer → X.509 Certificate → IAM Roles Anywhere Trust Anchor → Temporary Credentials → AWS Services
```

The `aws_signing_helper` binary handles credential refresh automatically via the AWS config's `credential_process` directive.

### Key Files
- `aws-infrastructure/roles-anywhere-infrastructure.yml` - CloudFormation template defining Trust Anchor, IAM Role, and Profile
- `.devcontainer/setup-aws-credentials.sh` - Credential setup script that configures AWS access based on environment
- `.devcontainer/Dockerfile` - Container image with aws_signing_helper pre-installed

### Required Codespaces Secrets
When using GitHub Codespaces, these secrets must be configured:
- `ROLES_ANYWHERE_CERTIFICATE` - Base64-encoded client certificate
- `ROLES_ANYWHERE_PRIVATE_KEY` - Base64-encoded private key
- `ROLES_ANYWHERE_TRUST_ANCHOR_ARN`
- `ROLES_ANYWHERE_PROFILE_ARN`
- `ROLES_ANYWHERE_ROLE_ARN`
