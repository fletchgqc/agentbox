# Migration History: Claude Code → OpenCode

**Status**: ✅ Completed (2025-12-28)  
**Outcome**: Led to the hook-based architecture

---

## Summary

AgentBox was originally built for Claude Code. This migration replaced it with OpenCode, leading to the development of the hook-based agent architecture.

**Current architecture**: See [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md)

---

## Key Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keep username "claude" | Minimize changes, many paths affected |
| Neutral volume names `agentbox-config-*` | Provider-independent, future-proof |
| Allow-all permissions | Analogous to `--dangerously-skip-permissions` |
| Clean break, no migration | Simplicity, test project |
| Ignore GitHub Actions | Not essential for core functionality |

---

## Technical Differences

| Aspect | Claude Code | OpenCode |
|--------|-------------|----------|
| NPM Package | `@anthropic-ai/claude-code` | `opencode-ai` |
| Command | `claude` | `opencode` |
| Permissions | `--dangerously-skip-permissions` | Allow-all by default |
| Config Directory | `~/.claude` | `~/.config/opencode` |
| Project Instructions | `CLAUDE.md` | `AGENTS.md` |

---

## Migration Phases (All Completed)

1. ✅ Docker Image - NPM package changed
2. ✅ Container Scripts - Welcome message, MCP detection
3. ✅ Main Script - Volume names, command execution
4. ✅ Documentation - Updated all references
5. ✅ New Files - `opencode.json.example`
6. ✅ Testing - Verified functionality

---

*This document is historical. For current architecture, see [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md).*
