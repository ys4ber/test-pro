#!/bin/bash
# Generate Azure DevOps pipeline for WordPress app

APP_NAME="$1"
PORT_START="$2"
DEPLOY_USER="${3:-liadwordpress}" # setting the default deploy user if not provided
SERVER_IP="${4:-192.99.35.79}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[PIPELINE]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port> [deploy-user] [server-ip]"
    echo "Example: $0 ecommerce-site 5000 liadwordpress 192.99.35.79"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/azure-pipelines.template.yml"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
PIPELINE_FILE="$APP_DIR/azure-pipelines.yml"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Pipeline template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app-structure.sh first to create the app structure"
    exit 1
fi

print_status "Generating Azure DevOps pipeline for $APP_NAME..."

# Calculate port assignments
PORT_TEST="$PORT_START"
PORT_PREPROD="$((PORT_START + 100))"
PORT_PROD="$((PORT_START + 200))"
PMA_PORT_TEST="$((PORT_START + 1))"
PMA_PORT_PREPROD="$((PORT_START + 101))"
PMA_PORT_PROD="$((PORT_START + 201))"

print_status "Port assignments:"
print_status "  Test:    WordPress=$PORT_TEST, phpMyAdmin=$PMA_PORT_TEST"
print_status "  PreProd: WordPress=$PORT_PREPROD, phpMyAdmin=$PMA_PORT_PREPROD"
print_status "  Prod:    WordPress=$PORT_PROD, phpMyAdmin=$PMA_PORT_PROD"

# Copy template and replace placeholders
cp "$TEMPLATE_FILE" "$PIPELINE_FILE"

# Replace placeholders in pipeline file
sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$PIPELINE_FILE"
sed -i "s/{{DEPLOY_USER}}/$DEPLOY_USER/g" "$PIPELINE_FILE"
sed -i "s/{{SERVER_IP}}/$SERVER_IP/g" "$PIPELINE_FILE"
sed -i "s/{{PORT_START}}/$PORT_TEST/g" "$PIPELINE_FILE"
sed -i "s/{{PORT_PREPROD}}/$PORT_PREPROD/g" "$PIPELINE_FILE"
sed -i "s/{{PORT_PROD}}/$PORT_PROD/g" "$PIPELINE_FILE"
sed -i "s/{{PMA_PORT_TEST}}/$PMA_PORT_TEST/g" "$PIPELINE_FILE"
sed -i "s/{{PMA_PORT_PREPROD}}/$PMA_PORT_PREPROD/g" "$PIPELINE_FILE"
sed -i "s/{{PMA_PORT_PROD}}/$PMA_PORT_PROD/g" "$PIPELINE_FILE"

print_status "Applied pipeline template substitutions"

# Create pipeline configuration summary
cat > "$APP_DIR/PIPELINE_CONFIG.md" << EOF
# Azure DevOps Pipeline Configuration for $APP_NAME

## Pipeline Details
- **Name**: $APP_NAME-Deploy-Ansible-v2
- **Template**: azure-pipelines.template.yml
- **Generated**: $(date)

## Environment Configuration

### Test Environment
- **WordPress URL**: http://$SERVER_IP:$PORT_TEST
- **phpMyAdmin URL**: http://$SERVER_IP:$PMA_PORT_TEST
- **Inventory**: ansible/inventories/test/hosts
- **Environment**: $APP_NAME-test-env

### PreProd Environment  
- **WordPress URL**: http://$SERVER_IP:$PORT_PREPROD
- **phpMyAdmin URL**: http://$SERVER_IP:$PMA_PORT_PREPROD
- **Inventory**: ansible/inventories/preprod/hosts
- **Environment**: $APP_NAME-preprod-env

### Production Environment
- **WordPress URL**: http://$SERVER_IP:$PORT_PROD
- **phpMyAdmin URL**: http://$SERVER_IP:$PMA_PORT_PROD
- **Inventory**: ansible/inventories/prod/hosts
- **Environment**: $APP_NAME-prod-env

## Deployment Flow
1. **Test Stage**: Deploy and validate in test environment
2. **PreProd Stage**: Deploy to preprod for final validation
3. **Production Stage**: Deploy to production (master branch only)
4. **Cleanup Stage**: Clean test and preprod environments

## Required Azure DevOps Setup

### Service Connections
Create SSH service connections for each environment:
- **Test**: SSH connection to $DEPLOY_USER@$SERVER_IP
- **PreProd**: SSH connection to $DEPLOY_USER@$SERVER_IP  
- **Production**: SSH connection to $DEPLOY_USER@$SERVER_IP

### Environments
Create the following environments in Azure DevOps:
- \`$APP_NAME-test-env\`
- \`$APP_NAME-preprod-env\`
- \`$APP_NAME-prod-env\`

### Variables
The pipeline uses these variables:
- APP_NAME: '$APP_NAME'
- DEPLOY_USER: '$DEPLOY_USER'
- SERVER_IP: '$SERVER_IP'

## Ansible Integration
The pipeline uses Ansible playbooks located in:
- \`ansible/deploy.yml\` - Main deployment playbook
- \`ansible/inventories/test/hosts\` - Test inventory
- \`ansible/inventories/preprod/hosts\` - PreProd inventory
- \`ansible/inventories/prod/hosts\` - Production inventory

## Trigger Configuration
- **Branch Triggers**: master, main, development
- **Path Triggers**: apps/$APP_NAME/**/*
- **PR Triggers**: master, main

## Health Checks
The pipeline includes comprehensive health checks:
- WordPress frontend accessibility
- WordPress admin panel accessibility
- phpMyAdmin accessibility
- Container status verification

## Maintenance Features
- Automatic backup before production deployment
- Maintenance mode during production deployment
- Rollback capabilities through Ansible
- Environment cleanup after successful deployment
EOF

print_success "✅ Azure DevOps pipeline generated: $PIPELINE_FILE"
print_success "✅ Pipeline configuration documented: $APP_DIR/PIPELINE_CONFIG.md"

echo ""
echo "🚀 Azure DevOps Pipeline Configuration:"
echo "  📄 File: $PIPELINE_FILE"
echo "  🎯 Test Environment: http://$SERVER_IP:$PORT_TEST"
echo "  🚧 PreProd Environment: http://$SERVER_IP:$PORT_PREPROD"
echo "  🏭 Production Environment: http://$SERVER_IP:$PORT_PROD"
echo ""
echo "📋 Next Steps:"
echo "  1. Commit the pipeline file to your repository"
echo "  2. Create Azure DevOps environments:"
echo "     - $APP_NAME-test-env"
echo "     - $APP_NAME-preprod-env"
echo "     - $APP_NAME-prod-env"
echo "  3. Configure SSH service connections in Azure DevOps"
echo "  4. Update Ansible inventory files with correct server details"
echo "  5. Test the pipeline with a development branch push"
echo ""
echo "🔧 Ansible Requirements:"
echo "  - Ensure ansible/deploy.yml playbook exists"
echo "  - Configure inventory files in ansible/inventories/"
echo "  - Set up SSH keys for deployment user"
echo ""