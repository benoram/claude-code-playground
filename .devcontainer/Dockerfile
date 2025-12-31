# Development container for Claude Code Playground
# Supports AWS IAM Roles Anywhere for secure credential management

ARG VARIANT="jammy"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# Install additional packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        jq \
        curl \
        unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install AWS IAM Roles Anywhere credential helper
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -L -o /tmp/aws_signing_helper.zip \
        "https://rolesanywhere.amazonaws.com/releases/1.4.0/X86_64/Linux/aws_signing_helper.zip" \
    && unzip /tmp/aws_signing_helper.zip -d /tmp \
    && mv /tmp/aws_signing_helper /usr/local/bin/ \
    && chmod +x /usr/local/bin/aws_signing_helper \
    && rm /tmp/aws_signing_helper.zip

# Create directories for credentials
RUN mkdir -p /home/vscode/.aws \
    && chown -R vscode:vscode /home/vscode/.aws
