# Makefile for haha
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
	docker compose exec database mysql -u root -p$(MYSQL_ROOT_PASSWORD)

backup: ## Create backup
	./scripts/backup-app.sh $(APP_NAME)

setup: ## Setup WordPress
	docker compose up -d
	sleep 15
	docker compose run --rm wpcli core download || true
	docker compose run --rm wpcli config create \
		--dbname=$(WORDPRESS_DB_NAME) \
		--dbuser=$(WORDPRESS_DB_USER) \
		--dbpass=$(WORDPRESS_DB_PASSWORD) \
		--dbhost=$(WORDPRESS_DB_HOST) \
		--force || true
	docker compose run --rm wpcli core install \
		--url=$(WP_URL) \
		--title="$(WP_TITLE)" \
		--admin_user=$(WP_ADMIN_USER) \
		--admin_password=$(WP_ADMIN_PASSWORD) \
		--admin_email=$(WP_ADMIN_EMAIL) || true

health-check: ## Run health check
	./scripts/health-check.sh haha "$(WP_URL)"

status: ## Show container status
	docker compose ps

help: ## Show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
