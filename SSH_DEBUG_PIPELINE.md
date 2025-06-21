# Quick SSH Debug Pipeline Steps

Add these debugging steps to your pipeline to help troubleshoot SSH issues:

## Add Before Ansible Deployment

```yaml
- script: |
    echo "🔍 SSH Connection Debugging..."
    echo "Target server: $(SERVER_IP)"
    echo "Deploy user: $(DEPLOY_USER)"
    
    # Test basic connectivity
    echo "Testing connectivity..."
    ping -c 3 $(SERVER_IP) || echo "❌ Ping failed"
    
    # Test SSH port
    echo "Testing SSH port..."
    nc -z $(SERVER_IP) 22 && echo "✅ SSH port accessible" || echo "❌ SSH port not accessible"
    
    # Check SSH password variable
    if [ -z "$(SSH_PASSWORD)" ]; then
        echo "❌ SSH_PASSWORD variable is not set!"
        echo "Please add SSH_PASSWORD variable in Azure DevOps pipeline settings"
        exit 1
    else
        echo "✅ SSH_PASSWORD variable is set"
    fi
    
    # Test SSH authentication methods
    echo "Available authentication methods:"
    ssh -o BatchMode=yes -o ConnectTimeout=10 $(DEPLOY_USER)@$(SERVER_IP) 2>&1 | grep "Permission denied" || true
    
  displayName: "🔍 SSH Connection Debug"
```

## Enhanced Ansible Command with Better Error Handling

```yaml
- script: |
    echo "🔧 Deploying with Ansible to Test Environment..."
    APP_PATH="$(Build.SourcesDirectory)/apps/$(APP_NAME)"
    
    cd "$APP_PATH"
    
    # Set Ansible environment variables
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_SSH_TIMEOUT=30
    export ANSIBLE_TIMEOUT=30
    
    # Run ansible with verbose output
    echo "Running Ansible playbook..."
    ansible-playbook ansible/deploy.yml \
      -i $(ANSIBLE_INVENTORY) \
      --extra-vars "app_name=$(APP_NAME) environment=$(DEPLOY_ENVIRONMENT) wp_url=$(WP_URL_TEST) pma_url=$(PMA_URL_TEST) ssh_password='$(SSH_PASSWORD)'" \
      --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10" \
      -vvv
      
    ANSIBLE_EXIT_CODE=$?
    
    if [ $ANSIBLE_EXIT_CODE -eq 0 ]; then
        echo "✅ Ansible deployment successful"
    else
        echo "❌ Ansible deployment failed with exit code: $ANSIBLE_EXIT_CODE"
        echo ""
        echo "🔧 Common solutions:"
        echo "1. Check SSH_PASSWORD variable is correct"
        echo "2. Verify server allows password authentication"
        echo "3. Test manual SSH: ssh $(DEPLOY_USER)@$(SERVER_IP)"
        echo "4. Check server SSH config: sudo grep PasswordAuthentication /etc/ssh/sshd_config"
        exit $ANSIBLE_EXIT_CODE
    fi
    
  displayName: "🔧 Deploy with Ansible to Test (Enhanced)"
```

## Alternative: SSH Key Setup

If password continues to fail, here's a pipeline step to use SSH keys:

```yaml
- task: DownloadSecureFile@1
  name: sshkey
  displayName: '🔑 Download SSH Private Key'
  inputs:
    secureFile: 'azure_devops_key'  # Upload your private key as secure file

- script: |
    echo "🔑 Setting up SSH key authentication..."
    
    # Setup SSH directory and key
    mkdir -p ~/.ssh
    cp $(sshkey.secureFilePath) ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    chmod 700 ~/.ssh
    
    # Add server to known hosts
    ssh-keyscan -H $(SERVER_IP) >> ~/.ssh/known_hosts
    
    # Test SSH key
    ssh -i ~/.ssh/id_rsa -o ConnectTimeout=10 $(DEPLOY_USER)@$(SERVER_IP) "echo 'SSH key authentication successful'"
    
  displayName: "🔑 Setup SSH Key Authentication"
```

## Password Authentication Server Setup

If you need to enable password authentication on your server:

```bash
# On your server (192.99.35.79)
sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl reload ssh

# Verify the setting
grep PasswordAuthentication /etc/ssh/sshd_config
```

## Quick Test Commands

Test these manually first:

```bash
# Test basic SSH
ssh liadwordpress@192.99.35.79

# Test with specific authentication
ssh -o PreferredAuthentications=password liadwordpress@192.99.35.79

# Test connectivity
ping 192.99.35.79
nc -z 192.99.35.79 22
```
