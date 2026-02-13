#!/bin/bash

# Webhook Setup Script for Docs Share
# This script helps you configure GitHub/GitLab webhook for auto-deployment

set -e

echo "📡 Docs Share - Webhook Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Get server URL
read -p "Enter your server URL (e.g., https://docs.example.com): " SERVER_URL

if [ -z "$SERVER_URL" ]; then
    echo "❌ Error: Server URL is required"
    exit 1
fi

WEBHOOK_URL="${SERVER_URL}/api/webhook"

echo ""
echo "✓ Webhook URL: $WEBHOOK_URL"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Configuration Steps:"
echo ""
echo "1. Add webhook to your Git hosting service:"
echo ""
echo "   GitHub:"
echo "   - Go to: Settings → Webhooks → Add webhook"
echo "   - Payload URL: $WEBHOOK_URL"
echo "   - Content type: application/json"
echo "   - Events: Just the push event"
echo ""
echo "   GitLab:"
echo "   - Go to: Settings → Webhooks"
echo "   - URL: $WEBHOOK_URL"
echo "   - Trigger: Push events"
echo ""
echo "2. On your server, set environment variable:"
echo ""
echo "   export ENABLE_WEBHOOK=true"
echo ""
echo "   Or in .env file:"
echo "   ENABLE_WEBHOOK=true"
echo ""
echo "3. Restart docs-share server"
echo ""
echo "4. Make sure your server has git configured:"
echo "   - SSH keys set up (for private repos)"
echo "   - Git user.name and user.email configured"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🧪 Test webhook:"
echo "   curl -X POST $WEBHOOK_URL"
echo ""
