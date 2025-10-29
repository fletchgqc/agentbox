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

# Ensure git config is set (for commits inside container)
if [ -z "$(git config --global user.email)" ]; then
    # Try to copy from mounted .gitconfig if available
    if [ -f "/home/claude/.gitconfig" ]; then
        git config --global user.email "$(git config --file /home/claude/.gitconfig user.email 2>/dev/null || echo 'claude@agentbox')"
        git config --global user.name "$(git config --file /home/claude/.gitconfig user.name 2>/dev/null || echo 'Claude (AgentBox)')"
    else
        git config --global user.email "claude@agentbox"
        git config --global user.name "Claude (AgentBox)"
    fi
fi

# Configure MCP servers from project-level .mcp.json if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/mcp_functions.sh" ]; then
    source "${SCRIPT_DIR}/mcp_functions.sh"
    configure_mcp_servers
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
    echo "📁 Workspace: /workspace"
    echo "🐍 Python: $(python3 --version 2>&1 | cut -d' ' -f2) (uv available)"
    echo "🟢 Node.js: $(node --version 2>/dev/null || echo 'not found')"
    echo "☕ Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo 'not found')"
    echo "🤖 Claude CLI: $(claude --version 2>/dev/null || echo 'not found - check installation')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Execute the command passed to docker run
exec "$@"
