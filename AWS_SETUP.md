# AWS IAM Roles Anywhere Setup for Devcontainers

This guide explains how to configure secure AWS access for this repository's devcontainer, supporting both GitHub Codespaces and local development.

## Overview

This setup uses [AWS IAM Roles Anywhere](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html) to provide temporary AWS credentials using X.509 certificates instead of long-lived access keys.

```
┌─────────────────────────┐     X.509 Certificate     ┌──────────────────────┐
│  Devcontainer           │ ────────────────────────► │  IAM Roles Anywhere  │
│  (Codespaces or Local)  │                           │                      │
│                         │ ◄──────────────────────── │  Trust Anchor        │
│                         │   Temporary Credentials   │  Profile             │
└─────────────────────────┘                           └──────────────────────┘
            │                                                    │
            │  Use temp credentials                              │
            ▼                                                    ▼
┌─────────────────────────┐                           ┌──────────────────────┐
│     AWS Services        │                           │  IAM Role:           │
│     (S3, EC2, etc.)     │                           │  devcontainer-       │
│                         │                           │  claude-code-        │
│                         │                           │  playground          │
└─────────────────────────┘                           └──────────────────────┘
```

## Prerequisites

- AWS CLI installed and configured with admin access
- OpenSSL (for certificate generation)
- Access to GitHub repository settings (for Codespaces secrets)

## Quick Start

### 1. Generate Certificates

```bash
cd aws-infrastructure
./generate-certificates.sh
```

This creates:
- `certificates/ca-cert.pem` - CA certificate (used to create Trust Anchor)
- `certificates/ca-key.pem` - CA private key (keep secure!)
- `certificates/end-entity-cert.pem` - Client certificate
- `certificates/end-entity-key.pem` - Client private key
- `certificates/*.b64` - Base64-encoded versions for secrets

### 2. Deploy AWS Infrastructure

```bash
# Deploy the CloudFormation stack
aws cloudformation deploy \
  --template-file aws-infrastructure/roles-anywhere-infrastructure.yml \
  --stack-name devcontainer-claude-code-playground \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CACertificateBody="$(cat aws-infrastructure/certificates/ca-cert.pem)" \
    RepositoryOwner="benoram" \
    RepositoryName="claude-code-playground"
```

### 3. Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name devcontainer-claude-code-playground \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

Note the following values:
- `TrustAnchorArn`
- `ProfileArn`
- `RoleArn`

### 4. Configure GitHub Codespaces Secrets

Go to **Repository Settings > Secrets and variables > Codespaces** and add:

| Secret Name | Value |
|------------|-------|
| `ROLES_ANYWHERE_CERTIFICATE` | Contents of `end-entity-cert.pem.b64` |
| `ROLES_ANYWHERE_PRIVATE_KEY` | Contents of `end-entity-key.pem.b64` |
| `ROLES_ANYWHERE_TRUST_ANCHOR_ARN` | TrustAnchorArn from stack outputs |
| `ROLES_ANYWHERE_PROFILE_ARN` | ProfileArn from stack outputs |
| `ROLES_ANYWHERE_ROLE_ARN` | RoleArn from stack outputs |

### 5. Launch Codespace

Create a new Codespace for this repository. AWS credentials will be automatically configured on startup.

Verify with:
```bash
aws sts get-caller-identity
```

---

## Local Development

### Option A: Use Host AWS Credentials (Recommended for Local)

The devcontainer automatically mounts your host's `~/.aws` directory. If you're authenticated on your host machine, credentials are shared with the container.

```bash
# On your host machine
aws sso login --profile your-profile

# Then open the devcontainer - credentials are automatically available
```

### Option B: Use IAM Roles Anywhere Locally

Set environment variables before starting the devcontainer:

```bash
export ROLES_ANYWHERE_CERTIFICATE=$(cat aws-infrastructure/certificates/end-entity-cert.pem.b64)
export ROLES_ANYWHERE_PRIVATE_KEY=$(cat aws-infrastructure/certificates/end-entity-key.pem.b64)
export ROLES_ANYWHERE_TRUST_ANCHOR_ARN="arn:aws:rolesanywhere:..."
export ROLES_ANYWHERE_PROFILE_ARN="arn:aws:rolesanywhere:..."
export ROLES_ANYWHERE_ROLE_ARN="arn:aws:iam::..."
```

### Option C: Use Same Credentials as Devcontainer on Host

To use the IAM Roles Anywhere credentials directly on your host machine (same as devcontainer):

1. Install the AWS Signing Helper:
   ```bash
   # Download from AWS
   curl -L -o aws_signing_helper.zip \
     "https://rolesanywhere.amazonaws.com/releases/1.4.0/X86_64/Linux/aws_signing_helper.zip"
   unzip aws_signing_helper.zip
   sudo mv aws_signing_helper /usr/local/bin/
   chmod +x /usr/local/bin/aws_signing_helper
   ```

2. Configure `~/.aws/config`:
   ```ini
   [profile devcontainer]
   region = us-east-1
   credential_process = aws_signing_helper credential-process \
     --certificate /path/to/aws-infrastructure/certificates/end-entity-cert.pem \
     --private-key /path/to/aws-infrastructure/certificates/end-entity-key.pem \
     --trust-anchor-arn arn:aws:rolesanywhere:REGION:ACCOUNT:trust-anchor/ID \
     --profile-arn arn:aws:rolesanywhere:REGION:ACCOUNT:profile/ID \
     --role-arn arn:aws:iam::ACCOUNT:role/devcontainer-claude-code-playground
   ```

3. Use the profile:
   ```bash
   export AWS_PROFILE=devcontainer
   aws sts get-caller-identity
   ```

---

## AWS Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| Trust Anchor | `devcontainer-claude-code-playground-trust-anchor` | Registers your CA with AWS |
| IAM Role | `devcontainer-claude-code-playground` | Role assumed via Roles Anywhere |
| Profile | `devcontainer-claude-code-playground-profile` | Maps certificates to the role |

All resources are tagged with:
- `Repository`: benoram/claude-code-playground
- `Owner`: benoram
- `Project`: claude-code-playground
- `ManagedBy`: CloudFormation

---

## Customizing Permissions

The default IAM role has `ReadOnlyAccess`. To customize:

1. Edit `aws-infrastructure/roles-anywhere-infrastructure.yml`
2. Modify the `ManagedPolicyArns` or add inline policies to `DevcontainerRole`
3. Redeploy the stack:
   ```bash
   aws cloudformation deploy \
     --template-file aws-infrastructure/roles-anywhere-infrastructure.yml \
     --stack-name devcontainer-claude-code-playground \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides \
       CACertificateBody="$(cat aws-infrastructure/certificates/ca-cert.pem)"
   ```

---

## Certificate Renewal

Certificates expire after the configured validity period (default: 365 days).

To renew:

1. Generate new certificates:
   ```bash
   cd aws-infrastructure
   VALIDITY_DAYS=365 ./generate-certificates.sh
   ```

2. Update the Trust Anchor (if CA changed):
   ```bash
   aws cloudformation deploy \
     --template-file aws-infrastructure/roles-anywhere-infrastructure.yml \
     --stack-name devcontainer-claude-code-playground \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides \
       CACertificateBody="$(cat certificates/ca-cert.pem)"
   ```

3. Update Codespaces secrets with new certificate values

---

## Troubleshooting

### "Could not verify AWS credentials"

1. Check that all Codespaces secrets are set correctly
2. Verify the Trust Anchor is enabled:
   ```bash
   aws rolesanywhere list-trust-anchors
   ```
3. Check CloudWatch Logs for IAM Roles Anywhere errors

### "Access Denied" errors

1. Verify the IAM role has the required permissions
2. Check the Profile's session policy isn't too restrictive
3. Ensure the certificate CN matches any conditions in the trust policy

### Local credentials not working

1. Ensure `~/.aws` exists on your host machine
2. Run `aws sts get-caller-identity` on your host first
3. If using SSO, run `aws sso login` on your host

### Certificate verification failed

1. Ensure the end-entity cert was signed by the CA registered as Trust Anchor
2. Verify certificate hasn't expired:
   ```bash
   openssl x509 -in certificates/end-entity-cert.pem -noout -dates
   ```

---

## Security Best Practices

1. **Never commit private keys** - The `.gitignore` excludes the certificates directory
2. **Use short-lived certificates** - Regenerate certificates regularly
3. **Minimal permissions** - Only grant the IAM role the permissions it needs
4. **Rotate on compromise** - If keys are exposed, regenerate and redeploy immediately
5. **Use separate CAs** - Consider separate CAs for development vs production

---

## Cleanup

To remove all AWS resources:

```bash
aws cloudformation delete-stack --stack-name devcontainer-claude-code-playground
```

To remove Codespaces secrets, go to **Repository Settings > Secrets and variables > Codespaces** and delete each secret.
