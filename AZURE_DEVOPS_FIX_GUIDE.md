# Azure DevOps Environment Setup Guide

## Issues Fixed in This Update

### 1. ❌ AnsiblePlaybook Task Missing
**Problem**: The pipeline was using `AnsiblePlaybook@0` task which isn't installed by default.

**Solution**: Replaced with standard `script` tasks that run `ansible-playbook` commands directly.

### 2. ❌ Missing Environments
**Problem**: Pipeline references environments that don't exist:
- `haha-test-env`
- `haha-preprod-env` 
- `haha-prod-env`

**Solutions Available**:

#### Option A: Use Simplified Pipeline (Recommended)
Use the new `azure-pipelines-simple.yml` file which removes environment dependencies.

#### Option B: Create Environments in Azure DevOps
Follow these steps to create the required environments:

1. **Navigate to Environments**:
   - Go to your Azure DevOps project
   - Click **Pipelines** → **Environments**

2. **Create Test Environment**:
   - Click **"New environment"**
   - Name: `haha-test-env`
   - Description: `WordPress Test Environment for haha app`
   - Resource: **None** (for now)
   - Click **Create**

3. **Create PreProd Environment**:
   - Click **"New environment"**
   - Name: `haha-preprod-env`
   - Description: `WordPress PreProduction Environment for haha app`
   - Resource: **None**
   - Click **Create**

4. **Create Production Environment**:
   - Click **"New environment"**
   - Name: `haha-prod-env`
   - Description: `WordPress Production Environment for haha app`
   - Resource: **None**
   - Add **Approvals and checks** for production safety
   - Click **Create**

## Quick Fix: Use the Simplified Pipeline

1. **Rename your current pipeline**:
   ```bash
   mv azure-pipelines.yml azure-pipelines-with-environments.yml
   ```

2. **Use the simplified version**:
   ```bash
   mv azure-pipelines-simple.yml azure-pipelines.yml
   ```

3. **Commit and push**:
   ```bash
   git add .
   git commit -m "Fix: Replace AnsiblePlaybook task with scripts and remove environment dependencies"
   git push
   ```

## Alternative: Install AnsiblePlaybook Extension

If you prefer to use the original pipeline with environments:

1. **Install the Ansible Extension**:
   - Go to Azure DevOps → **Organization Settings** → **Extensions**
   - Browse Marketplace for "Ansible"
   - Install the official Ansible extension

2. **Create the environments** (as described in Option B above)

3. **Set up approvals for Production**:
   - Go to `haha-prod-env` environment
   - Add **Approvals and checks**
   - Add required approvers

## Environment Benefits

Using environments provides:
- ✅ **Deployment tracking**: See deployment history per environment
- ✅ **Approval gates**: Require approval before production deployments
- ✅ **Resource monitoring**: Track deployment targets
- ✅ **Security controls**: Control who can deploy to which environment

## Current Pipeline Status

With the simplified pipeline (`azure-pipelines-simple.yml`):
- ✅ No missing task dependencies
- ✅ No missing environments
- ✅ Ansible deployments work via direct script calls
- ✅ Multi-stage deployment (Test → PreProd → Production)
- ✅ Health checks for all environments
- ✅ Backup and maintenance mode for production

## Next Steps

1. **Test the simplified pipeline** first to ensure it works
2. **If you need environments**, create them in Azure DevOps
3. **Switch back to the original pipeline** once environments are set up
4. **Add approval gates** for production deployments

## Troubleshooting

If you still get errors:

1. **Check SSH connectivity**:
   ```bash
   ssh -o StrictHostKeyChecking=no liadwordpress@192.99.35.79
   ```

2. **Verify Ansible inventory files exist**:
   - `apps/haha/ansible/inventories/test/hosts`
   - `apps/haha/ansible/inventories/preprod/hosts`
   - `apps/haha/ansible/inventories/prod/hosts`

3. **Check Ansible playbook**:
   - `apps/haha/ansible/deploy.yml`

4. **Test Ansible locally**:
   ```bash
   cd apps/haha
   ansible-playbook ansible/deploy.yml -i ansible/inventories/test/hosts --check
   ```
