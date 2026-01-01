#!/bin/bash
# Certificate Generation Script for IAM Roles Anywhere
# This script generates a CA and client certificate for use with devcontainers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certificates"
VALIDITY_DAYS="${VALIDITY_DAYS:-365}"
COMMON_NAME="${COMMON_NAME:-claude-code-playground}"
AWS_REGION="${AWS_REGION:-us-west-2}"

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
if [ -f "ca-cert.pem" ] || [ -f "client-cert.pem" ]; then
    echo -e "${YELLOW}WARNING: Certificates already exist in ${CERTS_DIR}${NC}"
    read -p "Do you want to regenerate them? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

echo -e "${GREEN}Step 1: Generating CA private key and certificate...${NC}"

# Create CA config file with proper extensions
cat > ca-ext.cnf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = ${COMMON_NAME}-ca
O = Claude Code Playground
OU = Development

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF

openssl req -x509 \
    -newkey rsa:4096 \
    -keyout ca-key.pem \
    -out ca-cert.pem \
    -days "${VALIDITY_DAYS}" \
    -nodes \
    -config ca-ext.cnf \
    -extensions v3_ca

echo -e "${GREEN}Step 2: Generating client private key...${NC}"
openssl genrsa -out client-key.pem 4096

echo -e "${GREEN}Step 3: Creating certificate signing request (CSR)...${NC}"
openssl req -new \
    -key client-key.pem \
    -out client-csr.pem \
    -subj "/CN=${COMMON_NAME}/O=Claude Code Playground/OU=Devcontainer"

echo -e "${GREEN}Step 4: Creating OpenSSL config for client certificate...${NC}"
cat > client-ext.cnf << EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo -e "${GREEN}Step 5: Signing client certificate with CA...${NC}"
openssl x509 -req \
    -in client-csr.pem \
    -CA ca-cert.pem \
    -CAkey ca-key.pem \
    -CAcreateserial \
    -out client-cert.pem \
    -days "${VALIDITY_DAYS}" \
    -extfile client-ext.cnf

echo -e "${GREEN}Step 6: Verifying certificate chain...${NC}"
openssl verify -CAfile ca-cert.pem client-cert.pem

echo -e "${GREEN}Step 7: Creating base64-encoded versions for Codespaces secrets...${NC}"
base64 -w 0 client-cert.pem > client-cert-base64.txt
base64 -w 0 client-key.pem > client-key-base64.txt

# Set secure permissions
chmod 600 ca-key.pem client-key.pem client-key-base64.txt
chmod 644 ca-cert.pem client-cert.pem client-cert-base64.txt

# Clean up intermediate files
rm -f client-csr.pem client-ext.cnf ca-ext.cnf ca-cert.srl

echo ""
echo -e "${GREEN}=== Certificate Generation Complete ===${NC}"
echo ""
echo "Generated files in ${CERTS_DIR}:"
echo "  CA Certificate:         ca-cert.pem"
echo "  CA Private Key:         ca-key.pem (KEEP SECURE!)"
echo "  Client Certificate:     client-cert.pem"
echo "  Client Private Key:     client-key.pem (KEEP SECURE!)"
echo "  Base64 Certificate:     client-cert-base64.txt"
echo "  Base64 Private Key:     client-key-base64.txt"
echo ""
echo -e "${YELLOW}=== Next Steps ===${NC}"
echo ""
echo "1. Deploy the bootstrap CloudFormation stack:"
echo ""
cat <<EOF
   ./scripts/deploy-bootstrap.sh --first-run --region ${AWS_REGION}

   Or manually:

   aws cloudformation deploy \\
     --template-file ${SCRIPT_DIR}/bootstrap.template \\
     --stack-name claude-code-bootstrap \\
     --region ${AWS_REGION} \\
     --capabilities CAPABILITY_NAMED_IAM \\
     --parameter-overrides \\
       CACertificateBody="\$(cat ${CERTS_DIR}/ca-cert.pem)"
EOF
echo ""
echo "2. Get the output values:"
echo ""
cat <<EOF
   aws cloudformation describe-stacks \\
     --stack-name claude-code-bootstrap \\
     --region ${AWS_REGION} \\
     --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \\
     --output table
EOF
echo ""
echo "3. Add these as GitHub Codespaces secrets:"
echo ""
echo "   ROLES_ANYWHERE_CERTIFICATE      = contents of client-cert-base64.txt"
echo "   ROLES_ANYWHERE_PRIVATE_KEY      = contents of client-key-base64.txt"
echo "   ROLES_ANYWHERE_TRUST_ANCHOR_ARN = RolesAnywhereTrustAnchorArn from stack outputs"
echo "   ROLES_ANYWHERE_PROFILE_ARN      = RolesAnywhereProfileArn from stack outputs"
echo "   ROLES_ANYWHERE_ROLE_ARN         = DevcontainerRoleArn from stack outputs"
echo ""
echo -e "${RED}IMPORTANT: Keep ca-key.pem and client-key.pem secure!${NC}"
echo "Do not commit private keys to version control."
