# haha WordPress Application

## 🚀 Quick Start

```bash
# Start the application
make start

# Setup WordPress
make setup

# View logs
make logs
```

## 🌐 Access Points

- **Frontend**: http://192.99.35.79:4000
- **Admin**: http://192.99.35.79:4000/wp-admin
- **phpMyAdmin**: http://192.99.35.79:4001

## 🔑 Credentials

See `CREDENTIALS.txt` file for all passwords.

## 🛠️ Management Commands

```bash
make start          # Start containers
make stop           # Stop containers  
make restart        # Restart containers
make logs           # View logs
make setup          # Initial WordPress setup
make status         # Show container status
make backup         # Create backup
make health-check   # Run health check
```

## 📁 File Structure

- `docker-compose.yml` - Docker configuration
- `.env` - Environment variables  
- `nginx.conf` - Nginx configuration
- `CREDENTIALS.txt` - Generated passwords
- `wp-content/` - WordPress content
- `scripts/` - Management scripts
- `ansible/` - Ansible deployment configuration

## 🔧 Generated Configuration

This app was generated using template-based scripts:
- `generate-env.sh` - Created .env file
- `generate-nginx.sh` - Created nginx.conf
- `generate-docker-compose.sh` - Created docker-compose.yml

Port assignments:
- WordPress: 4000
- phpMyAdmin: 4001
- MySQL: 4020

## 🚀 Deployment

Use the Ansible configuration in `ansible/` directory for automated deployment.
