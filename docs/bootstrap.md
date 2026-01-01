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
./scripts/deploy-bootstrap.sh --first-run --region us-west-2
```

Or manually:

```bash
aws cloudformation deploy \
  --template-file aws-infrastructure/bootstrap.template \
  --stack-name claude-code-bootstrap \
  --region us-west-2 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CACertificateBody="$(cat aws-infrastructure/certificates/ca-cert.pem)"
```

### Step 3: Retrieve Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name claude-code-bootstrap \
  --region us-west-2 \
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

### Option B: Use IAM Roles Anywhere with Environment Variables

This method passes the Roles Anywhere configuration to the devcontainer via environment variables.

#### Step 1: Get Stack Outputs

After deploying the bootstrap stack, retrieve the ARN values:

```bash
aws cloudformation describe-stacks \
  --stack-name claude-code-bootstrap \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

Note these values:
- `RolesAnywhereTrustAnchorArn`
- `RolesAnywhereProfileArn`
- `DevcontainerRoleArn`

#### Step 2: Create Local Environment File

Create a `.env.local` file in the repository root (this file is gitignored):

```bash
# .env.local - Local Roles Anywhere configuration
ROLES_ANYWHERE_CERTIFICATE=<base64-encoded-certificate>
ROLES_ANYWHERE_PRIVATE_KEY=<base64-encoded-private-key>
ROLES_ANYWHERE_TRUST_ANCHOR_ARN=arn:aws:rolesanywhere:us-west-2:ACCOUNT:trust-anchor/TRUST_ANCHOR_ID
ROLES_ANYWHERE_PROFILE_ARN=arn:aws:rolesanywhere:us-west-2:ACCOUNT:profile/PROFILE_ID
ROLES_ANYWHERE_ROLE_ARN=arn:aws:iam::ACCOUNT:role/claude-code-playground-devcontainer-role
```

To get the base64-encoded values:
```bash
cat aws-infrastructure/certificates/client-cert-base64.txt
cat aws-infrastructure/certificates/client-key-base64.txt
```

#### Step 3: Configure devcontainer to Use Environment File

Update `.devcontainer/devcontainer.json` to load the environment file:

```json
{
  "runArgs": ["--env-file", "${localWorkspaceFolder}/.env.local"]
}
```

Or export variables in your shell before opening VS Code:

```bash
# Source the environment file
set -a
source .env.local
set +a

# Open VS Code
code .
```

#### Step 4: Verify

After the devcontainer starts:
```bash
aws sts get-caller-identity
```

### Option C: Configure Signing Helper on Host

This method configures the AWS signing helper directly on your host machine, which then shares credentials with the devcontainer.

#### Step 1: Install AWS Signing Helper

```bash
# Linux x86_64
sudo curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/X86_64/Linux/Amzn2023/aws_signing_helper"
sudo chmod +x /usr/local/bin/aws_signing_helper

# Linux ARM64
sudo curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/Aarch64/Linux/Amzn2023/aws_signing_helper"
sudo chmod +x /usr/local/bin/aws_signing_helper

# macOS Intel
sudo curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/X86_64/Darwin/aws_signing_helper"
sudo chmod +x /usr/local/bin/aws_signing_helper

# macOS Apple Silicon
sudo curl -L -o /usr/local/bin/aws_signing_helper \
  "https://rolesanywhere.amazonaws.com/releases/1.7.2/Aarch64/Darwin/aws_signing_helper"
sudo chmod +x /usr/local/bin/aws_signing_helper
```

#### Step 2: Configure AWS Profile

Add to `~/.aws/config`:

```ini
[profile claude-playground]
region = us-west-2
credential_process = /usr/local/bin/aws_signing_helper credential-process \
  --certificate /full/path/to/aws-infrastructure/certificates/client-cert.pem \
  --private-key /full/path/to/aws-infrastructure/certificates/client-key.pem \
  --trust-anchor-arn arn:aws:rolesanywhere:us-west-2:ACCOUNT:trust-anchor/TRUST_ANCHOR_ID \
  --profile-arn arn:aws:rolesanywhere:us-west-2:ACCOUNT:profile/PROFILE_ID \
  --role-arn arn:aws:iam::ACCOUNT:role/claude-code-playground-devcontainer-role
```

**Important:** Use absolute paths for certificate files.

#### Step 3: Test on Host

```bash
export AWS_PROFILE=claude-playground
aws sts get-caller-identity
```

#### Step 4: Use in Devcontainer

The devcontainer mounts `~/.aws` from your host. Set the profile before opening:

```bash
export AWS_PROFILE_LOCAL=claude-playground
code .
```

Or add to `.devcontainer/devcontainer.json`:

```json
{
  "containerEnv": {
    "AWS_PROFILE": "claude-playground"
  }
}
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
