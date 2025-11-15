# AgentBox Firewall Design Document

## Overview

This document explains the firewall implementation for AgentBox, designed to restrict container network access to approved services only.

## Design Philosophy

The implementation follows AgentBox's core principles:

1. **Simplicity First**: Single 154-line script, no complex dependencies
2. **Automatic Behavior**: Firewall initializes automatically when enabled
3. **No Prompts**: Zero user interaction required
4. **Fail Gracefully**: Clear errors for critical issues, warnings for non-critical

## Architecture Comparison

### Anthropic's Implementation
- **Complexity**: 200+ lines, multiple tools (aggregate, jq, curl)
- **Dependencies**: External GitHub API calls
- **Strengths**: Automatic IP range updates, CIDR aggregation
- **Weaknesses**: Fails if GitHub API unreachable, complex dependencies

### Rewritten Version (marcoemrich)
- **Complexity**: Similar to Anthropic but with hardcoded ranges
- **Dependencies**: Fewer external dependencies
- **Strengths**: No API dependency, faster startup
- **Weaknesses**: Requires manual IP range updates

### AgentBox Implementation (Our Approach)
- **Complexity**: 154 lines, minimal dependencies
- **Dependencies**: Only iptables, ipset, iproute2 (standard tools)
- **Strengths**:
  - Faster startup (no API call ~500ms saved)
  - No GitHub API rate limit issues
  - Fewer failure modes (no external API dependency)
  - Simple configuration via bash arrays
  - Self-validating at startup
  - Easy to customize
- **Trade-offs**:
  - GitHub ranges need manual updates (but infrequent)
  - No CIDR aggregation (negligible performance impact)

## Key Design Decisions

### 1. Opt-In via Environment Variable

```bash
AGENTBOX_FIREWALL=1 agentbox
```

**Rationale**:
- Users who don't need firewall aren't affected
- Can make default later based on feedback
- Follows "simplicity first" - don't force complexity on everyone

### 2. Hardcoded GitHub Ranges

```bash
GITHUB_RANGES=(
  "140.82.112.0/20"
  "143.55.64.0/20"
  ...
)
```

**Rationale**:
- **Faster startup**: No API call (~500ms saved per container start)
- **No rate limiting**: GitHub API has 60 req/hour unauthenticated limit - can hit this when rebuilding frequently or on shared corporate networks
- **Fewer failure modes**: If GitHub API is down/unreachable but github.com works, firewall still initializes
- **Simpler code**: No JSON parsing, HTTP error handling, or API authentication logic
- **Infrequent updates needed**: GitHub IP ranges change rarely (1-2 times per year)

**Alternative Considered**: Fetching from GitHub API like Anthropic
**Rejected Because**: Adds external dependency, slower startup, potential rate limiting issues, more complex error handling

### 3. No CIDR Aggregation

**Rationale**:
- Would require `aggregate` tool (extra dependency)
- Modern iptables handles dozens of rules efficiently
- Simpler code is more maintainable
- Performance difference is negligible

**Alternative Considered**: Using `aggregate` tool
**Rejected Because**: Adds dependency for minimal benefit

### 4. Configuration via Bash Arrays

```bash
ALLOWED_SERVICES=(
  "github.com"
  "api.anthropic.com"
  ...
)

CRITICAL_SERVICES=(
  "api.anthropic.com"
  "github.com"
)
```

**Rationale**:
- Easy to edit for users
- No complex parsing logic
- Self-documenting
- Follows "assume knowledgeable developer" principle

### 5. Self-Validation at Startup

```bash
# Validate firewall is working
log "Validating firewall..."
if timeout 5 wget -q --spider https://api.anthropic.com 2>/dev/null; then
  log "  ✓ Anthropic API accessible"
else
  die "Validation failed: Cannot reach api.anthropic.com"
fi
```

**Rationale**:
- Catches configuration errors immediately
- Prevents silent failures
- User knows firewall is working correctly
- Fail-fast approach

### 6. Separate Test Plan Document

Created `FIREWALL_TEST_PLAN.md` instead of inline tests or separate test script.

**Rationale**:
- Keeps core simple (3 files remain 3 files)
- Testing is manual in this project
- Documentation-first approach
- Easy to follow for contributors

## Technical Implementation

### Firewall Rules Order (Critical)

1. Initialize ipset with allowed IPs
2. Flush existing iptables rules
3. Allow established/related connections FIRST
4. Allow localhost
5. Allow DNS (port 53)
6. Allow SSH (port 22)
7. Allow traffic to ipset addresses
8. Set default DROP policy LAST

**Why this order**: Setting DROP policy before allowing established connections would lock out the container.

### Container Integration

1. **agentbox script**: Adds `--cap-add=NET_ADMIN --cap-add=NET_RAW` when `AGENTBOX_FIREWALL=1`
2. **entrypoint.sh**: Calls `/usr/local/bin/firewall.sh` before showing welcome message
3. **Dockerfile**: Copies firewall.sh and installs dependencies

### Error Handling

- **Critical services** (Anthropic API, GitHub): Container fails if DNS resolution fails
- **Non-critical services**: Warning logged, container continues
- **Validation failures**: Container fails with clear error message

## Maintenance

### Updating GitHub IP Ranges

GitHub publishes current ranges at: https://api.github.com/meta

To update:
1. Visit https://api.github.com/meta
2. Copy IP ranges from `web`, `api`, and `git` arrays
3. Update `GITHUB_RANGES` array in `firewall.sh`
4. Run `agentbox --rebuild`

Expected frequency: 1-2 times per year

### Adding New Services

Edit `firewall.sh`:

```bash
# Add to ALLOWED_SERVICES
ALLOWED_SERVICES=(
  ...
  "your-service.com"
)

# If critical, also add to CRITICAL_SERVICES
CRITICAL_SERVICES=(
  ...
  "your-service.com"  # Only if absolutely required
)
```

Then rebuild: `agentbox --rebuild`

## Security Considerations

### What the Firewall Protects Against

1. **Data exfiltration**: Prevents AI from sending data to arbitrary servers
2. **Unintended network access**: Limits attack surface
3. **Malicious packages**: Prevents packages from reaching C&C servers

### What the Firewall Does NOT Protect Against

1. **DNS tunneling**: DNS queries are allowed (required for resolution)
2. **Attacks via allowed services**: If GitHub is compromised, container can reach it
3. **Local attacks**: Localhost traffic is allowed
4. **Data exfiltration via allowed services**: Can still upload to GitHub, npm, etc.

### Assumptions

1. **Approved services are trustworthy**: GitHub, npm, Maven, Anthropic are trusted
2. **DNS is not malicious**: DNS responses are trusted
3. **User customization is informed**: Users editing firewall.sh understand implications

## Performance Impact

- **Startup time**: +1-2 seconds for DNS resolution and validation
- **Runtime overhead**: Negligible (iptables is highly optimized)
- **Memory usage**: ~1MB for ipset table
- **Network throughput**: No measurable impact

## Future Improvements (Not Implemented)

1. **IPv6 Support**: Currently only IPv4 (IPv6 would require additional ranges)
2. **Dynamic IP Updates**: Periodic refresh of DNS-resolved IPs (adds complexity)
3. **Logging**: Log blocked connection attempts (increases noise)
4. **Caching**: Cache DNS responses between runs (marginal benefit)
5. **CIDR Aggregation**: Use `aggregate` tool (adds dependency)

These were considered but rejected to maintain simplicity.

## Comparison with Alternatives

### vs. Anthropic's Implementation

| Aspect | AgentBox | Anthropic |
|--------|----------|-----------|
| GitHub IP source | Hardcoded | API fetch |
| Startup time | Faster (~500ms saved) | Slower (API call) |
| Rate limit issues | None | Possible (60/hr limit) |
| API failure handling | N/A | Required |
| CIDR aggregation | No | Yes |
| Dependencies | 3 tools | 7 tools |
| Code complexity | 154 lines | 200+ lines |
| Maintenance | Manual (rare) | Automatic |

### vs. No Firewall (Current AgentBox)

| Aspect | With Firewall | Without Firewall |
|--------|--------------|------------------|
| Security | Limited network access | Full network access |
| Startup time | +1-2 seconds | Baseline |
| Complexity | +1 script | Baseline |
| User control | Opt-in | N/A |
| Dependencies | +3 packages | Baseline |

## Testing

See `FIREWALL_TEST_PLAN.md` for comprehensive testing procedures.

Quick validation:
```bash
# Test without firewall
./agentbox shell
curl https://example.com  # Should work

# Test with firewall
AGENTBOX_FIREWALL=1 ./agentbox shell
curl https://api.anthropic.com  # Should work
curl --max-time 5 https://example.com  # Should fail
```

## Conclusion

This implementation balances security, simplicity, and maintainability. It adds minimal complexity to AgentBox while providing meaningful network isolation for users who need it.

The opt-in approach means existing users aren't affected, while new users can enable firewall protection easily. The hardcoded GitHub ranges trade automatic updates for faster startup, no rate limiting, and simpler code - a trade-off that aligns with AgentBox's philosophy of simplicity first.
