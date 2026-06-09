#!/bin/bash

set -e

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
fi

if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

if [ -n "$PROJECT_DIR" ] && [ ! -d "$PROJECT_DIR/.venv" ] && [ -f "$PROJECT_DIR/requirements.txt" -o -f "$PROJECT_DIR/pyproject.toml" -o -f "$PROJECT_DIR/setup.py" ]; then
    echo "🐍 Python project detected, creating virtual environment..."
    cd "$PROJECT_DIR"
    uv venv .venv
    echo "✅ Virtual environment created at .venv/"
    echo "   Activate with: source .venv/bin/activate"
fi

if [ -d "/home/agent/.ssh" ]; then
    chmod 700 /home/agent/.ssh 2>/dev/null || true
    chmod 600 /home/agent/.ssh/* 2>/dev/null || true
    chmod 644 /home/agent/.ssh/*.pub 2>/dev/null || true
    chmod 644 /home/agent/.ssh/authorized_keys 2>/dev/null || true
    chmod 644 /home/agent/.ssh/known_hosts 2>/dev/null || true
    echo "✅ SSH directory permissions configured"
fi

if [ -d "/tmp/host_direnv_allow" ]; then
    mkdir -p /home/agent/.local/share/direnv/allow
    cp /tmp/host_direnv_allow/* /home/agent/.local/share/direnv/allow/ 2>/dev/null && \
        echo "✅ Direnv approvals copied from host"
fi

if [ -f "/tmp/host_gitconfig" ]; then
    cp /tmp/host_gitconfig /home/agent/.gitconfig
else
    cat > /home/agent/.gitconfig << 'EOF'
[user]
    email = agent@agentbox
    name = AI Agent (AgentBox)
[init]
    defaultBranch = main
EOF
    echo "ℹ️  Using default git identity (agent@agentbox). Configure ~/.gitconfig on host to customize."
fi

if [ -n "$PROJECT_DIR" ] && { [ -f "$PROJECT_DIR/.mcp.json" ] || [ -f "$PROJECT_DIR/mcp.json" ]; }; then
    echo "🔌 MCP configuration detected. To enable MCP servers, see AgentBox documentation."
fi

export TERM=xterm-256color

# Handle terminal size
if [ -t 0 ]; then
    eval $(resize 2>/dev/null || true)
fi

if [ -t 0 ] && [ -t 1 ]; then
    echo "🤖 AgentBox Development Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Project Directory: ${PROJECT_DIR:-unknown}"
    echo "🐍 Python: $(python3 --version 2>&1 | cut -d' ' -f2) (uv available)"
    echo "🟢 Node.js: $(node --version 2>/dev/null || echo 'not found')"
    echo "☕ Java: $(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo 'not found')"
    if [ "$TOOL" = "opencode" ]; then
        echo "🤖 OpenCode: $(opencode --version 2>/dev/null || echo 'not found - check installation')"
    elif [ "$TOOL" = "pi" ]; then
        echo "🤖 Pi: $(pi --version 2>/dev/null || echo 'not found - check installation')"
    else
        echo "🤖 Claude CLI: $(claude --version 2>/dev/null || echo 'not found - check installation')"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

exec "$@"
