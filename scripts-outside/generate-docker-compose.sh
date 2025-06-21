#!/bin/bash
# Generate docker-compose.yml file for WordPress app based on template

APP_NAME="$1"
PORT_START="$2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[DOCKER]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port>"
    echo "Example: $0 ecommerce-site 5000"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/docker-compose.template.yml"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
DOCKER_COMPOSE_FILE="$APP_DIR/docker-compose.yml"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Docker Compose template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app.sh first to create the app structure"
    exit 1
fi

print_status "Generating docker-compose.yml for $APP_NAME..."

# Calculate ports
NGINX_PORT="$PORT_START"
PHPMYADMIN_PORT="$((PORT_START + 1))"
MYSQL_PORT="$((PORT_START + 20))"

print_status "Port assignments:"
print_status "  Nginx: $NGINX_PORT"
print_status "  phpMyAdmin: $PHPMYADMIN_PORT"
print_status "  MySQL: $MYSQL_PORT"

# Copy template and replace placeholders
cp "$TEMPLATE_FILE" "$DOCKER_COMPOSE_FILE"

# Replace placeholders in docker-compose.yml
sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/{{NGINX_PORT}}/$NGINX_PORT/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/{{PHPMYADMIN_PORT}}/$PHPMYADMIN_PORT/g" "$DOCKER_COMPOSE_FILE"
sed -i "s/{{DB_PORT}}/$MYSQL_PORT/g" "$DOCKER_COMPOSE_FILE"

print_status "Applied docker-compose template substitutions"

# Create necessary directories referenced in docker-compose
mkdir -p "$APP_DIR/wp-content"/{themes,uploads}
mkdir -p "$APP_DIR/php-conf"
mkdir -p "$APP_DIR/logs"

# Create PHP configuration file
cat > "$APP_DIR/php-conf/uploads.ini" << EOF
upload_max_filesize = 2048M
post_max_size = 2048M
memory_limit = 2048M
max_execution_time = 2000
max_input_time = 2000
max_input_vars = 5000
EOF

print_status "Created PHP configuration file"

print_success "✅ Docker Compose file generated: $DOCKER_COMPOSE_FILE"
print_success "✅ Supporting directories created"
print_success "✅ PHP configuration created: $APP_DIR/php-conf/uploads.ini"

echo ""
echo "🐳 Docker Configuration:"
echo "  📄 File: $DOCKER_COMPOSE_FILE"
echo "  🌐 Nginx: $SERVER_IP:$NGINX_PORT"
echo "  🗄️ phpMyAdmin: $SERVER_IP:$PHPMYADMIN_PORT"
echo "  🐬 MySQL: $SERVER_IP:$MYSQL_PORT"
echo ""
echo "📁 Created Directories:"
echo "  📂 wp-content/themes/ (WordPress themes)"
echo "  📂 wp-content/uploads/ (WordPress uploads)"
echo "  📂 php-conf/ (PHP configuration)"
echo "  📂 logs/ (Application logs)"
echo ""
echo "🐳 Docker Volumes:"
echo "  📦 ${APP_NAME}_db_data (MySQL data persistence)"
echo "  📦 ${APP_NAME}_wp_data (WordPress core files)"
echo "  📦 ${APP_NAME}_plugins (WordPress plugins persistence)"
echo ""
echo "📋 Next Steps:"
echo "  1. Review docker-compose.yml for any custom modifications"
echo "  2. Ensure .env file is generated (run generate-env.sh)"
echo "  3. Start containers: cd apps/$APP_NAME && docker compose up -d"