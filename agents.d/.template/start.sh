#!/bin/bash
# Agent Start Script
#
# Zweck: Agent starten (inkl. Welcome Message + MCP Detection)
# Aufgerufen: Von entrypoint.sh als letzter Schritt
# Input: $@ = User-Argumente (z.B. "chat", "--help")
# Output: Startet den Agent (sollte mit 'exec' enden)
#
# WICHTIG: Diese Datei muss executable sein!
#   chmod +x agents.d/your-agent/start.sh
#
# Dieses Script sollte enthalten:
#   1. Welcome Message anzeigen
#   2. MCP Configuration Detection (optional)
#   3. Agent starten (exec)

set -euo pipefail

# 1. Welcome Message
echo "════════════════════════════════════════════════════════════════"
echo "🤖 Your Agent: $(your-agent --version 2>/dev/null || echo 'not found')"
echo "════════════════════════════════════════════════════════════════"

# 2. MCP Detection (optional, anpassen für deinen Agent)
if [ -f "/workspace/your-agent.json" ] && grep -q '"mcp"' /workspace/your-agent.json 2>/dev/null; then
    echo "🔌 MCP configuration detected"
fi

echo ""

# 3. Start Agent
exec your-agent "$@"
