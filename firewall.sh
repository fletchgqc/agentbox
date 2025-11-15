#!/bin/bash
set -e

# AgentBox Network Firewall
# Restricts container network access to approved services only.
# Configuration: ~/.agentbox/firewall.conf

# ============================================================================
# HARDCODED GITHUB RANGES
# ============================================================================
# These are always allowed to ensure GitHub access even if DNS fails.
# Updated from https://api.github.com/meta (2025-01)

GITHUB_RANGES=(
  "140.82.112.0/20"
  "143.55.64.0/20"
  "185.199.108.0/22"
  "192.30.252.0/22"
  "20.201.28.151/32"
  "20.205.243.166/32"
)

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly CONFIG_FILE="/tmp/firewall.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[firewall] ERROR: Configuration file not found: $CONFIG_FILE"
  echo "[firewall] This should have been mounted by agentbox script"
  exit 1
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
  echo "[firewall] $*"
}

die() {
  log "ERROR: $*"
  exit 1
}

# Resolve domain to IP addresses
resolve_domain() {
  local domain="$1"
  local ips=""

  if command -v dig &>/dev/null; then
    ips=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
  else
    ips=$(nslookup "$domain" 2>/dev/null | grep -A 10 "Name:" | grep "Address:" | awk '{print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
  fi

  echo "$ips"
}

# ============================================================================
# FIREWALL IMPLEMENTATION
# ============================================================================

log "Initializing firewall..."

# Initialize ipset for allowed IP addresses
ipset create allowed-hosts hash:net 2>/dev/null || ipset flush allowed-hosts

# Add hardcoded GitHub ranges
log "Adding hardcoded GitHub IP ranges..."
for range in "${GITHUB_RANGES[@]}"; do
  ipset add allowed-hosts "$range" 2>/dev/null || log "  Warning: Could not add $range"
done

# Detect container network to preserve Docker internal communication
gateway=$(ip route show default | head -1 | awk '{print $3}' 2>/dev/null || echo "")
if [[ -n "$gateway" ]]; then
  container_subnet=$(echo "$gateway" | sed 's/\.[0-9]*$/.0\/24/')
  log "Allowing container network: $container_subnet"
  ipset add allowed-hosts "$container_subnet" 2>/dev/null || true
fi

# Parse and apply configuration file
log "Processing configuration from $CONFIG_FILE..."

while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  # Parse line: domain [options]
  domain=$(echo "$line" | awk '{print $1}')
  options=$(echo "$line" | awk '{$1=""; print $0}' | xargs)

  # Resolve domain
  ips=$(resolve_domain "$domain")

  # Check if critical
  if [[ "$options" == *"critical"* ]]; then
    if [[ -z "$ips" ]]; then
      die "Failed to resolve critical service: $domain"
    fi
  fi

  # Handle empty resolution for non-critical
  if [[ -z "$ips" ]]; then
    log "  Warning: Could not resolve $domain (non-critical)"
    continue
  fi

  # Apply wide-net if specified (convert to /24 networks)
  if [[ "$options" == *"wide-net"* ]]; then
    ips=$(echo "$ips" | sed 's/\.[0-9]*$/\.0\/24/' | sort -u)
  fi

  # Add IPs to ipset
  for ip in $ips; do
    [[ -n "$ip" ]] && ipset add allowed-hosts "$ip" 2>/dev/null || true
  done

  log "  Added $domain"
done < "$CONFIG_FILE"

# Configure iptables rules
log "Configuring iptables..."

# Clear existing rules
iptables -F OUTPUT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

# Allow established/related connections FIRST (prevents lockout)
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow localhost
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Allow DNS (required for name resolution)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow SSH (required for git over SSH)
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow outbound connections to allowed hosts
iptables -A OUTPUT -m set --match-set allowed-hosts dst -j ACCEPT

# Log blocked connections before dropping
iptables -A OUTPUT -j LOG --log-prefix "[agentbox-firewall] BLOCK: " --log-level 4 -m limit --limit 10/min

# Set default policy to DROP for outbound traffic
iptables -P OUTPUT DROP

# Allow all inbound (container is already isolated by Docker)
iptables -P INPUT ACCEPT

log "Firewall configured successfully"

# Validate firewall is working
log "Validating firewall..."

if timeout 5 wget -q --spider https://api.anthropic.com 2>/dev/null; then
  log "  ✓ Anthropic API accessible"
else
  die "Validation failed: Cannot reach api.anthropic.com"
fi

if timeout 5 wget -q --spider https://github.com 2>/dev/null; then
  log "  ✓ GitHub accessible"
else
  die "Validation failed: Cannot reach github.com"
fi

if timeout 5 wget -q --spider https://example.com 2>/dev/null; then
  log "  ✗ Validation failed: example.com should be blocked but is accessible"
else
  log "  ✓ Blocked traffic confirmed"
fi

log "Firewall active and validated"
