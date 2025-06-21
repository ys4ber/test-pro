#!/bin/bash
# Generate complete Ansible configuration for WordPress app

APP_NAME="$1"
PORT_START="$2"
DEPLOY_USER="${3:-liadwordpress}"
SERVER_IP="${4:-192.99.35.79}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[ANSIBLE]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validation
if [ -z "$APP_NAME" ] || [ -z "$PORT_START" ]; then
    print_error "Usage: $0 <app-name> <starting-port> [deploy-user] [server-ip]"
    echo "Example: $0 ecommerce-site 5000 liadwordpress 192.99.35.79"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
APP_DIR="$SCRIPT_DIR/../apps/$APP_NAME"
ANSIBLE_DIR="$APP_DIR/ansible"

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "App directory not found: $APP_DIR"
    print_error "Run create-app-structure.sh first to create the app structure"
    exit 1
fi

print_status "Generating complete Ansible configuration for $APP_NAME..."

# Calculate port assignments
PORT_TEST="$PORT_START"
PORT_PREPROD="$((PORT_START + 100))"
PORT_PROD="$((PORT_START + 200))"

print_status "Environment ports:"
print_status "  Test: $PORT_TEST"
print_status "  PreProd: $PORT_PREPROD"
print_status "  Production: $PORT_PROD"

# Create Ansible directory structure
mkdir -p "$ANSIBLE_DIR"/{tasks,group_vars}
mkdir -p "$ANSIBLE_DIR/inventories"/{test,preprod,prod}/group_vars
mkdir -p "$ANSIBLE_DIR/roles"/{wordpress,nginx,mysql}/{tasks,templates,vars,handlers}

# Generate main deploy.yml playbook
if [ -f "$TEMPLATES_DIR/deploy.template.yml" ]; then
    cp "$TEMPLATES_DIR/deploy.template.yml" "$ANSIBLE_DIR/deploy.yml"
    sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$ANSIBLE_DIR/deploy.yml"
    sed -i "s/{{DEPLOY_USER}}/$DEPLOY_USER/g" "$ANSIBLE_DIR/deploy.yml"
    print_status "Generated main playbook: deploy.yml"
else
    print_error "Deploy template not found: $TEMPLATES_DIR/deploy.template.yml"
fi

# Generate task files
task_files=("backup" "cleanup" "health_check" "maintenance" "logging")
for task in "${task_files[@]}"; do
    if [ -f "$TEMPLATES_DIR/${task}.template.yml" ]; then
        cp "$TEMPLATES_DIR/${task}.template.yml" "$ANSIBLE_DIR/tasks/${task}.yml"
        print_status "Generated task file: tasks/${task}.yml"
    fi
done

# Generate inventory files
environments=("test" "preprod" "prod")
ports=("$PORT_TEST" "$PORT_PREPROD" "$PORT_PROD")

for i in "${!environments[@]}"; do
    env="${environments[$i]}"
    port="${ports[$i]}"
    pma_port="$((port + 1))"
    
    # Create hosts file
    cat > "$ANSIBLE_DIR/inventories/$env/hosts" << EOF
[wordpress_servers]
$SERVER_IP ansible_user=$DEPLOY_USER ansible_ssh_private_key_file=~/.ssh/id_rsa

[wordpress_servers:vars]
environment=$env
app_name=$APP_NAME
EOF

    # Create group_vars/all.yml
    cat > "$ANSIBLE_DIR/inventories/$env/group_vars/all.yml" << EOF
---
# $env Environment Configuration for $APP_NAME
app_name: "$APP_NAME"
environment: "$env"
deploy_user: "$DEPLOY_USER"
server_ip: "$SERVER_IP"

# Port Configuration
wordpress_port: $port
phpmyadmin_port: $pma_port
mysql_port: $((port + 20))

# URLs
wp_url: "http://$SERVER_IP:$port"
pma_url: "http://$SERVER_IP:$pma_port"

# WordPress Configuration
wordpress_title: "$APP_NAME ${env^} Site"
wordpress_admin_user: "admin"
wordpress_admin_email: "admin@$APP_NAME-$env.local"

# Database Configuration
mysql_database: "${APP_NAME}_${env}_db"
mysql_user: "${APP_NAME}_${env}_user"

# Docker Configuration
docker_compose_file: "docker-compose.$env.yml"
container_prefix: "${APP_NAME}_${env}"

# Backup Configuration
backup_retention_days: $( [ "$env" = "prod" ] && echo "30" || [ "$env" = "preprod" ] && echo "14" || echo "7" )
backup_schedule: "$( [ "$env" = "prod" ] && echo "0 1 * * *" || [ "$env" = "preprod" ] && echo "0 3 * * *" || echo "0 2 * * *" )"

# Environment Settings
wp_debug: $( [ "$env" = "test" ] && echo "true" || echo "false" )
wp_environment_type: $( [ "$env" = "prod" ] && echo "production" || [ "$env" = "preprod" ] && echo "staging" || echo "development" )

# Security Settings (production only)
$( [ "$env" = "prod" ] && cat << 'PROD_SECURITY'
ssl_enabled: true
fail2ban_enabled: true
firewall_enabled: true
automatic_updates: false
PROD_SECURITY
)
EOF

    print_status "Generated $env inventory and variables"
done

# Generate WordPress role files
print_status "Generating WordPress role..."

# WordPress tasks
cat > "$ANSIBLE_DIR/roles/wordpress/tasks/main.yml" << 'EOF'
---
- name: Create application directory
  file:
    path: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'

- name: Stop existing containers
  docker_compose:
    project_src: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}"
    state: absent
  ignore_errors: yes

- name: Generate secure passwords
  set_fact:
    mysql_root_password: "{{ lookup('password', '/tmp/' + app_name + '_' + environment + '_mysql_root chars=ascii_letters,digits length=16') }}"
    mysql_password: "{{ lookup('password', '/tmp/' + app_name + '_' + environment + '_mysql_user chars=ascii_letters,digits length=16') }}"
    wp_admin_password: "{{ lookup('password', '/tmp/' + app_name + '_' + environment + '_wp_admin chars=ascii_letters,digits length=16') }}"

- name: Create .env file from template
  template:
    src: .env.j2
    dest: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/.env"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0600'

- name: Create docker-compose.yml from template
  template:
    src: docker-compose.yml.j2
    dest: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/docker-compose.yml"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0644'

- name: Create wp-content directories
  file:
    path: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/wp-content/{{ item }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  loop:
    - themes
    - uploads
    - plugins

- name: Start WordPress containers
  docker_compose:
    project_src: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}"
    state: present
  become_user: "{{ deploy_user }}"

- name: Wait for WordPress to be ready
  wait_for:
    port: "{{ wordpress_port }}"
    host: "{{ server_ip }}"
    delay: 30
    timeout: 120

- name: Configure WordPress URLs
  shell: |
    docker compose exec -T wpcli wp option update home "{{ wp_url }}" --allow-root
    docker compose exec -T wpcli wp option update siteurl "{{ wp_url }}" --allow-root
  args:
    chdir: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}"
  become_user: "{{ deploy_user }}"
  ignore_errors: yes
EOF

# WordPress templates - copy from main templates if they exist
if [ -f "$TEMPLATES_DIR/template.env" ]; then
    # Convert .env template to Jinja2 format
    sed 's/{{APP_NAME}}/{{ app_name }}/g; s/{{MYSQL_ROOT_PASSWORD}}/{{ mysql_root_password }}/g; s/{{MYSQL_PASSWORD}}/{{ mysql_password }}/g; s/{{WP_ADMIN_PASSWORD}}/{{ wp_admin_password }}/g; s/{{WP_URL}}/{{ wp_url }}/g' \
        "$TEMPLATES_DIR/template.env" > "$ANSIBLE_DIR/roles/wordpress/templates/.env.j2"
    
    # Add Ansible-specific variables
    cat >> "$ANSIBLE_DIR/roles/wordpress/templates/.env.j2" << 'EOF'

# --- ANSIBLE GENERATED VARIABLES ---
WP_DEBUG={{ wp_debug | default('false') }}
WP_ENVIRONMENT_TYPE={{ wp_environment_type | default('development') }}
EOF
fi

if [ -f "$TEMPLATES_DIR/docker-compose.template.yml" ]; then
    # Convert docker-compose template to Jinja2 format
    sed 's/{{APP_NAME}}/{{ container_prefix }}/g; s/{{NGINX_PORT}}/{{ wordpress_port }}/g; s/{{PHPMYADMIN_PORT}}/{{ phpmyadmin_port }}/g; s/{{DB_PORT}}/{{ mysql_port }}/g' \
        "$TEMPLATES_DIR/docker-compose.template.yml" > "$ANSIBLE_DIR/roles/wordpress/templates/docker-compose.yml.j2"
fi

# WordPress handlers
cat > "$ANSIBLE_DIR/roles/wordpress/handlers/main.yml" << 'EOF'
---
- name: restart wordpress
  docker_compose:
    project_src: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}"
    restarted: yes
  become_user: "{{ deploy_user }}"
EOF

# Generate Nginx role
print_status "Generating Nginx role..."

cat > "$ANSIBLE_DIR/roles/nginx/tasks/main.yml" << 'EOF'
---
- name: Create nginx configuration from template
  template:
    src: nginx.conf.j2
    dest: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/nginx.conf"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0644'
  notify: restart nginx container

- name: Create PHP configuration directory
  file:
    path: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/php-conf"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'

- name: Create PHP uploads configuration
  copy:
    content: |
      upload_max_filesize = 2048M
      post_max_size = 2048M
      memory_limit = 2048M
      max_execution_time = 2000
      max_input_time = 2000
      max_input_vars = 5000
    dest: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/php-conf/uploads.ini"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0644'
EOF

if [ -f "$TEMPLATES_DIR/nginx.template.conf" ]; then
    # Convert nginx template to Jinja2 format
    sed 's/{{SERVER_NAME}}/{{ server_ip }}/g; s/{{SERVER_IP}}/{{ server_ip }}/g' \
        "$TEMPLATES_DIR/nginx.template.conf" > "$ANSIBLE_DIR/roles/nginx/templates/nginx.conf.j2"
fi

# Generate MySQL role
print_status "Generating MySQL role..."

cat > "$ANSIBLE_DIR/roles/mysql/tasks/main.yml" << 'EOF'
---
- name: Create MySQL data directory
  file:
    path: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/mysql-data"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'

- name: Save database credentials for reference
  copy:
    content: |
      # Database Credentials for {{ app_name }} ({{ environment }})
      # Generated: {{ ansible_date_time.iso8601 }}
      
      MySQL Root Password: {{ mysql_root_password }}
      MySQL Database: {{ mysql_database }}
      MySQL User: {{ mysql_user }}
      MySQL Password: {{ mysql_password }}
      
      Connection Details:
      Host: {{ server_ip }}
      Port: {{ mysql_port }}
      
      Access Commands:
      docker compose exec -T database mysql -u root -p
      docker compose exec -T database mysql -u {{ mysql_user }} -p {{ mysql_database }}
    dest: "/home/{{ deploy_user }}/{{ app_name }}-{{ environment }}/database-credentials.txt"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0600'
EOF

# Create Ansible configuration summary
cat > "$ANSIBLE_DIR/ANSIBLE_CONFIG.md" << EOF
# Ansible Configuration for $APP_NAME

## Generated Configuration
- **Generated**: $(date)
- **App Name**: $APP_NAME
- **Deploy User**: $DEPLOY_USER
- **Server**: $SERVER_IP

## Structure Created
\`\`\`
ansible/
├── deploy.yml                      # Main playbook
├── tasks/                          # Shared tasks
│   ├── backup.yml
│   ├── cleanup.yml
│   ├── health_check.yml
│   ├── maintenance.yml
│   └── logging.yml
├── inventories/                    # Environment inventories
│   ├── test/
│   ├── preprod/
│   └── prod/
└── roles/                          # Ansible roles
    ├── wordpress/
    ├── nginx/
    └── mysql/
\`\`\`

## Environment Ports
- **Test**: $PORT_TEST (phpMyAdmin: $((PORT_TEST + 1)))
- **PreProd**: $PORT_PREPROD (phpMyAdmin: $((PORT_PREPROD + 1)))
- **Production**: $PORT_PROD (phpMyAdmin: $((PORT_PROD + 1)))

## Usage Examples
\`\`\`bash
# Deploy to test
ansible-playbook -i inventories/test/hosts deploy.yml --extra-vars "app_name=$APP_NAME environment=test"

# Deploy to production with backup
ansible-playbook -i inventories/prod/hosts deploy.yml --extra-vars "app_name=$APP_NAME environment=prod full_backup=true"

# Cleanup test environment
ansible-playbook -i inventories/test/hosts deploy.yml --extra-vars "cleanup_environment=true"
\`\`\`

## Pipeline Integration
This Ansible configuration works with the Azure DevOps pipeline generated by generate-pipeline.sh
EOF

print_success "✅ Complete Ansible configuration generated!"
print_success "✅ Configuration documented: $ANSIBLE_DIR/ANSIBLE_CONFIG.md"

echo ""
echo "📋 Generated Ansible Components:"
echo "  📜 Main playbook: ansible/deploy.yml"
echo "  📁 Task files: 5 task files in ansible/tasks/"
echo "  🏗️ Inventories: 3 environments with variables"
echo "  🎭 Roles: wordpress, nginx, mysql"
echo "  📄 Documentation: ansible/ANSIBLE_CONFIG.md"
echo ""
echo "🎯 Ready for deployment with:"
echo "  ansible-playbook -i inventories/test/hosts deploy.yml --extra-vars \"app_name=$APP_NAME environment=test\""
echo ""