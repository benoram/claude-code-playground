#!/bin/bash
# AWS Credentials Setup Script for Devcontainer
# Supports both GitHub Codespaces (IAM Roles Anywhere) and local development

set -e

echo "Setting up AWS credentials..."

# Determine environment
if [ -n "${CODESPACES}" ]; then
    echo "Running in GitHub Codespaces"
    ENVIRONMENT="codespaces"
elif [ -d "/home/vscode/.aws-host" ]; then
    echo "Running in local devcontainer with host AWS credentials"
    ENVIRONMENT="local-host"
else
    echo "Running in local devcontainer without host credentials"
    ENVIRONMENT="local"
fi

# Function to setup IAM Roles Anywhere credentials
setup_roles_anywhere() {
    # Check for required Codespaces secrets
    if [ -z "${ROLES_ANYWHERE_CERTIFICATE}" ] || \
       [ -z "${ROLES_ANYWHERE_PRIVATE_KEY}" ] || \
       [ -z "${ROLES_ANYWHERE_TRUST_ANCHOR_ARN}" ] || \
       [ -z "${ROLES_ANYWHERE_PROFILE_ARN}" ] || \
       [ -z "${ROLES_ANYWHERE_ROLE_ARN}" ]; then
        echo "WARNING: IAM Roles Anywhere secrets not configured."
        echo "Required Codespaces secrets:"
        echo "  - ROLES_ANYWHERE_CERTIFICATE"
        echo "  - ROLES_ANYWHERE_PRIVATE_KEY"
        echo "  - ROLES_ANYWHERE_TRUST_ANCHOR_ARN"
        echo "  - ROLES_ANYWHERE_PROFILE_ARN"
        echo "  - ROLES_ANYWHERE_ROLE_ARN"
        echo ""
        echo "See AWS_SETUP.md for configuration instructions."
        return 1
    fi

    # Create certificate and key files
    mkdir -p /home/vscode/.aws/roles-anywhere

    echo "${ROLES_ANYWHERE_CERTIFICATE}" | base64 -d > /home/vscode/.aws/roles-anywhere/certificate.pem
    echo "${ROLES_ANYWHERE_PRIVATE_KEY}" | base64 -d > /home/vscode/.aws/roles-anywhere/private-key.pem
    chmod 600 /home/vscode/.aws/roles-anywhere/private-key.pem
    chmod 644 /home/vscode/.aws/roles-anywhere/certificate.pem

    # Determine region from ARN or use default
    AWS_REGION="${AWS_REGION:-us-east-1}"
    if [ -n "${ROLES_ANYWHERE_TRUST_ANCHOR_ARN}" ]; then
        EXTRACTED_REGION=$(echo "${ROLES_ANYWHERE_TRUST_ANCHOR_ARN}" | cut -d: -f4)
        if [ -n "${EXTRACTED_REGION}" ]; then
            AWS_REGION="${EXTRACTED_REGION}"
        fi
    fi

    # Create credential helper script
    cat > /home/vscode/.aws/roles-anywhere-credential-helper.sh << 'HELPER_EOF'
#!/bin/bash
aws_signing_helper credential-process \
    --certificate /home/vscode/.aws/roles-anywhere/certificate.pem \
    --private-key /home/vscode/.aws/roles-anywhere/private-key.pem \
    --trust-anchor-arn "${ROLES_ANYWHERE_TRUST_ANCHOR_ARN}" \
    --profile-arn "${ROLES_ANYWHERE_PROFILE_ARN}" \
    --role-arn "${ROLES_ANYWHERE_ROLE_ARN}"
HELPER_EOF
    chmod +x /home/vscode/.aws/roles-anywhere-credential-helper.sh

    # Create AWS config
    cat > /home/vscode/.aws/config << EOF
[default]
region = ${AWS_REGION}
credential_process = /home/vscode/.aws/roles-anywhere-credential-helper.sh

[profile roles-anywhere]
region = ${AWS_REGION}
credential_process = /home/vscode/.aws/roles-anywhere-credential-helper.sh
EOF

    echo "IAM Roles Anywhere credentials configured successfully!"
    echo "Testing AWS access..."
    # Disable exit-on-error for credential validation to avoid unexpected script termination
    set +e
    aws sts get-caller-identity 2>/dev/null
    exit_code=$?
    set -e
    if [ $exit_code -eq 0 ]; then
        echo "AWS credentials are working!"
    else
        echo "WARNING: Could not verify AWS credentials. Check your configuration."
    fi
}

# Function to use host AWS credentials (local development)
setup_host_credentials() {
    if [ -d "/home/vscode/.aws-host" ] && [ -f "/home/vscode/.aws-host/credentials" ]; then
        # Create symlinks to host credentials
        mkdir -p /home/vscode/.aws

        # Copy config and credentials (can't symlink due to read-only mount)
        if [ -f "/home/vscode/.aws-host/config" ]; then
            cp /home/vscode/.aws-host/config /home/vscode/.aws/config
        fi
        if [ -f "/home/vscode/.aws-host/credentials" ]; then
            cp /home/vscode/.aws-host/credentials /home/vscode/.aws/credentials
            chmod 600 /home/vscode/.aws/credentials
        fi

        # Use the local profile if specified
        if [ -n "${AWS_PROFILE_LOCAL}" ]; then
            export AWS_PROFILE="${AWS_PROFILE_LOCAL}"
            echo "export AWS_PROFILE=${AWS_PROFILE_LOCAL}" >> /home/vscode/.bashrc
        fi

        echo "Host AWS credentials configured!"
        echo "Testing AWS access..."
        # Disable exit-on-error for credential validation to avoid unexpected script termination
        set +e
        aws sts get-caller-identity 2>/dev/null
        exit_code=$?
        set -e
        if [ $exit_code -eq 0 ]; then
            echo "AWS credentials are working!"
        else
            echo "WARNING: Could not verify AWS credentials."
            echo "Make sure you're authenticated on your host machine (e.g., 'aws sso login')"
        fi
    else
        echo "No host AWS credentials found at ~/.aws"
        echo "To use AWS in local development, either:"
        echo "  1. Configure AWS CLI on your host machine"
        echo "  2. Set up IAM Roles Anywhere (see AWS_SETUP.md)"
    fi
}

# Main logic
case "${ENVIRONMENT}" in
    "codespaces")
        setup_roles_anywhere
        ;;
    "local-host")
        setup_host_credentials
        ;;
    "local")
        # Check if Roles Anywhere env vars are set (for local Roles Anywhere testing)
        if [ -n "${ROLES_ANYWHERE_CERTIFICATE}" ]; then
            setup_roles_anywhere
        else
            echo "No AWS credentials configured."
            echo "Options:"
            echo "  1. Mount host ~/.aws directory (automatic if it exists)"
            echo "  2. Set ROLES_ANYWHERE_* environment variables"
            echo "  3. See AWS_SETUP.md for full setup instructions"
        fi
        ;;
esac

echo ""
echo "AWS credential setup complete."
