#!/bin/bash
# Generate scripts for WordPress app from templates

APP_NAME="$1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[SCRIPTS]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ]; then
    print_error "Usage: $0 <app-name>"
    echo "Example: $0 ecommerce-site"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app-structure.sh first to create the app structure"
    exit 1
fi

print_status "Generating scripts for $APP_NAME from templates..."

# Copy script templates if they exist
scripts_copied=0

if [ -f "$TEMPLATES_DIR/install-plugins.template.sh" ]; then
    cp "$TEMPLATES_DIR/install-plugins.template.sh" "$APP_DIR/scripts/install-plugins.sh"
    chmod +x "$APP_DIR/scripts/install-plugins.sh"
    print_status "Copied install-plugins.sh from template"
    ((scripts_copied++))
fi

if [ -f "$TEMPLATES_DIR/deploy-app.template.sh" ]; then
    cp "$TEMPLATES_DIR/deploy-app.template.sh" "$APP_DIR/scripts/deploy-app.sh"
    chmod +x "$APP_DIR/scripts/deploy-app.sh"
    print_status "Copied deploy-app.sh from template"
    ((scripts_copied++))
fi

if [ -f "$TEMPLATES_DIR/health-check.template.sh" ]; then
    cp "$TEMPLATES_DIR/health-check.template.sh" "$APP_DIR/scripts/health-check.sh"
    chmod +x "$APP_DIR/scripts/health-check.sh"
    print_status "Copied health-check.sh from template"
    ((scripts_copied++))
fi

if [ -f "$TEMPLATES_DIR/backup-app.template.sh" ]; then
    cp "$TEMPLATES_DIR/backup-app.template.sh" "$APP_DIR/scripts/backup-app.sh"
    chmod +x "$APP_DIR/scripts/backup-app.sh"
    print_status "Copied backup-app.sh from template"
    ((scripts_copied++))
fi

# Replace placeholders if any templates were copied
if [ $scripts_copied -gt 0 ]; then
    print_status "Replacing placeholders in scripts..."
    
    # Replace {{APP_NAME}} in all script files
    find "$APP_DIR/scripts/" -name "*.sh" -exec sed -i "s/{{APP_NAME}}/$APP_NAME/g" {} \;
    
    print_status "Applied script template substitutions"
fi

print_success "✅ Scripts generated: $scripts_copied files from templates"

if [ $scripts_copied -eq 0 ]; then
    print_status "No script templates found in $TEMPLATES_DIR"
    print_status "Expected template files:"
    print_status "  - install-plugins.template.sh"
    print_status "  - deploy-app.template.sh"
    print_status "  - health-check.template.sh"
    print_status "  - backup-app.template.sh"
fi

echo ""
print_status "Available scripts in $APP_DIR/scripts/:"
ls -la "$APP_DIR/scripts/"

echo ""
print_status "Scripts are executable and ready to use!"