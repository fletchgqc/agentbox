# AgentBox Firewall - Implementation Summary

## Overview

The firewall is now **enabled by default** with **user-configurable** allowed hosts that don't require editing AgentBox repository files or rebuilding the image.

## Key Features

### 1. Enabled by Default
```bash
# Firewall is on by default
./agentbox

# To disable:
AGENTBOX_FIREWALL=disabled agentbox
```

### 2. User Configuration File: `~/.agentbox/firewall.conf`

**Location**: `~/.agentbox/firewall.conf`

**Creation**: Automatically created on first run from `firewall.conf.default`

**Format**:
```
# domain [options]
github.com critical
api.anthropic.com critical
registry.npmjs.org
repo.maven.apache.org wide-net
my-custom-api.example.com
```

**Options**:
- `critical` - Container fails to start if DNS resolution fails
- `wide-net` - Allows entire /24 subnet for services with frequently changing IPs

### 3. Easy Customization

**Add a service**:
```bash
echo "my-api.example.com" >> ~/.agentbox/firewall.conf
```

**Add a critical service**:
```bash
echo "my-auth-server.com critical" >> ~/.agentbox/firewall.conf
```

**Add a service with changing IPs**:
```bash
echo "my-cdn.example.com wide-net" >> ~/.agentbox/firewall.conf
```

**Apply changes**:
```bash
# Just restart container - no rebuild needed!
./agentbox
```

## Implementation Details

### File Structure

```
agentbox/
├── firewall.conf.default    # Default template (copied to ~/.agentbox/)
├── firewall.sh              # Firewall initialization script (in container)
├── agentbox                 # Creates config, mounts it to container
├── entrypoint.sh            # Calls firewall.sh if enabled
└── Dockerfile               # Copies firewall.sh to /usr/local/bin/
```

### How It Works

1. **agentbox script**:
   - Checks if `~/.agentbox/firewall.conf` exists
   - If not, copies `firewall.conf.default` to `~/.agentbox/firewall.conf`
   - Mounts config to `/tmp/firewall.conf` inside container (read-only)
   - Adds `NET_ADMIN` and `NET_RAW` capabilities if firewall enabled

2. **entrypoint.sh**:
   - Calls `/usr/local/bin/firewall.sh` if `AGENTBOX_FIREWALL != disabled`
   - Shows firewall status in welcome message

3. **firewall.sh**:
   - Reads `/tmp/firewall.conf` (mounted from host)
   - Applies hardcoded GitHub IP ranges
   - Resolves domains from config file
   - Applies `critical` and `wide-net` options
   - Configures iptables rules
   - Validates connectivity to critical services

### Environment Variable

**Format**: `AGENTBOX_FIREWALL=enabled|disabled`

**Default**: `enabled` (if not set)

**Examples**:
```bash
# Explicitly enable (unnecessary, it's default)
AGENTBOX_FIREWALL=enabled agentbox

# Disable
AGENTBOX_FIREWALL=disabled agentbox

# Disable by default (add to shell profile)
export AGENTBOX_FIREWALL=disabled
```

### Configuration Parsing

The firewall script parses each line:

```bash
# Skip comments and empty lines
[[ "$line" =~ ^[[:space:]]*# ]] && continue

# Parse: domain [options]
domain=$(echo "$line" | awk '{print $1}')
options=$(echo "$line" | awk '{$1=""; print $0}' | xargs)

# Check if critical
if [[ "$options" == *"critical"* ]] && [[ -z "$ips" ]]; then
  die "Failed to resolve critical service: $domain"
fi

# Apply wide-net (convert to /24)
if [[ "$options" == *"wide-net"* ]]; then
  ips=$(echo "$ips" | sed 's/\.[0-9]*$/\.0\/24/')
fi
```

## User Experience

### First Run

```bash
$ ./agentbox
ℹ️  Created default firewall configuration: /home/user/.agentbox/firewall.conf
ℹ️  Edit this file to customize network access
ℹ️  To disable firewall: AGENTBOX_FIREWALL=disabled agentbox
ℹ️  Network firewall enabled (config: ~/.agentbox/firewall.conf)
[firewall] Initializing firewall...
[firewall] Adding hardcoded GitHub IP ranges...
[firewall] Processing configuration from /tmp/firewall.conf...
[firewall]   Added github.com
[firewall]   Added api.github.com
[firewall]   Added api.anthropic.com
[firewall]   Added registry.npmjs.org
[firewall]   Added repo.maven.apache.org
[firewall]   Added repo1.maven.org
[firewall]   Added plugins.gradle.org
[firewall] Configuring iptables...
[firewall] Firewall configured successfully
[firewall] Validating firewall...
[firewall]   ✓ Anthropic API accessible
[firewall]   ✓ GitHub accessible
[firewall]   ✓ Blocked traffic confirmed
[firewall] Firewall active and validated

🤖 AgentBox Development Environment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Workspace: /workspace
🐍 Python: 3.12.0 (uv available)
🟢 Node.js: v20.10.0
☕ Java: 21.0.8
🤖 Claude CLI: 0.1.0
🔒 Network: Restricted (firewall active)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Adding Custom Service

```bash
$ echo "httpbin.org" >> ~/.agentbox/firewall.conf
$ ./agentbox shell

# Inside container:
$ curl https://httpbin.org/get  # Works!
$ curl https://example.com       # Blocked
```

### Disabling Firewall

```bash
$ AGENTBOX_FIREWALL=disabled ./agentbox shell
⚠️  Network firewall disabled - container has unrestricted network access

# Inside container:
$ curl https://example.com  # Works - firewall is off
```

## Default Configuration

The default `firewall.conf.default` includes:

**Critical Services**:
- github.com
- api.github.com
- api.anthropic.com

**Package Registries**:
- registry.npmjs.org
- repo.maven.apache.org (wide-net)
- repo1.maven.org (wide-net)
- plugins.gradle.org

**Always Allowed** (hardcoded):
- GitHub IP ranges (from api.github.com/meta, 2025-01)
- Container's own /24 subnet

## Benefits of This Approach

1. ✅ **No editing AgentBox repo files** - config is in `~/.agentbox/`
2. ✅ **No rebuild required** - just restart container
3. ✅ **Enabled by default** - security out of the box
4. ✅ **Easy to disable** - single environment variable
5. ✅ **Handles different IP behaviors** - `wide-net` option for Maven, etc.
6. ✅ **Simple format** - easy to understand and edit
7. ✅ **Safe defaults** - critical services marked appropriately
8. ✅ **Automatic setup** - creates config on first run
9. ✅ **Clear syntax** - `enabled/disabled` instead of `1/0`

## Migration from Previous Version

If anyone was using the opt-in version:
- `AGENTBOX_FIREWALL=1` still works (but unnecessary now)
- Config will be created automatically
- No breaking changes

## Testing

See `FIREWALL_TEST_PLAN.md` for comprehensive testing procedures.

Quick test:
```bash
# Test firewall is working
./agentbox shell
curl https://api.anthropic.com  # Should work
curl --max-time 5 https://example.com  # Should fail/timeout

# Test custom service
echo "httpbin.org" >> ~/.agentbox/firewall.conf
exit
./agentbox shell
curl https://httpbin.org/get  # Should work now
```

## Future Enhancements (Not Implemented)

- Per-project firewall config (wait for user feedback)
- IPv6 support
- Caching DNS responses between container restarts
- Firewall logs/statistics
