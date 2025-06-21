#!/bin/bash
# Complete WordPress app setup - runs all generation scripts in sequence

APP_NAME="$1"
PORT_START="$2"
SERVER_IP="${3:-192.99.35.79}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[SETUP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port> [server-ip]"
    echo "Example: $0 ecommerce-site 5000 192.99.35.79"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status "🚀 Starting complete WordPress app setup for: $APP_NAME"
print_status "🔢 Port: $PORT_START"
print_status "🖥️  Server: $SERVER_IP"

echo ""
echo "🏗️  Step 1: Creating app structure..."
if "$SCRIPT_DIR/create-app-structure.sh" "$APP_NAME"; then
    print_success "✅ App structure created"
else
    print_error "❌ Failed to create app structure"
    exit 1
fi

echo ""
echo "🔧 Step 2: Generating .env file..."
if "$SCRIPT_DIR/generate-env.sh" "$APP_NAME" "$PORT_START" "$SERVER_IP"; then
    print_success "✅ .env file generated"
else
    print_error "❌ Failed to generate .env file"
    exit 1
fi

echo ""
echo "🌐 Step 3: Generating nginx configuration..."
if "$SCRIPT_DIR/generate-nginx.sh" "$APP_NAME" "$PORT_START" "$SERVER_IP"; then
    print_success "✅ Nginx config generated"
else
    print_error "❌ Failed to generate nginx config"
    exit 1
fi

echo ""
echo "🐳 Step 4: Generating docker-compose.yml..."
if "$SCRIPT_DIR/generate-docker-compose.sh" "$APP_NAME" "$PORT_START"; then
    print_success "✅ Docker Compose file generated"
else
    print_error "❌ Failed to generate docker-compose file"
    exit 1
fi

echo ""
echo "📜 Step 5: Generating scripts from templates..."
if "$SCRIPT_DIR/generate-scripts.sh" "$APP_NAME"; then
    print_success "✅ Scripts generated from templates"
else
    print_warning "⚠️ Scripts generation had issues (this might be normal if no templates exist)"
fi

echo ""
echo "🔄 Step 6: Generating Azure DevOps pipeline..."
if "$SCRIPT_DIR/generate-pipeline.sh" "$APP_NAME" "$PORT_START" "$DEPLOY_USER" "$SERVER_IP"; then
    print_success "✅ Azure DevOps pipeline generated"
else
    print_error "❌ Failed to generate pipeline"
    exit 1
fi

echo ""
echo "🎭 Step 7: Generating complete Ansible configuration..."
if "$SCRIPT_DIR/generate-ansible.sh" "$APP_NAME" "$PORT_START" "$DEPLOY_USER" "$SERVER_IP"; then
    print_success "✅ Ansible configuration generated"
else
    print_error "❌ Failed to generate Ansible configuration"
    exit 1
fi

echo ""
echo "📋 Step 8: Creating Makefile..."
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
cat > "$APP_DIR/Makefile" << EOF
# Makefile for $APP_NAME
include .env
export

.PHONY: start stop restart logs shell wp-shell db-shell backup setup status health-check

start: ## Start this WordPress app
	docker compose up -d

stop: ## Stop this WordPress app
	docker compose down

restart: ## Restart this WordPress app
	docker compose restart

logs: ## Show logs
	docker compose logs -f

shell: ## Access WordPress container shell
	docker compose exec wordpress bash

wp-shell: ## Access WP-CLI
	docker compose run --rm wpcli bash

db-shell: ## Access database shell
	docker compose exec database mysql -u root -p\$(MYSQL_ROOT_PASSWORD)

backup: ## Create backup
	./scripts/backup-app.sh \$(APP_NAME)

setup: ## Setup WordPress
	docker compose up -d
	sleep 15
	docker compose run --rm wpcli core download || true
	docker compose run --rm wpcli config create \\
		--dbname=\$(WORDPRESS_DB_NAME) \\
		--dbuser=\$(WORDPRESS_DB_USER) \\
		--dbpass=\$(WORDPRESS_DB_PASSWORD) \\
		--dbhost=\$(WORDPRESS_DB_HOST) \\
		--force || true
	docker compose run --rm wpcli core install \\
		--url=\$(WP_URL) \\
		--title="\$(WP_TITLE)" \\
		--admin_user=\$(WP_ADMIN_USER) \\
		--admin_password=\$(WP_ADMIN_PASSWORD) \\
		--admin_email=\$(WP_ADMIN_EMAIL) || true

health-check: ## Run health check
	./scripts/health-check.sh $APP_NAME "\$(WP_URL)"

status: ## Show container status
	docker compose ps

help: ## Show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*\$\$' \$(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", \$\$1, \$\$2}'
EOF

print_success "✅ Makefile created"

echo ""
echo "📝 Step 9: Creating README..."
cat > "$APP_DIR/README.md" << EOF
# $APP_NAME WordPress Application

## 🚀 Quick Start

\`\`\`bash
# Start the application
make start

# Setup WordPress
make setup

# View logs
make logs
\`\`\`

## 🌐 Access Points

- **Frontend**: http://$SERVER_IP:$PORT_START
- **Admin**: http://$SERVER_IP:$PORT_START/wp-admin
- **phpMyAdmin**: http://$SERVER_IP:$((PORT_START + 1))

## 🔑 Credentials

See \`CREDENTIALS.txt\` file for all passwords.

## 🛠️ Management Commands

\`\`\`bash
make start          # Start containers
make stop           # Stop containers  
make restart        # Restart containers
make logs           # View logs
make setup          # Initial WordPress setup
make status         # Show container status
make backup         # Create backup
make health-check   # Run health check
\`\`\`

## 📁 File Structure

- \`docker-compose.yml\` - Docker configuration
- \`.env\` - Environment variables  
- \`nginx.conf\` - Nginx configuration
- \`CREDENTIALS.txt\` - Generated passwords
- \`wp-content/\` - WordPress content
- \`scripts/\` - Management scripts
- \`ansible/\` - Ansible deployment configuration

## 🔧 Generated Configuration

This app was generated using template-based scripts:
- \`generate-env.sh\` - Created .env file
- \`generate-nginx.sh\` - Created nginx.conf
- \`generate-docker-compose.sh\` - Created docker-compose.yml

Port assignments:
- WordPress: $PORT_START
- phpMyAdmin: $((PORT_START + 1))
- MySQL: $((PORT_START + 20))

## 🚀 Deployment

Use the Ansible configuration in \`ansible/\` directory for automated deployment.
EOF

print_success "✅ README created"

echo ""
print_success "🎉 Complete WordPress app setup finished!"

echo ""
echo "📋 Summary:"
echo "  📁 App: $APP_NAME"
echo "  📍 Location: $APP_DIR"
echo "  🌐 WordPress: http://$SERVER_IP:$PORT_START"
echo "  🗄️ phpMyAdmin: http://$SERVER_IP:$((PORT_START + 1))"
echo ""
echo "🔐 Credentials saved in: $APP_DIR/CREDENTIALS.txt"
echo ""
echo "🚀 Next Steps:"
echo "  1. cd apps/$APP_NAME"
echo "  2. make start"
echo "  3. make setup"
echo "  4. Visit http://$SERVER_IP:$PORT_START"
echo ""
echo "⚠️  Remember to save CREDENTIALS.txt securely!"