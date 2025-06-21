#!/bin/bash

# SSH Connection Test Script
# This script helps troubleshoot SSH authentication issues

SERVER="192.99.35.79"
USER="liadwordpress"
SSH_PORT="2220"

echo "🔍 SSH Connection Troubleshooting for Azure DevOps Pipeline"
echo "============================================================"
echo ""

echo "📋 Testing SSH connection to: $USER@$SERVER:$SSH_PORT"
echo ""

# Test 1: Basic connectivity
echo "1️⃣ Testing basic connectivity..."
if ping -c 1 $SERVER > /dev/null 2>&1; then
    echo "✅ Server is reachable"
else
    echo "❌ Server is not reachable"
    exit 1
fi

# Test 2: SSH service
echo ""
echo "2️⃣ Testing SSH service..."
if nc -z $SERVER $SSH_PORT; then
    echo "✅ SSH service is running on port $SSH_PORT"
else
    echo "❌ SSH service is not accessible on port $SSH_PORT"
    exit 1
fi

# Test 3: SSH authentication methods
echo ""
echo "3️⃣ Checking available authentication methods..."
ssh -p $SSH_PORT -o PreferredAuthentications=none -o BatchMode=yes $USER@$SERVER 2>&1 | grep "Permission denied" | head -1

# Test 4: Manual SSH test
echo ""
echo "4️⃣ Manual SSH connection test"
echo "   Please test manually with:"
echo "   ssh -p $SSH_PORT $USER@$SERVER"
echo ""

# Generate SSH key for Azure DevOps
echo "5️⃣ Generate SSH key for Azure DevOps"
echo ""
read -p "Do you want to generate a new SSH key for Azure DevOps? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    KEY_NAME="azure_devops_key"
    
    if [ -f ~/.ssh/$KEY_NAME ]; then
        echo "⚠️  SSH key already exists: ~/.ssh/$KEY_NAME"
        read -p "Overwrite existing key? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping key generation..."
            exit 0
        fi
    fi
    
    echo "🔑 Generating SSH key pair..."
    ssh-keygen -t ed25519 -f ~/.ssh/$KEY_NAME -N "" -C "Azure DevOps - $(date)"
    
    echo ""
    echo "✅ SSH key generated successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Copy the public key to your server:"
    echo "   ssh-copy-id -i ~/.ssh/$KEY_NAME.pub -p $SSH_PORT $USER@$SERVER"
    echo ""
    echo "2. Test the SSH key:"
    echo "   ssh -i ~/.ssh/$KEY_NAME -p $SSH_PORT $USER@$SERVER"
    echo ""
    echo "3. Add the private key to Azure DevOps:"
    echo "   - Go to Project Settings → Service connections"
    echo "   - Create new SSH service connection"
    echo "   - Upload: ~/.ssh/$KEY_NAME"
    echo ""
    echo "4. Public key content (copy this to your server):"
    echo "----------------------------------------"
    cat ~/.ssh/$KEY_NAME.pub
    echo "----------------------------------------"
fi

echo ""
echo "🔧 Common SSH Issues and Solutions:"
echo ""
echo "❌ Permission denied (publickey):"
echo "   - SSH key is not installed on server"
echo "   - Wrong key path or permissions"
echo "   - Solution: Use ssh-copy-id or manual key installation"
echo ""
echo "❌ Permission denied (password):"
echo "   - Wrong password"
echo "   - Password authentication disabled"
echo "   - Wrong username"
echo "   - Solution: Check server SSH config and user credentials"
echo ""
echo "❌ Connection refused:"
echo "   - SSH service not running"
echo "   - Firewall blocking port $SSH_PORT"
echo "   - Wrong server IP"
echo "   - Solution: Check server status and network connectivity"
echo ""
echo "📚 For more help, see: SSH_AUTHENTICATION_SETUP.md"
