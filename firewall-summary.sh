#!/bin/bash

# AgentBox Firewall Summary
# Generates summary of blocked connections from kernel log

readonly LOG_FILE="/tmp/agentbox-firewall.log"

# Read kernel log and extract agentbox firewall blocks
# Using dmesg if available, otherwise try to read from mounted log
if command -v dmesg &>/dev/null; then
  blocked=$(dmesg 2>/dev/null | grep "\[agentbox-firewall\] BLOCK:" || echo "")
else
  blocked=$(cat "$LOG_FILE" 2>/dev/null | grep "\[agentbox-firewall\] BLOCK:" || echo "")
fi

# Count total blocks
count=$(echo "$blocked" | grep -c "BLOCK:" 2>/dev/null || echo "0")

if [[ "$count" -eq 0 ]]; then
  exit 0  # No blocks, no summary needed
fi

# Extract unique destination IP:port combinations
destinations=$(echo "$blocked" | grep -oE "DST=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*DPT=[0-9]+" | \
  sed -E 's/.*DST=([0-9.]+).*DPT=([0-9]+).*/\1:\2/' | \
  sort | uniq -c | sort -rn | head -5)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Firewall Summary: $count connection(s) blocked this session"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$destinations" ]]; then
  echo "Most frequently blocked destinations:"
  while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $2}')
    printf "  %3d × %s\n" "$count" "$dest"
  done <<< "$destinations"
fi

echo ""
echo "This is normal if software tried to reach services not in"
echo "~/.agentbox/firewall.conf (e.g., package mirrors, telemetry)."
echo ""
echo "To allow a service, add it to ~/.agentbox/firewall.conf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
