# Bootstrap Setup Guide

This guide covers the manual steps required to set up the environment for GitHub Codespaces and locally run devcontainers.

## Prerequisites

- AWS CLI installed with administrator access
- OpenSSL for certificate generation
- GitHub repository access (for Codespaces secrets)

## Initial Bootstrap Deployment

The first deployment of the bootstrap stack must be done manually with admin credentials.

### Step 1: Generate Certificates

```bash
cd aws-infrastructure
./generate-certificates.sh
```

This creates the following files in `aws-infrastructure/certificates/`:

| File | Description |
|------|-------------|
| `ca-cert.pem` | CA certificate (registered with AWS) |
| `ca-key.pem` | CA private key (keep secure!) |
| `client-cert.pem` | Client certificate for authentication |
| `client-key.pem` | Client private key |
| `*-base64.txt` | Base64-encoded versions for secrets |

### Step 2: Deploy Bootstrap Stack

```bash
cd /workspaces/claude-code-playground

# Deploy with admin credentials
./scripts/deploy-bootstrap.sh --first-run --region us-east-1
```

Or manually:

```bash
aws cloudformation deploy \
  --template-file aws-infrastructure/bootstrap.template \
  --stack-name claude-code-bootstrap \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CACertificateBody="$(cat aws-infrastructure/certificates/ca-cert.pem)"
```

### Step 3: Retrieve Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name claude-code-bootstrap \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

Note these values:
- `RolesAnywhereTrustAnchorArn`
- `RolesAnywhereProfileArn`
- `DevcontainerRoleArn`

---

## GitHub Codespaces Setup

### Configure Repository Secrets

Navigate to: **Repository Settings > Secrets and variables > Codespaces**

Add the following secrets:

| Secret Name | Value Source |
|-------------|--------------|
| `ROLES_ANYWHERE_CERTIFICATE` | `cat aws-infrastructure/certificates/client-cert-base64.txt` |
| `ROLES_ANYWHERE_PRIVATE_KEY` | `cat aws-infrastructure/certificates/client-key-base64.txt` |
| `ROLES_ANYWHERE_TRUST_ANCHOR_ARN` | Stack output: `RolesAnywhereTrustAnchorArn` |
| `ROLES_ANYWHERE_PROFILE_ARN` | Stack output: `RolesAnywhereProfileArn` |
| `ROLES_ANYWHERE_ROLE_ARN` | Stack output: `DevcontainerRoleArn` |

### Launch Codespace

1. Go to the repository on GitHub
2. Click **Code > Codespaces > Create codespace on main**
3. Wait for container to build and start
4. Verify AWS access:
   ```bash
   aws sts get-caller-identity
   ```

---

## Local Devcontainer Setup

### Option A: Use Host AWS Credentials (Recommended)

The devcontainer mounts your host's `~/.aws` directory automatically.

1. Authenticate on your host machine:
   ```bash
   aws sso login --profile your-profile
   # or
   aws configure
   ```

2. Open the repository in VS Code
3. Click **Reopen in Container** when prompted
4. Credentials are automatically available

To use a specific profile:
```bash
export AWS_PROFILE_LOCAL=your-profile
# Then open in devcontainer
```

### Option B: Use IAM Roles Anywhere

Set environment variables before starting the devcontainer:

```bash
# Export these before opening VS Code
export ROLES_ANYWHERE_CERTIFICATE=$(cat aws-infrastructure/certificates/client-cert-base64.txt)
export ROLES_ANYWHERE_PRIVATE_KEY=$(cat aws-infrastructure/certificates/client-key-base64.txt)
export ROLES_ANYWHERE_TRUST_ANCHOR_ARN="arn:aws:rolesanywhere:REGION:ACCOUNT:trust-anchor/ID"
export ROLES_ANYWHERE_PROFILE_ARN="arn:aws:rolesanywhere:REGION:ACCOUNT:profile/ID"
export ROLES_ANYWHERE_ROLE_ARN="arn:aws:iam::ACCOUNT:role/claude-code-playground-devcontainer-role"

# Then open in devcontainer
code .
```

### Option C: Configure Signing Helper on Host

Install the AWS Signing Helper:

```bash
# Linux x86_64
curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/X86_64/Linux/Amzn2023/aws_signing_helper"
chmod +x /usr/local/bin/aws_signing_helper

# macOS (Intel)
curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/X86_64/Darwin/aws_signing_helper"
chmod +x /usr/local/bin/aws_signing_helper
```

Configure `~/.aws/config`:

```ini
[profile claude-playground]
region = us-east-1
credential_process = aws_signing_helper credential-process \
  --certificate /path/to/aws-infrastructure/certificates/client-cert.pem \
  --private-key /path/to/aws-infrastructure/certificates/client-key.pem \
  --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT:trust-anchor/ID \
  --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT:profile/ID \
  --role-arn arn:aws:iam::ACCOUNT:role/claude-code-playground-devcontainer-role
```

Then:
```bash
export AWS_PROFILE=claude-playground
aws sts get-caller-identity
```

---

## Initialize Terraform

After the devcontainer is running with AWS access:

```bash
./scripts/init-terraform.sh
```

This:
1. Fetches configuration from SSM Parameter Store
2. Generates Terraform backend configuration
3. Creates provider and variable files
4. Initializes the S3 backend

Verify:
```bash
cd terraform
terraform plan
```

---

## Updating Bootstrap Infrastructure

After initial setup, the devcontainer role has permissions to update the bootstrap stack:

```bash
./scripts/deploy-bootstrap.sh
```

---

## Certificate Renewal

Certificates expire after 365 days by default.

### Check Expiry
```bash
openssl x509 -in aws-infrastructure/certificates/client-cert.pem -noout -dates
```

### Renew Certificates
```bash
# Generate new certificates
cd aws-infrastructure
./generate-certificates.sh

# Update trust anchor (if CA changed)
cd ..
./scripts/deploy-bootstrap.sh

# Update Codespaces secrets with new values
```

---

## Troubleshooting

### Credential Errors in Codespaces

1. Verify all secrets are set correctly
2. Check secret values don't have extra whitespace
3. Rebuild the codespace: **Command Palette > Codespaces: Rebuild Container**

### Credential Errors Locally

1. Check environment variables are exported
2. Verify certificate files exist and are readable
3. Ensure `~/.aws` directory exists on host

### Permission Errors

1. Verify the IAM role has required permissions
2. Check you're operating in the correct AWS region
3. Verify resource name prefixes match project name

### View Credential Setup Logs

```bash
# In devcontainer
cat /tmp/aws-credentials-setup.log 2>/dev/null || echo "Log not available"

# Check aws_signing_helper output
/usr/local/bin/aws_signing_helper credential-process \
  --certificate ~/.aws/client-cert.pem \
  --private-key ~/.aws/client-key.pem \
  --trust-anchor-arn "$ROLES_ANYWHERE_TRUST_ANCHOR_ARN" \
  --profile-arn "$ROLES_ANYWHERE_PROFILE_ARN" \
  --role-arn "$ROLES_ANYWHERE_ROLE_ARN"
```
