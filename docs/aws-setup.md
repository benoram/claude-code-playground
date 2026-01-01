# AWS Infrastructure Setup Guide

This guide explains how to configure AWS access, Terraform state management, and the bootstrap infrastructure for this repository's devcontainer environment.

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           Bootstrap Infrastructure                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐  │
│  │  Devcontainer   │────►│  IAM Roles Anywhere  │────►│   IAM Role      │  │
│  │  (Codespaces/   │     │  - Trust Anchor      │     │  - CloudFormation│  │
│  │   Local)        │◄────│  - Profile           │◄────│  - S3 State     │  │
│  │                 │     │                      │     │  - SSM Params   │  │
│  └────────┬────────┘     └──────────────────────┘     └─────────────────┘  │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        AWS Services                                  │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │  S3 Bucket   │  │  SSM Param   │  │    KMS       │              │   │
│  │  │  (TF State)  │  │   Store      │  │   (Encrypt)  │              │   │
│  │  │  + Locking   │  │  (Config)    │  │              │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS CLI installed with admin access (for initial setup)
- OpenSSL (for certificate generation)
- Access to GitHub repository settings (for Codespaces secrets)

## Quick Start

### Step 1: Generate Certificates

```bash
cd aws-infrastructure
./generate-certificates.sh
```

This creates certificates in `aws-infrastructure/certificates/`:
- `ca-cert.pem` / `ca-key.pem` - CA certificate and key
- `client-cert.pem` / `client-key.pem` - Client certificate and key
- `*-base64.txt` - Base64-encoded versions for GitHub secrets

### Step 2: Deploy Bootstrap Infrastructure

For the **first deployment**, use admin credentials:

```bash
./scripts/deploy-bootstrap.sh --first-run --region us-west-2
```

This creates:
- S3 bucket for Terraform state with native locking
- KMS key for state encryption
- IAM Roles Anywhere (Trust Anchor, Profile, Role)
- SSM Parameter Store configuration values

### Step 3: Configure GitHub Codespaces Secrets

Go to **Repository Settings > Secrets and variables > Codespaces** and add:

| Secret Name | Value |
|-------------|-------|
| `ROLES_ANYWHERE_CERTIFICATE` | Contents of `client-cert-base64.txt` |
| `ROLES_ANYWHERE_PRIVATE_KEY` | Contents of `client-key-base64.txt` |
| `ROLES_ANYWHERE_TRUST_ANCHOR_ARN` | From stack outputs |
| `ROLES_ANYWHERE_PROFILE_ARN` | From stack outputs |
| `ROLES_ANYWHERE_ROLE_ARN` | From stack outputs |

### Step 4: Initialize Terraform

After the bootstrap is deployed:

```bash
./scripts/init-terraform.sh
```

This generates Terraform configuration in the `terraform/` directory with:
- S3 backend configuration (from SSM Parameter Store)
- AWS provider configuration
- Data sources for SSM parameters

### Step 5: Launch Codespace or Devcontainer

Create a new Codespace or rebuild your devcontainer. AWS credentials will be automatically configured.

Verify with:
```bash
aws sts get-caller-identity
terraform version
```

---

## Bootstrap Template Resources

The `aws-infrastructure/bootstrap.template` CloudFormation template creates:

### Terraform State Storage
| Resource | Description |
|----------|-------------|
| S3 Bucket | Versioned, encrypted bucket for `.tfstate` files |
| KMS Key | Customer-managed key for state encryption |
| Bucket Policy | Enforces TLS and server-side encryption |

### IAM Roles Anywhere
| Resource | Description |
|----------|-------------|
| Trust Anchor | Registers your CA certificate with AWS |
| IAM Role | Role with permissions for Terraform operations |
| Profile | Maps certificates to the IAM role |

### SSM Parameters
| Parameter | Description |
|-----------|-------------|
| `/{project}/terraform/state-bucket` | S3 bucket name |
| `/{project}/terraform/state-region` | AWS region |
| `/{project}/terraform/state-kms-key-arn` | KMS key ARN |
| `/{project}/roles-anywhere/*` | Roles Anywhere ARNs |
| `/{project}/config/*` | Project configuration |

---

## Scripts Reference

### `scripts/deploy-bootstrap.sh`

Deploy or update the bootstrap CloudFormation stack.

```bash
# First deployment (generates certs if needed)
./scripts/deploy-bootstrap.sh --first-run

# Update existing stack
./scripts/deploy-bootstrap.sh

# Options
./scripts/deploy-bootstrap.sh --help
  --first-run         First deployment
  --region REGION     AWS region (default: us-west-2)
  --project-name NAME Project name (default: claude-code-playground)
  --environment ENV   dev/staging/prod (default: dev)
```

### `scripts/init-terraform.sh`

Initialize Terraform with S3 backend from SSM configuration.

```bash
# Initialize with defaults
./scripts/init-terraform.sh

# Force reconfiguration
./scripts/init-terraform.sh --reconfigure

# Options
./scripts/init-terraform.sh --help
  --region REGION       AWS region
  --project-name NAME   Project name
  --terraform-dir DIR   Terraform directory
  --reconfigure         Force backend reconfiguration
```

---

## Local Development Options

### Option A: Use Host AWS Credentials (Recommended)

The devcontainer mounts your host's `~/.aws` directory. If authenticated on your host, credentials are shared.

```bash
# On your host machine
aws sso login --profile your-profile

# Open devcontainer - credentials available automatically
```

To use a specific profile, set `AWS_PROFILE_LOCAL` environment variable before starting the container.

### Option B: Use IAM Roles Anywhere Locally

Set environment variables before starting the devcontainer:

```bash
export ROLES_ANYWHERE_CERTIFICATE=$(cat aws-infrastructure/certificates/client-cert-base64.txt)
export ROLES_ANYWHERE_PRIVATE_KEY=$(cat aws-infrastructure/certificates/client-key-base64.txt)
export ROLES_ANYWHERE_TRUST_ANCHOR_ARN="arn:aws:rolesanywhere:..."
export ROLES_ANYWHERE_PROFILE_ARN="arn:aws:rolesanywhere:..."
export ROLES_ANYWHERE_ROLE_ARN="arn:aws:iam::..."
```

### Option C: Direct Signing Helper on Host

Install the AWS Signing Helper on your host machine:

```bash
# Download from AWS (adjust for your platform)
curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/X86_64/Linux/Amzn2023/aws_signing_helper"
chmod +x /usr/local/bin/aws_signing_helper
```

Configure `~/.aws/config`:
```ini
[profile devcontainer]
region = us-west-2
credential_process = aws_signing_helper credential-process \
  --certificate /path/to/client-cert.pem \
  --private-key /path/to/client-key.pem \
  --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT:trust-anchor/ID \
  --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT:profile/ID \
  --role-arn arn:aws:iam::ACCOUNT:role/claude-code-playground-devcontainer-role
```

---

## Terraform Usage

After initialization, Terraform is ready to use:

```bash
cd terraform

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List outputs
terraform output
```

### State Locking

Terraform state locking uses the native S3 locking feature (Terraform 1.6+), eliminating the need for a separate DynamoDB table. The lock file is stored in the same S3 bucket as the state.

### Adding New Resources

Create `.tf` files in the `terraform/` directory:

```hcl
# example.tf
resource "aws_s3_bucket" "example" {
  bucket = "${var.project_name}-example-bucket"
}
```

---

## IAM Role Permissions

The bootstrap role includes permissions for:

| Service | Actions | Purpose |
|---------|---------|---------|
| S3 | Full access to project buckets | Terraform state + resources |
| SSM | Parameter CRUD on project prefix | Configuration management |
| CloudFormation | Stack operations | Bootstrap updates |
| IAM | Role management (scoped) | Terraform IAM resources |
| KMS | Encrypt/decrypt | State encryption |
| Roles Anywhere | Read/manage own resources | Certificate rotation |
| STS | Get caller identity | Verification |

To customize permissions, edit `aws-infrastructure/bootstrap.template` and redeploy:

```bash
./scripts/deploy-bootstrap.sh
```

---

## Certificate Renewal

Certificates expire after the configured validity period (default: 365 days).

To renew:

1. Generate new certificates:
   ```bash
   cd aws-infrastructure
   ./generate-certificates.sh
   ```

2. Update the Trust Anchor (if CA changed):
   ```bash
   ./scripts/deploy-bootstrap.sh
   ```

3. Update Codespaces secrets with new certificate values

Check certificate expiry:
```bash
openssl x509 -in aws-infrastructure/certificates/client-cert.pem -noout -dates
```

---

## Troubleshooting

### "Could not verify AWS credentials"

1. Check all Codespaces secrets are set correctly
2. Verify the Trust Anchor is enabled:
   ```bash
   aws rolesanywhere list-trust-anchors
   ```
3. Check certificate validity:
   ```bash
   openssl x509 -in certificates/client-cert.pem -noout -dates
   ```

### "Access Denied" errors

1. Verify the IAM role has required permissions
2. Check resource name prefixes match the project name
3. Ensure you're operating in the correct AWS region

### Terraform state locked

If Terraform reports the state is locked:

```bash
# List current lock
aws s3api head-object --bucket BUCKET --key terraform.tfstate.tflock

# If stale, the lock should auto-expire
# Or force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Local credentials not working

1. Ensure `~/.aws` exists on your host machine
2. Run `aws sts get-caller-identity` on your host first
3. If using SSO, run `aws sso login` on your host

### "Permission denied" when executing scripts

All scripts are committed with executable permissions. If you encounter this error:

```bash
chmod +x scripts/*.sh aws-infrastructure/*.sh
```

This typically occurs if files were copied instead of cloned, or if git doesn't preserve executable permissions on your system.

---

## Security Best Practices

1. **Never commit private keys** - `.gitignore` excludes the certificates directory
2. **Use short-lived certificates** - Regenerate certificates regularly
3. **Minimal permissions** - Only grant the IAM role necessary permissions
4. **Rotate on compromise** - Regenerate and redeploy immediately if exposed
5. **Separate environments** - Use different CAs for dev vs production
6. **Enable CloudTrail** - Monitor IAM Roles Anywhere usage

---

## Cleanup

To remove all AWS resources:

```bash
# Delete Terraform-managed resources first
cd terraform
terraform destroy

# Then delete the bootstrap stack
aws cloudformation delete-stack --stack-name claude-code-bootstrap

# Note: S3 bucket has DeletionPolicy: Retain - delete manually if needed
aws s3 rb s3://claude-code-playground-terraform-state-ACCOUNT_ID --force
```

To remove Codespaces secrets, go to **Repository Settings > Secrets and variables > Codespaces** and delete each secret.
