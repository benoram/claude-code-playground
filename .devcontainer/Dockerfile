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

# Install Node.js LTS and Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install AWS IAM Roles Anywhere credential helper
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "Aarch64" || echo "X86_64") \
    && curl -L -o /usr/local/bin/aws_signing_helper \
        "https://rolesanywhere.amazonaws.com/releases/1.7.2/${ARCH}/Linux/Amzn2023/aws_signing_helper" \
    && chmod +x /usr/local/bin/aws_signing_helper

# Create directories for credentials and Claude Code config
RUN mkdir -p /home/vscode/.aws /home/vscode/.claude \
    && chown -R vscode:vscode /home/vscode/.aws /home/vscode/.claude

# Add clauded alias for bash and zsh
RUN echo "alias clauded='claude --dangerously-skip-permissions'" >> /home/vscode/.bashrc \
    && echo "alias clauded='claude --dangerously-skip-permissions'" >> /home/vscode/.zshrc
