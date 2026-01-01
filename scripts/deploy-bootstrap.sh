#!/usr/bin/env bash
#
# deploy-bootstrap.sh - Deploy or update the bootstrap CloudFormation stack
#
# This script deploys the bootstrap.template CloudFormation stack which contains:
# - S3 bucket for Terraform state (with native locking)
# - IAM Roles Anywhere configuration
# - SSM Parameter Store configuration values
#
# Usage:
#   ./scripts/deploy-bootstrap.sh [--first-run] [--region REGION]
#
# Options:
#   --first-run     First deployment (requires CA certificate generation)
#   --region        AWS region (default: us-west-2)
#   --project-name  Project name override (default: claude-code-playground)
#   --environment   Environment (dev/staging/prod, default: dev)
#   --help          Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AWS_INFRA_DIR="${REPO_ROOT}/aws-infrastructure"
TEMPLATE_FILE="${AWS_INFRA_DIR}/bootstrap.template"
CERTS_DIR="${AWS_INFRA_DIR}/certificates"

# Default values
STACK_NAME="claude-code-bootstrap"
REGION="${AWS_REGION:-us-west-2}"
PROJECT_NAME="claude-code-playground"
ENVIRONMENT="dev"
FIRST_RUN=false

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Deploy or update the bootstrap CloudFormation stack.

Options:
    --first-run         First deployment (will generate certificates if needed)
    --region REGION     AWS region (default: ${REGION})
    --project-name NAME Project name (default: ${PROJECT_NAME})
    --environment ENV   Environment: dev, staging, prod (default: ${ENVIRONMENT})
    --help              Show this help message

Examples:
    # First deployment
    ${0##*/} --first-run --region us-west-2

    # Update existing stack
    ${0##*/}

    # Deploy to production
    ${0##*/} --environment prod
EOF
}

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid."
        print_error "Please configure AWS credentials before running this script."
        exit 1
    fi

    # Check template file exists
    if [[ ! -f "${TEMPLATE_FILE}" ]]; then
        print_error "Bootstrap template not found at: ${TEMPLATE_FILE}"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

validate_template() {
    print_info "Validating CloudFormation template..."

    if ! aws cloudformation validate-template \
        --template-body "file://${TEMPLATE_FILE}" \
        --region "${REGION}" > /dev/null; then
        print_error "Template validation failed"
        exit 1
    fi

    print_success "Template validation passed"
}

generate_certificates() {
    print_info "Checking for existing certificates..."

    if [[ -f "${CERTS_DIR}/ca-cert.pem" ]] && [[ -f "${CERTS_DIR}/client-cert.pem" ]]; then
        print_info "Certificates already exist in ${CERTS_DIR}"
        read -p "Do you want to regenerate certificates? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    print_info "Generating certificates..."

    if [[ -f "${AWS_INFRA_DIR}/generate-certificates.sh" ]]; then
        cd "${AWS_INFRA_DIR}"
        ./generate-certificates.sh
        cd "${REPO_ROOT}"
    else
        print_error "Certificate generation script not found"
        exit 1
    fi

    print_success "Certificates generated successfully"
}

deploy_stack() {
    print_info "Deploying CloudFormation stack: ${STACK_NAME}"

    # Check if CA certificate exists
    if [[ ! -f "${CERTS_DIR}/ca-cert.pem" ]]; then
        print_error "CA certificate not found at: ${CERTS_DIR}/ca-cert.pem"
        print_error "Please generate certificates first with: ${0##*/} --first-run"
        exit 1
    fi

    # Read CA certificate
    CA_CERT="$(cat "${CERTS_DIR}/ca-cert.pem")"

    # Check if stack exists
    STACK_EXISTS=false
    if aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" &> /dev/null; then
        STACK_EXISTS=true
        print_info "Stack exists, updating..."
    else
        print_info "Stack does not exist, creating..."
    fi

    # Deploy the stack
    print_info "Starting CloudFormation deployment..."

    if aws cloudformation deploy \
        --template-file "${TEMPLATE_FILE}" \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides \
            "ProjectName=${PROJECT_NAME}" \
            "Environment=${ENVIRONMENT}" \
            "CACertificateBody=${CA_CERT}" \
        --tags \
            "Project=${PROJECT_NAME}" \
            "Environment=${ENVIRONMENT}" \
            "ManagedBy=CloudFormation" \
        --no-fail-on-empty-changeset; then
        print_success "Stack deployment completed successfully"
    else
        print_error "Stack deployment failed"
        print_info "Check CloudFormation events for details:"
        print_info "  aws cloudformation describe-stack-events --stack-name ${STACK_NAME} --region ${REGION}"
        exit 1
    fi
}

show_outputs() {
    print_info "Stack outputs:"
    echo ""

    aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table

    echo ""
    print_info "SSM Parameters created:"
    aws ssm get-parameters-by-path \
        --path "/${PROJECT_NAME}/" \
        --region "${REGION}" \
        --query 'Parameters[*].[Name,Value]' \
        --output table 2>/dev/null || true
}

show_next_steps() {
    echo ""
    print_info "Next steps:"
    echo ""

    # Get outputs for display
    TRUST_ANCHOR_ARN=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`RolesAnywhereTrustAnchorArn`].OutputValue' \
        --output text 2>/dev/null || echo "")

    PROFILE_ARN=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`RolesAnywhereProfileArn`].OutputValue' \
        --output text 2>/dev/null || echo "")

    ROLE_ARN=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --query 'Stacks[0].Outputs[?OutputKey==`DevcontainerRoleArn`].OutputValue' \
        --output text 2>/dev/null || echo "")

    if [[ "${FIRST_RUN}" == "true" ]]; then
        echo "1. Configure GitHub Codespaces secrets (if using Codespaces):"
        echo "   - ROLES_ANYWHERE_CERTIFICATE: $(cat "${CERTS_DIR}/client-cert-base64.txt" 2>/dev/null || echo 'base64 encoded client-cert.pem')"
        echo "   - ROLES_ANYWHERE_PRIVATE_KEY: $(cat "${CERTS_DIR}/client-key-base64.txt" 2>/dev/null || echo 'base64 encoded client-key.pem')"
        echo "   - ROLES_ANYWHERE_TRUST_ANCHOR_ARN: ${TRUST_ANCHOR_ARN}"
        echo "   - ROLES_ANYWHERE_PROFILE_ARN: ${PROFILE_ARN}"
        echo "   - ROLES_ANYWHERE_ROLE_ARN: ${ROLE_ARN}"
        echo ""
        echo "2. For local development, set these environment variables:"
        echo "   export ROLES_ANYWHERE_TRUST_ANCHOR_ARN=\"${TRUST_ANCHOR_ARN}\""
        echo "   export ROLES_ANYWHERE_PROFILE_ARN=\"${PROFILE_ARN}\""
        echo "   export ROLES_ANYWHERE_ROLE_ARN=\"${ROLE_ARN}\""
        echo ""
        echo "3. Initialize Terraform:"
        echo "   ./scripts/init-terraform.sh"
        echo ""
    else
        echo "1. Verify AWS access:"
        echo "   aws sts get-caller-identity"
        echo ""
        echo "2. Initialize Terraform (if not done):"
        echo "   ./scripts/init-terraform.sh"
        echo ""
    fi

    print_success "Bootstrap deployment complete!"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --first-run)
            FIRST_RUN=true
            shift
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  Bootstrap CloudFormation Deployment"
    echo "=============================================="
    echo ""
    print_info "Stack Name:    ${STACK_NAME}"
    print_info "Region:        ${REGION}"
    print_info "Project:       ${PROJECT_NAME}"
    print_info "Environment:   ${ENVIRONMENT}"
    print_info "First Run:     ${FIRST_RUN}"
    echo ""

    check_prerequisites
    validate_template

    if [[ "${FIRST_RUN}" == "true" ]]; then
        generate_certificates
    fi

    deploy_stack
    show_outputs
    show_next_steps
}

main "$@"
