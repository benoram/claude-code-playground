#!/bin/bash
# Certificate Generation Script for IAM Roles Anywhere
# This script generates a CA and end-entity certificate for use with devcontainers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certificates"
VALIDITY_DAYS="${VALIDITY_DAYS:-365}"
COMMON_NAME="${COMMON_NAME:-devcontainer-claude-code-playground}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== IAM Roles Anywhere Certificate Generator ===${NC}"
echo ""

# Create certificates directory
mkdir -p "${CERTS_DIR}"
cd "${CERTS_DIR}"

# Check if certificates already exist
if [ -f "ca-cert.pem" ] || [ -f "end-entity-cert.pem" ]; then
    echo -e "${YELLOW}WARNING: Certificates already exist in ${CERTS_DIR}${NC}"
    read -p "Do you want to regenerate them? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

echo -e "${GREEN}Step 1: Generating CA private key and certificate...${NC}"
openssl req -x509 \
    -newkey rsa:4096 \
    -keyout ca-key.pem \
    -out ca-cert.pem \
    -days "${VALIDITY_DAYS}" \
    -nodes \
    -subj "/CN=${COMMON_NAME}-ca/O=Claude Code Playground/OU=Development"

echo -e "${GREEN}Step 2: Generating end-entity private key...${NC}"
openssl genrsa -out end-entity-key.pem 4096

echo -e "${GREEN}Step 3: Creating certificate signing request (CSR)...${NC}"
openssl req -new \
    -key end-entity-key.pem \
    -out end-entity-csr.pem \
    -subj "/CN=${COMMON_NAME}/O=Claude Code Playground/OU=Devcontainer"

echo -e "${GREEN}Step 4: Creating OpenSSL config for end-entity certificate...${NC}"
cat > end-entity-ext.cnf << EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo -e "${GREEN}Step 5: Signing end-entity certificate with CA...${NC}"
openssl x509 -req \
    -in end-entity-csr.pem \
    -CA ca-cert.pem \
    -CAkey ca-key.pem \
    -CAcreateserial \
    -out end-entity-cert.pem \
    -days "${VALIDITY_DAYS}" \
    -extfile end-entity-ext.cnf

echo -e "${GREEN}Step 6: Verifying certificate chain...${NC}"
openssl verify -CAfile ca-cert.pem end-entity-cert.pem

echo -e "${GREEN}Step 7: Creating base64-encoded versions for Codespaces secrets...${NC}"
base64 -w 0 end-entity-cert.pem > end-entity-cert.pem.b64
base64 -w 0 end-entity-key.pem > end-entity-key.pem.b64

# Set secure permissions
chmod 600 ca-key.pem end-entity-key.pem end-entity-key.pem.b64
chmod 644 ca-cert.pem end-entity-cert.pem end-entity-cert.pem.b64

echo ""
echo -e "${GREEN}=== Certificate Generation Complete ===${NC}"
echo ""
echo "Generated files in ${CERTS_DIR}:"
echo "  CA Certificate:           ca-cert.pem"
echo "  CA Private Key:           ca-key.pem (KEEP SECURE!)"
echo "  End-Entity Certificate:   end-entity-cert.pem"
echo "  End-Entity Private Key:   end-entity-key.pem (KEEP SECURE!)"
echo "  Base64 Certificate:       end-entity-cert.pem.b64"
echo "  Base64 Private Key:       end-entity-key.pem.b64"
echo ""
echo -e "${YELLOW}=== Next Steps ===${NC}"
echo ""
echo "1. Deploy the CloudFormation stack with the CA certificate:"
echo ""
cat <<EOF
   aws cloudformation deploy \
     --template-file ${SCRIPT_DIR}/roles-anywhere-infrastructure.yml \
     --stack-name devcontainer-claude-code-playground \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides \
       CACertificateBody="\$(cat ${CERTS_DIR}/ca-cert.pem)"
EOF
echo ""
echo "2. Get the output values:"
echo ""
cat <<EOF
   aws cloudformation describe-stacks \
     --stack-name devcontainer-claude-code-playground \
     --query 'Stacks[0].Outputs'
EOF
echo ""
echo "3. Add these as GitHub Codespaces secrets:"
echo ""
echo "   ROLES_ANYWHERE_CERTIFICATE     = contents of end-entity-cert.pem.b64"
echo "   ROLES_ANYWHERE_PRIVATE_KEY     = contents of end-entity-key.pem.b64"
echo "   ROLES_ANYWHERE_TRUST_ANCHOR_ARN = TrustAnchorArn from stack outputs"
echo "   ROLES_ANYWHERE_PROFILE_ARN      = ProfileArn from stack outputs"
echo "   ROLES_ANYWHERE_ROLE_ARN         = RoleArn from stack outputs"
echo ""
echo -e "${RED}IMPORTANT: Keep ca-key.pem and end-entity-key.pem secure!${NC}"
echo "Do not commit private keys to version control."
