#!/bin/bash
# Generate nginx configuration file for WordPress app based on template

APP_NAME="$1"
PORT_START="$2"
SERVER_IP="${3:-192.99.35.79}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[NGINX]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port> [server-ip]"
    echo "Example: $0 ecommerce-site 5000 192.99.35.79"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/nginx.template.conf"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
NGINX_FILE="$APP_DIR/nginx.conf"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Nginx template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app.sh first to create the app structure"
    exit 1
fi

print_status "Generating nginx configuration for $APP_NAME..."

# Copy template and replace placeholders
cp "$TEMPLATE_FILE" "$NGINX_FILE"

# Replace placeholders in nginx config
sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$NGINX_FILE"
sed -i "s/{{SERVER_IP}}/$SERVER_IP/g" "$NGINX_FILE"
sed -i "s/{{SERVER_NAME}}/$SERVER_IP/g" "$NGINX_FILE"
sed -i "s/{{PORT_START}}/$PORT_START/g" "$NGINX_FILE"

print_status "Applied nginx template substitutions"

# Create nginx directory structure if needed
mkdir -p "$APP_DIR/nginx-conf"

# Also create a copy in nginx-conf directory for backup
cp "$NGINX_FILE" "$APP_DIR/nginx-conf/default.conf"

print_success "✅ Nginx config generated: $NGINX_FILE"
print_success "✅ Backup created: $APP_DIR/nginx-conf/default.conf"

echo ""
echo "🌐 Nginx Configuration:"
echo "  📁 Config file: $NGINX_FILE"
echo "  🖥️  Server: $SERVER_IP"
echo "  🚪 Port: $PORT_START"
echo "  🔗 Upstream: wordpress:80"
echo ""
echo "📋 Next Steps:"
echo "  1. Review nginx.conf for any custom modifications"
echo "  2. Test nginx configuration if needed"
echo "  3. The config will be used by Docker Compose"