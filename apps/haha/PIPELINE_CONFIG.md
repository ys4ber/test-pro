# Azure DevOps Pipeline Configuration for haha

## Pipeline Details
- **Name**: haha-Deploy-Ansible-v2
- **Template**: azure-pipelines.template.yml
- **Generated**: Fri Jun 20 06:03:04 PM EDT 2025

## Environment Configuration

### Test Environment
- **WordPress URL**: http://192.99.35.79:4000
- **phpMyAdmin URL**: http://192.99.35.79:4001
- **Inventory**: ansible/inventories/test/hosts
- **Environment**: haha-test-env

### PreProd Environment  
- **WordPress URL**: http://192.99.35.79:4100
- **phpMyAdmin URL**: http://192.99.35.79:4101
- **Inventory**: ansible/inventories/preprod/hosts
- **Environment**: haha-preprod-env

### Production Environment
- **WordPress URL**: http://192.99.35.79:4200
- **phpMyAdmin URL**: http://192.99.35.79:4201
- **Inventory**: ansible/inventories/prod/hosts
- **Environment**: haha-prod-env

## Deployment Flow
1. **Test Stage**: Deploy and validate in test environment
2. **PreProd Stage**: Deploy to preprod for final validation
3. **Production Stage**: Deploy to production (master branch only)
4. **Cleanup Stage**: Clean test and preprod environments

## Required Azure DevOps Setup

### Service Connections
Create SSH service connections for each environment:
- **Test**: SSH connection to liadwordpress@192.99.35.79
- **PreProd**: SSH connection to liadwordpress@192.99.35.79  
- **Production**: SSH connection to liadwordpress@192.99.35.79

### Environments
Create the following environments in Azure DevOps:
- `haha-test-env`
- `haha-preprod-env`
- `haha-prod-env`

### Variables
The pipeline uses these variables:
- APP_NAME: 'haha'
- DEPLOY_USER: 'liadwordpress'
- SERVER_IP: '192.99.35.79'

## Ansible Integration
The pipeline uses Ansible playbooks located in:
- `ansible/deploy.yml` - Main deployment playbook
- `ansible/inventories/test/hosts` - Test inventory
- `ansible/inventories/preprod/hosts` - PreProd inventory
- `ansible/inventories/prod/hosts` - Production inventory

## Trigger Configuration
- **Branch Triggers**: master, main, development
- **Path Triggers**: apps/haha/**/*
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
