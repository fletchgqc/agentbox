#!/bin/bash
# OpenCode Start Script

set -euo pipefail

# Welcome Message
echo "════════════════════════════════════════════════════════════════"
echo "🤖 OpenCode: $(opencode --version 2>/dev/null || echo 'not found - check installation')"
echo "════════════════════════════════════════════════════════════════"

# MCP Detection - OpenCode specific
if [ -f "/workspace/opencode.json" ]; then
    if grep -q '"mcp"' /workspace/opencode.json 2>/dev/null; then
        echo "🔌 MCP configuration detected in opencode.json"
    fi
fi

# MCP Detection - Generic files (backward compatibility)
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ]; then
    echo "🔌 MCP configuration detected"
fi

echo ""

# Start OpenCode
# OpenCode allows all operations by default (no permission flags needed)
exec opencode "$@"
