#!/bin/sh

# Fix SSH permissions for Docker volume mounts
# Host's .ssh is mounted read-only, but SSH requires strict ownership/permissions
if [ -d /root/.ssh ]; then
    mkdir -p /tmp/ssh
    cp /root/.ssh/* /tmp/ssh/ 2>/dev/null
    chown -R root:root /tmp/ssh
    chmod 700 /tmp/ssh
    chmod 600 /tmp/ssh/* 2>/dev/null
    chmod 644 /tmp/ssh/*.pub 2>/dev/null

    # Fix IdentityFile paths in config (host path → container path)
    if [ -f /tmp/ssh/config ]; then
        sed -i 's|IdentityFile .*/.ssh/|IdentityFile /tmp/ssh/|g' /tmp/ssh/config
    fi

    # Update GIT_SSH_COMMAND to use fixed paths and config
    if [ -n "$GIT_SSH_COMMAND" ]; then
        GIT_SSH_COMMAND=$(echo "$GIT_SSH_COMMAND" | sed 's|/root/.ssh|/tmp/ssh|g')
        # Use fixed config to resolve Host aliases
        if [ -f /tmp/ssh/config ]; then
            GIT_SSH_COMMAND="$GIT_SSH_COMMAND -F /tmp/ssh/config"
        fi
        export GIT_SSH_COMMAND
    fi
fi

exec node server.mjs
