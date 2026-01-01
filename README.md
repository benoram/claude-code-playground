# Claude Code Playground

A devcontainer-based development environment with secure AWS access and Terraform infrastructure-as-code.

## Features

- **Secure AWS Access**: IAM Roles Anywhere with X.509 certificates
- **Terraform Ready**: S3 state backend with native locking
- **Multi-Environment**: Works in GitHub Codespaces and local development

## Quick Start

> **Note:** All shell scripts in this repository are committed with executable permissions. If you encounter permission errors, run:
> ```bash
> chmod +x scripts/deploy-bootstrap.sh scripts/init-terraform.sh aws-infrastructure/generate-certificates.sh
> ```

### 1. Generate Certificates
```bash
cd aws-infrastructure && ./generate-certificates.sh
```

### 2. Deploy Bootstrap Infrastructure
```bash
./scripts/deploy-bootstrap.sh --first-run --region us-west-2
```

### 3. Configure Codespaces Secrets
Add the output values to your repository's Codespaces secrets.

### 4. Initialize Terraform
```bash
./scripts/init-terraform.sh
```

### 5. Verify
```bash
aws sts get-caller-identity
terraform version
```

## Documentation

- [Bootstrap Guide](docs/bootstrap.md) - Manual setup steps for Codespaces and local devcontainers
- [AWS Setup Guide](docs/aws-setup.md) - Detailed AWS and Terraform configuration
- [CLAUDE.md](CLAUDE.md) - Claude Code guidance and reference

## Directory Structure

```
.
├── aws-infrastructure/     # CloudFormation templates and certificates
├── docs/                   # Documentation
├── scripts/                # Deployment and setup scripts
├── terraform/              # Terraform configuration (created by init)
└── .devcontainer/          # Development container configuration
```

## License

MIT
