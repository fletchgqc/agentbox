#!/bin/bash
# AgentBox entrypoint script - minimal initialization

set -e

# Ensure proper PATH
export PATH="$HOME/.local/bin:$PATH"

# Source NVM if available
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
fi

# Source SDKMAN if available
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Create Python virtual environment if it doesn't exist in the project
if [ ! -d "/workspace/.venv" ] && [ -f "/workspace/requirements.txt" -o -f "/workspace/pyproject.toml" -o -f "/workspace/setup.py" ]; then
    echo "🐍 Python project detected, creating virtual environment..."
    cd /workspace
    uv venv .venv
    echo "✅ Virtual environment created at .venv/"
    echo "   Activate with: source .venv/bin/activate"
fi

# Set proper permissions on mounted SSH directory if it exists
if [ -d "/home/claude/.ssh" ]; then
    # Ensure correct permissions for SSH directory and files
    chmod 700 /home/claude/.ssh 2>/dev/null || true
    chmod 600 /home/claude/.ssh/* 2>/dev/null || true
    chmod 644 /home/claude/.ssh/*.pub 2>/dev/null || true
    chmod 644 /home/claude/.ssh/authorized_keys 2>/dev/null || true
    chmod 644 /home/claude/.ssh/known_hosts 2>/dev/null || true
    echo "✅ SSH directory permissions configured"
fi

# Translate host direnv approvals to container paths
if [ -d "/tmp/host_direnv_allow" ] && [ -f "/workspace/.envrc" ] && [ -n "$HOST_PROJECT_DIR" ]; then
    mkdir -p /home/claude/.local/share/direnv/allow

    # The host .envrc path
    host_envrc_path="$HOST_PROJECT_DIR/.envrc"

    # Calculate the expected hash for the host path + current .envrc content
    # This is how direnv validates approvals
    expected_host_hash=$(printf "%s\n" "$host_envrc_path" | cat - /workspace/.envrc | sha256sum | cut -d' ' -f1)

    # If a valid approval exists for the current .envrc content, create a corresponding approval int the container
    if [ -f "/tmp/host_direnv_allow/$expected_host_hash" ]; then
        approved_path=$(cat "/tmp/host_direnv_allow/$expected_host_hash")
        if [ "$approved_path" = "$host_envrc_path" ]; then
            container_hash=$(printf "/workspace/.envrc\n" | cat - /workspace/.envrc | sha256sum | cut -d' ' -f1)
            echo "/workspace/.envrc" > /home/claude/.local/share/direnv/allow/"$container_hash"
            echo "✅ Translated direnv approval from host to container"
        fi
    fi
fi

# Set up git config for commits inside container
if [ -f "/tmp/host_gitconfig" ]; then
    cp /tmp/host_gitconfig /home/claude/.gitconfig
else
    cat > /home/claude/.gitconfig << 'EOF'
[user]
    email = claude@agentbox
    name = Claude (AgentBox)
[init]
    defaultBranch = main
EOF
    echo "ℹ️  Using default git identity (claude@agentbox). Configure ~/.gitconfig on host to customize."
fi

# Check if project has MCP servers and show reminder
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ]; then
    echo "🔌 MCP configuration detected. To enable MCP servers, see AgentBox documentation."
fi

# Set terminal for better experience
export TERM=xterm-256color

# Handle terminal size
if [ -t 0 ]; then
    # Update terminal size
    eval $(resize 2>/dev/null || true)
fi

# If running interactively, show welcome message
if [ -t 0 ] && [ -t 1 ]; then
    echo "🤖 AgentBox Development Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Project Directory: /workspace"
    echo "🐍 Python: $(python3 --version 2>&1 | cut -d' ' -f2) (uv available)"
    echo "🟢 Node.js: $(node --version 2>/dev/null || echo 'not found')"
    echo "☕ Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo 'not found')"
    echo "🤖 Claude CLI: $(claude --version 2>/dev/null || echo 'not found - check installation')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Execute the command passed to docker run
exec "$@"
