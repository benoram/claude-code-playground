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
        gnupg \
        software-properties-common \
        telnet \
        iputils-ping \
        whois \
        dnsutils \
        netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform from HashiCorp repository
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS and Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg \
        > /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list \
        > /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
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

# Set default AWS_REGION (prevents empty host env var from overriding config file)
RUN echo 'export AWS_REGION="${AWS_REGION:-us-west-2}"' >> /home/vscode/.bashrc \
    && echo 'export AWS_REGION="${AWS_REGION:-us-west-2}"' >> /home/vscode/.zshrc

# Configure SSH to use SOCKS5 proxy for Tailscale CGNAT IPs (100.64.0.0/10)
# This is needed because tailscaled runs in userspace networking mode without kernel routes
RUN mkdir -p /etc/ssh/ssh_config.d \
    && { \
        echo "# Route Tailscale CGNAT range (100.64.0.0/10) through SOCKS5 proxy"; \
        echo "# Required for userspace networking mode (no /dev/net/tun)"; \
        printf "Host"; \
        for i in $(seq 64 127); do printf " 100.%d.*" "$i"; done; \
        echo ""; \
        echo "    ProxyCommand nc -X 5 -x localhost:1080 %h %p"; \
    } > /etc/ssh/ssh_config.d/tailscale-cgnat.conf
