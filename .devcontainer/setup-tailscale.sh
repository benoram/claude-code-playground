#!/bin/bash
# Tailscale Setup Script for Devcontainer
# Connects the devcontainer to a Tailscale network using auth key from SSM Parameter Store
#
# Prerequisites:
#   - AWS credentials must be configured (run setup-aws-credentials.sh first)
#   - Tailscale auth key stored in SSM at /{project-name}/config/tailscale-auth-key
#
# Usage: This script is called automatically by postStartCommand in devcontainer.json

set -e

echo "Setting up Tailscale..."

# Configuration
PROJECT_NAME="${PROJECT_NAME:-claude-code-playground}"
AWS_REGION="${AWS_REGION:-us-west-2}"
SSM_PARAMETER_NAME="/${PROJECT_NAME}/config/tailscale-auth-key"
PLACEHOLDER_VALUE="PLACEHOLDER_UPDATE_AFTER_DEPLOYMENT"

# Check if AWS credentials are available
if ! aws sts get-caller-identity &> /dev/null; then
    echo "[WARNING] AWS credentials not available. Skipping Tailscale setup."
    echo "[WARNING] Run setup-aws-credentials.sh first, then re-run this script."
    exit 0
fi

# Fetch Tailscale auth key from SSM Parameter Store
echo "[INFO] Fetching Tailscale auth key from SSM Parameter Store..."

TAILSCALE_AUTH_KEY=$(aws ssm get-parameter \
    --name "${SSM_PARAMETER_NAME}" \
    --region "${AWS_REGION}" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text 2>/dev/null) || {
    echo "[WARNING] Could not fetch Tailscale auth key from SSM."
    echo "[WARNING] Parameter: ${SSM_PARAMETER_NAME}"
    echo "[WARNING] Tailscale will not be configured."
    exit 0
}

# Check if the value is still the placeholder
if [[ "${TAILSCALE_AUTH_KEY}" == "${PLACEHOLDER_VALUE}" ]]; then
    echo "[WARNING] Tailscale auth key has not been configured."
    echo "[WARNING] To enable Tailscale, update the SSM parameter:"
    echo "[WARNING]   aws ssm put-parameter \\"
    echo "[WARNING]     --name '${SSM_PARAMETER_NAME}' \\"
    echo "[WARNING]     --value 'tskey-auth-xxxxx' \\"
    echo "[WARNING]     --overwrite \\"
    echo "[WARNING]     --region ${AWS_REGION}"
    echo ""
    echo "[WARNING] Skipping Tailscale setup."
    exit 0
fi

# Basic validation of auth key format
if [[ ! "${TAILSCALE_AUTH_KEY}" =~ ^tskey- ]]; then
    echo "[WARNING] Tailscale auth key does not appear to be valid (should start with 'tskey-')."
    echo "[WARNING] Skipping Tailscale setup."
    exit 0
fi

echo "[SUCCESS] Auth key retrieved from SSM Parameter Store"

# Start tailscaled daemon
echo "[INFO] Starting tailscaled daemon..."

# Check if tailscaled is already running
if pgrep -x tailscaled > /dev/null; then
    echo "[INFO] tailscaled is already running"
else
    # Start tailscaled in userspace networking mode (works in containers without TUN device)
    # Using --state=mem: to avoid needing persistent state file
    # Using --tun=userspace-networking to work without /dev/net/tun
    sudo tailscaled --state=mem: --tun=userspace-networking --socket=/var/run/tailscale/tailscaled.sock > /tmp/tailscaled.log 2>&1 &

    # Wait for daemon to start (tailscale status returns 1 when logged out, but that's OK)
    max_attempts=30
    attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        # Check if daemon is responding (status command works even when logged out)
        if tailscale status 2>&1 | grep -qE "(Logged out|stopped|Health check)"; then
            echo "[SUCCESS] tailscaled daemon started"
            break
        fi
        # Also check if already connected
        if tailscale status &> /dev/null; then
            echo "[SUCCESS] tailscaled daemon started (already connected)"
            break
        fi
        sleep 0.5
        ((attempt++))
    done

    if [[ $attempt -ge $max_attempts ]]; then
        echo "[ERROR] tailscaled daemon failed to start within timeout"
        cat /tmp/tailscaled.log 2>/dev/null | tail -10
        exit 1
    fi
fi

# Connect to Tailscale network
echo "[INFO] Connecting to Tailscale network..."

# Check if already connected
if tailscale status 2>/dev/null | grep -q "offers exit node"; then
    echo "[INFO] Already connected to Tailscale"
else
    # Connect using auth key (ephemeral behavior is set when generating the key)
    if sudo tailscale up --authkey="${TAILSCALE_AUTH_KEY}"; then
        echo "[SUCCESS] Connected to Tailscale network"
    else
        echo "[ERROR] Failed to connect to Tailscale network"
        echo "[WARNING] Check that your auth key is valid and has not expired"
        exit 1
    fi
fi

# Verify connection
echo ""
echo "[INFO] Verifying Tailscale connection..."
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [[ -n "${TAILSCALE_IP}" ]]; then
    echo "[SUCCESS] Tailscale connected successfully!"
    echo "[INFO] Tailscale IPv4: ${TAILSCALE_IP}"
    echo ""
    echo "[INFO] Tailscale status:"
    tailscale status
else
    echo "[ERROR] Could not verify Tailscale connection - no IP assigned"
    exit 1
fi

echo ""
echo "Tailscale setup complete."
