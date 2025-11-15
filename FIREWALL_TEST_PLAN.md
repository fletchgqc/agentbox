# Firewall Test Plan

This document outlines how to test the firewall implementation.

## Prerequisites

- Docker installed and running
- AgentBox built successfully (`./agentbox --rebuild`)

## Test 1: Basic Functionality Without Firewall

Verify AgentBox works normally without firewall enabled:

```bash
# Should work normally
./agentbox shell

# Inside container, verify normal network access
curl https://example.com  # Should succeed
exit
```

## Test 2: Enable Firewall

Enable firewall and verify it initializes:

```bash
# Enable firewall
AGENTBOX_FIREWALL=1 ./agentbox shell

# You should see firewall initialization messages:
# [firewall] Initializing firewall...
# [firewall] Adding GitHub IP ranges...
# [firewall] Resolving allowed services...
# [firewall] Firewall configured successfully
# [firewall] Validating firewall...
# [firewall] ✓ Anthropic API accessible
# [firewall] ✓ GitHub accessible
# [firewall] ✓ Blocked traffic confirmed
# [firewall] Firewall active and validated
#
# Welcome message should show:
# 🔒 Network: Restricted (firewall active)
```

## Test 3: Verify Allowed Services Work

Inside the firewalled container, test that allowed services are accessible:

```bash
AGENTBOX_FIREWALL=1 ./agentbox shell

# Test GitHub
curl -I https://github.com  # Should succeed
curl -I https://api.github.com  # Should succeed

# Test npm registry
curl -I https://registry.npmjs.org  # Should succeed

# Test Maven repos
curl -I https://repo.maven.apache.org  # Should succeed
curl -I https://repo1.maven.org  # Should succeed

# Test Anthropic API
curl -I https://api.anthropic.com  # Should succeed

# Test Gradle plugins
curl -I https://plugins.gradle.org  # Should succeed
```

## Test 4: Verify Blocked Services Fail

Inside the firewalled container, verify that non-allowed services are blocked:

```bash
AGENTBOX_FIREWALL=1 ./agentbox shell

# These should all timeout/fail
curl --max-time 5 https://example.com  # Should fail
curl --max-time 5 https://google.com  # Should fail
curl --max-time 5 https://reddit.com  # Should fail
curl --max-time 5 https://twitter.com  # Should fail

# Should see error like:
# curl: (28) Connection timeout after 5001 ms
# or
# curl: (7) Failed to connect
```

## Test 5: Verify DNS Still Works

DNS lookups should work even with firewall enabled:

```bash
AGENTBOX_FIREWALL=1 ./agentbox shell

# DNS should work
nslookup github.com  # Should succeed
nslookup example.com  # Should succeed (DNS != HTTP access)
dig google.com  # Should succeed
```

## Test 6: Verify SSH Works

Git operations over SSH should work:

```bash
# First initialize SSH
./agentbox ssh-init

# Add the generated key to GitHub

# Test SSH git operations with firewall
AGENTBOX_FIREWALL=1 ./agentbox shell

# Inside container
ssh -T git@github.com  # Should authenticate successfully
```

## Test 7: Verify Claude CLI Works

The main use case - Claude should work normally:

```bash
AGENTBOX_FIREWALL=1 ./agentbox

# Claude should start normally and be able to:
# - Access Anthropic API
# - Clone/read GitHub repos if needed
# - Install packages from npm/pip/maven
```

## Test 8: Add Custom Service

Test that adding a custom service works:

1. Edit `firewall.sh` and add a service to `ALLOWED_SERVICES`:
   ```bash
   ALLOWED_SERVICES=(
     ...
     "httpbin.org"  # Add for testing
   )
   ```

2. Rebuild:
   ```bash
   ./agentbox --rebuild
   ```

3. Test:
   ```bash
   AGENTBOX_FIREWALL=1 ./agentbox shell
   curl https://httpbin.org/get  # Should now succeed
   ```

## Test 9: Critical Service Failure

Verify that firewall fails if critical service can't be resolved:

1. Edit `firewall.sh` and add a non-existent domain to `CRITICAL_SERVICES`:
   ```bash
   CRITICAL_SERVICES=(
     ...
     "this-domain-does-not-exist-12345.com"
   )
   ```

2. Try to start:
   ```bash
   AGENTBOX_FIREWALL=1 ./agentbox shell
   # Should fail with:
   # [firewall] ERROR: Failed to resolve critical service: this-domain-does-not-exist-12345.com
   ```

3. Revert the change and rebuild.

## Test 10: Verify ipset and iptables Rules

Inspect the actual firewall rules:

```bash
AGENTBOX_FIREWALL=1 ./agentbox shell --admin

# Inside container, view ipset
sudo ipset list allowed-hosts

# Should show all allowed IPs/ranges including:
# - GitHub ranges (140.82.112.0/20, etc.)
# - Resolved IPs for npm, maven, etc.
# - Container subnet

# View iptables rules
sudo iptables -L -n -v

# Should show:
# - OUTPUT policy DROP
# - Rules allowing established connections
# - Rules allowing DNS, SSH
# - Rules allowing traffic to ipset
```

## Expected Issues and Resolutions

### Issue: "Cannot initialize ipset"
**Cause**: Missing NET_ADMIN capability
**Fix**: Ensure `AGENTBOX_FIREWALL=1` is set (adds required capabilities)

### Issue: "Failed to resolve critical service"
**Cause**: DNS resolution failed for a critical service
**Fix**: Check internet connectivity, verify service domain is correct

### Issue: "Validation failed: Cannot reach api.anthropic.com"
**Cause**: Firewall blocked Claude API or network issue
**Fix**: Check if api.anthropic.com resolved correctly, verify DNS works

## Success Criteria

All tests should pass:
- ✓ Container starts without firewall
- ✓ Container starts with firewall enabled
- ✓ Allowed services are accessible
- ✓ Blocked services are blocked
- ✓ DNS resolution works
- ✓ SSH/Git operations work
- ✓ Claude CLI works normally
- ✓ Custom services can be added
- ✓ Firewall validates critical services
- ✓ iptables/ipset rules are correct
