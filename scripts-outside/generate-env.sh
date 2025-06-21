#!/bin/bash
# Generate .env file for WordPress app based on template

APP_NAME="$1"
PORT_START="$2"
SERVER_IP="${3:-192.99.35.79}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[ENV]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port> [server-ip]"
    echo "Example: $0 ecommerce-site 5000 192.99.35.79"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/template.env"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
ENV_FILE="$APP_DIR/.env"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app-structure.sh first to create the app structure"
    exit 1
fi

print_status "Generating .env file for $APP_NAME..."

# Generate random passwords
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
WP_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)

print_status "Generated secure passwords"

# Create WP_URL
WP_URL="http://$SERVER_IP:$PORT_START"

# Read template and replace placeholders
cp "$TEMPLATE_FILE" "$ENV_FILE"

# Replace placeholders in .env file
sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$ENV_FILE"
sed -i "s/{{MYSQL_ROOT_PASSWORD}}/$MYSQL_ROOT_PASSWORD/g" "$ENV_FILE"
sed -i "s/{{MYSQL_PASSWORD}}/$MYSQL_PASSWORD/g" "$ENV_FILE"
sed -i "s/{{WP_ADMIN_PASSWORD}}/$WP_ADMIN_PASSWORD/g" "$ENV_FILE"
sed -i "s|{{WP_URL}}|$WP_URL|g" "$ENV_FILE"

print_status "Applied template substitutions"

# Create credentials file for reference
cat > "$APP_DIR/CREDENTIALS.txt" << EOF
# Generated Credentials for $APP_NAME
# Generated on: $(date)
# Save this file securely!

App Name: $APP_NAME
Server IP: $SERVER_IP
WordPress URL: $WP_URL
phpMyAdmin URL: http://$SERVER_IP:$((PORT_START + 1))

MySQL Root Password: $MYSQL_ROOT_PASSWORD
MySQL User Password: $MYSQL_PASSWORD
WordPress Admin Password: $WP_ADMIN_PASSWORD

WordPress Admin Login:
- Username: admin
- Password: $WP_ADMIN_PASSWORD
- Email: admin@${APP_NAME}.local

Database Info:
- Database: ${APP_NAME}_db
- Username: ${APP_NAME}_user
- Password: $MYSQL_PASSWORD

Port Configuration:
- WordPress (Nginx): $PORT_START
- phpMyAdmin: $((PORT_START + 1))
- MySQL: $((PORT_START + 20))

Docker Volumes:
- ${APP_NAME}_db_data (MySQL data)
- ${APP_NAME}_wp_data (WordPress core)
- ${APP_NAME}_plugins (WordPress plugins)

Access URLs:
- Frontend: $WP_URL
- Admin: $WP_URL/wp-admin
- phpMyAdmin: http://$SERVER_IP:$((PORT_START + 1))
EOF

print_success "✅ .env file generated: $ENV_FILE"
print_success "✅ Credentials saved: $APP_DIR/CREDENTIALS.txt"

echo ""
echo "🔐 Generated Credentials:"
echo "  📝 WordPress Admin: admin / $WP_ADMIN_PASSWORD"
echo "  🗄️ MySQL User: ${APP_NAME}_user / $MYSQL_PASSWORD"
echo "  🔑 MySQL Root: root / $MYSQL_ROOT_PASSWORD"
echo ""
echo "🌐 Access URLs:"
echo "  🧪 WordPress: $WP_URL"
echo "  🗄️ phpMyAdmin: http://$SERVER_IP:$((PORT_START + 1))"
echo ""
echo "⚠️  IMPORTANT: Save CREDENTIALS.txt securely and don't commit it to Git!"