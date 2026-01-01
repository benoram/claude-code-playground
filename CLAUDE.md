# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a devcontainer-based development environment for Claude Code with:
- Secure AWS access via IAM Roles Anywhere
- Terraform for infrastructure-as-code with S3 state backend
- Support for both GitHub Codespaces and local development

## Quick Reference Commands

### Bootstrap Infrastructure (First Time Setup)
```bash
# Generate certificates
cd aws-infrastructure && ./generate-certificates.sh && cd ..

# Deploy bootstrap stack (requires admin credentials)
./scripts/deploy-bootstrap.sh --first-run --region us-east-1
```

### Initialize Terraform
```bash
./scripts/init-terraform.sh
```

### Update Bootstrap Infrastructure
```bash
./scripts/deploy-bootstrap.sh
```

### Verify AWS Access
```bash
aws sts get-caller-identity
```

### Terraform Operations
```bash
cd terraform
terraform plan
terraform apply
```

## Architecture

### Bootstrap Infrastructure (`aws-infrastructure/bootstrap.template`)

The bootstrap CloudFormation template creates:
- **S3 Bucket**: Terraform state with native S3 locking (Terraform 1.6+)
- **KMS Key**: Encryption for state files
- **IAM Roles Anywhere**: Trust Anchor, Profile, and IAM Role
- **SSM Parameter Store**: Configuration values for scripts

### Devcontainer Setup
- **Base image**: Ubuntu Jammy with Node.js LTS, AWS CLI, Go, Terraform, and Claude Code
- **Credential handling**: `.devcontainer/setup-aws-credentials.sh` auto-detects environment:
  - **Codespaces**: Uses IAM Roles Anywhere with certificates from GitHub secrets
  - **Local with host credentials**: Copies from mounted `~/.aws-host` directory
  - **Local with Roles Anywhere**: Uses `ROLES_ANYWHERE_*` environment variables

### AWS IAM Roles Anywhere Flow
```
Devcontainer → X.509 Certificate → IAM Roles Anywhere → Temporary Credentials → AWS Services
```

The `aws_signing_helper` binary handles credential refresh automatically.

## Key Files

| File | Purpose |
|------|---------|
| `aws-infrastructure/bootstrap.template` | CloudFormation: S3, KMS, Roles Anywhere, SSM |
| `aws-infrastructure/generate-certificates.sh` | Generate X.509 certificates |
| `scripts/deploy-bootstrap.sh` | Deploy/update bootstrap stack |
| `scripts/init-terraform.sh` | Initialize Terraform with S3 backend |
| `.devcontainer/setup-aws-credentials.sh` | Configure AWS credentials on container start |
| `.devcontainer/Dockerfile` | Container with Terraform, AWS CLI, Claude Code |
| `terraform/` | Terraform configuration directory (created by init script) |

## SSM Parameter Store Configuration

Configuration is stored under `/{project-name}/`:
- `/claude-code-playground/terraform/state-bucket` - S3 bucket name
- `/claude-code-playground/terraform/state-region` - AWS region
- `/claude-code-playground/terraform/state-kms-key-arn` - KMS key ARN
- `/claude-code-playground/roles-anywhere/*` - Roles Anywhere ARNs
- `/claude-code-playground/config/*` - Project configuration

## Required Codespaces Secrets

When using GitHub Codespaces, configure these secrets:
- `ROLES_ANYWHERE_CERTIFICATE` - Base64-encoded client certificate
- `ROLES_ANYWHERE_PRIVATE_KEY` - Base64-encoded private key
- `ROLES_ANYWHERE_TRUST_ANCHOR_ARN`
- `ROLES_ANYWHERE_PROFILE_ARN`
- `ROLES_ANYWHERE_ROLE_ARN`

## IAM Role Permissions

The devcontainer role has permissions for:
- S3 (state bucket + project buckets)
- SSM Parameter Store (project prefix)
- CloudFormation (project stacks)
- IAM (scoped role management)
- KMS (state encryption)
- Roles Anywhere (self-management)

See `aws-infrastructure/bootstrap.template` for full policy definitions.
