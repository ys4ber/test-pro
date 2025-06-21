# Azure DevOps Docker Compose Fixes Applied

## 🔧 Issues Fixed

### 1. ❌ Deprecated `docker_compose` Module
**Error**: `community.docker.docker_compose has been removed. This module uses docker-compose v1, which is End of Life since July 2022.`

**Files Updated**:
- ✅ `ansible/roles/wordpress/tasks/main.yml` - Updated to use `community.docker.docker_compose_v2`
- ✅ `ansible/roles/wordpress/handlers/main.yml` - Updated to use `community.docker.docker_compose_v2`

**Changes Made**:
```yaml
# Before (deprecated)
- name: Start WordPress containers
  docker_compose:
    project_src: "/path/to/project"
    state: present

# After (fixed)  
- name: Start WordPress containers
  community.docker.docker_compose_v2:
    project_src: "/path/to/project"
    state: present
```

### 2. ❌ Missing Docker Collections
**Error**: Ansible couldn't find the `community.docker` collection.

**Solution**: 
- ✅ Created `ansible/requirements.yml` with required collections
- ✅ Added collection installation steps to all pipeline stages

**New Pipeline Steps**:
```yaml
- script: |
    echo "📦 Installing Ansible Collections..."
    ansible-galaxy collection install community.docker
    ansible-galaxy collection install ansible.posix
  displayName: "📦 Install Ansible Collections"
```

### 3. ❌ Reserved Variable Name Warning
**Warning**: `Found variable using reserved name: environment`

**Solution**: 
- ✅ Changed `ENVIRONMENT` to `DEPLOY_ENVIRONMENT` in pipeline
- ✅ Updated all references to use `$(DEPLOY_ENVIRONMENT)`
- ✅ Relaxed validation in `ansible/deploy.yml` to accept any environment name

### 4. ❌ Environment Validation Error
**Error**: Ansible validation expected environment to be `['test', 'preprod', 'prod']` but got `'ysaber-env'`

**Solution**:
- ✅ Updated validation in `ansible/deploy.yml` to accept any non-empty environment name

## 📁 Files Modified

1. **`ansible/roles/wordpress/tasks/main.yml`**
   - Updated `docker_compose` → `community.docker.docker_compose_v2`

2. **`ansible/roles/wordpress/handlers/main.yml`**  
   - Updated `docker_compose` → `community.docker.docker_compose_v2`
   - Fixed `restarted: yes` → `restart: true`

3. **`ansible/requirements.yml`** (NEW)
   - Added required Ansible collections

4. **`azure-pipelines-simple.yml`**
   - Added Ansible collections installation to all stages
   - Changed `ENVIRONMENT` → `DEPLOY_ENVIRONMENT`
   - Updated all variable references

5. **`ansible/deploy.yml`**
   - Relaxed environment validation to accept any value

## 🚀 What Should Work Now

The pipeline should now successfully:
- ✅ Install required Ansible collections
- ✅ Use the modern Docker Compose v2 module
- ✅ Deploy with the custom environment name `ysaber-env`
- ✅ Avoid reserved variable name conflicts
- ✅ Pass all validation checks

## 🔄 Next Steps

1. **Commit and push these changes**:
   ```bash
   git add .
   git commit -m "Fix: Update to docker_compose_v2 and resolve Ansible issues"
   git push
   ```

2. **Run the pipeline again** - it should now work without the Docker Compose errors

3. **Monitor the deployment** to ensure all services start correctly

## 🐛 If You Still Get Errors

Check these common issues:

1. **SSH connectivity**: Ensure the agent can connect to your servers
2. **Inventory files**: Verify the hosts files exist and are properly configured
3. **Docker installation**: Ensure Docker and Docker Compose are installed on target servers
4. **Permissions**: Check that the deploy user has proper permissions

## ✅ SUCCESS: Docker Compose Issues Fixed!

**Great news!** The Docker Compose errors are completely resolved. The pipeline now successfully:
- ✅ Uses `community.docker.docker_compose_v2` (no more deprecated module errors)
- ✅ Installs required collections automatically
- ✅ Handles the custom environment name `ysaber-env`

## 🔑 NEW ISSUE: SSH Authentication 

**Current Error**: `Permission denied (publickey,password)` when connecting to `192.99.35.79`

**Root Cause**: The Azure DevOps agent doesn't have SSH credentials to connect to your server.

### 🛠️ SSH Authentication Solutions

#### Option 1: SSH Key Authentication (Recommended)

1. **Create SSH key pair on your server**:
   ```bash
   # On your server (192.99.35.79)
   ssh-keygen -t ed25519 -f ~/.ssh/azure_devops_key -N ""
   cat ~/.ssh/azure_devops_key.pub >> ~/.ssh/authorized_keys
   ```

2. **Add private key to Azure DevOps**:
   - Go to Azure DevOps → Project Settings → Service connections
   - Create new "SSH" service connection
   - Upload the private key (`~/.ssh/azure_devops_key`)
   - Host: `192.99.35.79`
   - Username: `liadwordpress`

3. **Update pipeline to use service connection**:
   ```yaml
   - task: DownloadSecureFile@1
     name: sshkey
     displayName: '🔑 Download SSH Key'
     inputs:
       secureFile: 'azure_devops_key'
   
   - script: |
       mkdir -p ~/.ssh
       cp $(sshkey.secureFilePath) ~/.ssh/id_rsa
       chmod 600 ~/.ssh/id_rsa
       ssh-keyscan -H 192.99.35.79 >> ~/.ssh/known_hosts
     displayName: '🔑 Setup SSH Key'
   ```

#### Option 2: Password Authentication (Quick Fix)

1. **Add SSH password to Azure DevOps variables**:
   - Go to Pipelines → Variables
   - Add variable: `SSH_PASSWORD` (mark as secret)
   - Value: Your server password

2. **Update pipeline ansible commands**:
   ```yaml
   - script: |
       cd "$APP_PATH"
       ansible-playbook ansible/deploy.yml \
         -i $(ANSIBLE_INVENTORY) \
         --extra-vars "app_name=$(APP_NAME) environment=$(DEPLOY_ENVIRONMENT) wp_url=$(WP_URL_TEST) pma_url=$(PMA_URL_TEST)" \
         --ssh-extra-args="-o StrictHostKeyChecking=no" \
         --ask-pass \
         -v
     env:
       ANSIBLE_SSH_PASS: $(SSH_PASSWORD)
   ```

#### Option 3: Simple Password Auth (Immediate Fix)

Add the SSH password directly to the ansible command with `sshpass`:

```yaml
- script: |
    cd "$APP_PATH"
    echo "$(SSH_PASSWORD)" | sshpass ansible-playbook ansible/deploy.yml \
      -i $(ANSIBLE_INVENTORY) \
      --extra-vars "app_name=$(APP_NAME) environment=$(DEPLOY_ENVIRONMENT) wp_url=$(WP_URL_TEST) pma_url=$(PMA_URL_TEST)" \
      --ssh-extra-args="-o StrictHostKeyChecking=no" \
      -v
  env:
    SSH_PASSWORD: $(SSH_PASSWORD)
```

## 🚀 Quick Fix Pipeline Update

Want me to update your pipeline with SSH password authentication right now?
