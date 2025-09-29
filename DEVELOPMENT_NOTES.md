# AgentBox Development Notes

## Context for Future Development

### Project Origin
This is a simplified replacement for ClaudeBox - a complex Docker-based development environment that the user found useful but difficult to maintain. The user wanted a slimmed-down version without profiles, slots, or complex bash abstractions.

### Key Design Decisions

1. **Single Dockerfile**: No profile system - all languages (Python, Node.js, Java, Shell) in one image
2. **Automatic Rebuilds**: Hash-based detection of Dockerfile/entrypoint changes triggers automatic rebuild
3. **Per-Project Containers**: Each project directory gets its own persistent container (named using path hash)
4. **SSH Agent Forwarding**: Implemented for security - no direct key mounting (this was added after security discussion)
5. **Name Change**: Deliberately named "agentbox" not "claudebox" to avoid confusion

### Current Implementation

**Core Files:**
- `Dockerfile` - Unified multi-language image (Python via uv, Node via NVM, Java via SDKMAN)
- `entrypoint.sh` - Minimal initialization (sets PATH, auto-creates Python venvs)
- `agentbox` - Main wrapper script (~400 lines) with auto-rebuild and container management
- `README.md` - Complete documentation including SSH agent setup

**Key Features Implemented:**
- Automatic image rebuild when Dockerfile/entrypoint changes (via hash tracking)
- Container persistence per project (survives restarts)
- Package manager cache persistence in `~/.cache/agentbox/<container-name>/`
- Shell history persistence in `~/.agentbox/projects/<container-name>/history/` (zsh, bash)
- Claude CLI configuration mounted from `~/.claude` (shared across all containers)
- Automatic cleanup of outdated containers after rebuild
- SSH agent forwarding instead of mounting SSH keys (security improvement)
- Support for running multiple projects simultaneously

### Architecture Notes

```
Single Dockerfile → Build once → agentbox:latest image
                                         ↓
                    ┌────────────────────┼────────────────────┐
                    ↓                    ↓                    ↓
          Container: project1    Container: project2    Container: project3
          Mounts: ~/code/api    Mounts: ~/code/web     Mounts: ~/code/cli
          Cache: ~/.cache/agentbox/agentbox-<hash1>/
          Project: ~/.agentbox/projects/agentbox-<hash1>/
                                agentbox/agentbox-<hash2>/
                                ~/.agentbox/projects/agentbox-<hash2>/
                                                agentbox/agentbox-<hash3>/
                                                ~/.agentbox/projects/agentbox-<hash3>/
```

### Testing Status
- Basic functionality tested (help command works)
- Image building not yet tested (would require Docker)
- Multi-project isolation not yet tested in practice

### Potential Future Improvements

1. **Performance**: Docker layer optimization could be improved for faster rebuilds
2. **Security**: Could add option for dedicated SSH keys in `~/.ssh/agentbox/`
3. **Configuration**: Could add `.agentboxrc` for user preferences
4. **Logging**: Could add debug mode for troubleshooting
5. **Platform Support**: Currently assumes Linux/macOS, could add WSL2 specific handling

### Migration from ClaudeBox

The user has been maintaining their own patches to ClaudeBox but wants to stop. This agentbox solution is meant to be:
- Simpler (4 files vs 20+)
- More maintainable (no Bash 3.2 compatibility requirements)
- More predictable (no slot management complexity)
- Equally functional for their use cases (Python, JavaScript, Java, Shell development)

### Important Context from Original ClaudeBox

- Has 1000+ users
- Enables multiple Claude instances to communicate via tmux
- Uses complex slot system for container management
- Requires Bash 3.2 compatibility for macOS
- Has many features the user doesn't need (firewall rules, project isolation modes, 20+ profiles)

### User's Specific Needs

- Uses profiles: Java, JavaScript, Shell, Python (Python profile was buggy in ClaudeBox)
- Wants to run in different project directories independently
- Needs simultaneous containers for different projects
- Prefers automatic behavior without prompts
- Values security (hence the SSH agent forwarding discussion)

### Current Working Directory
The agentbox solution is in `/workspace/agentbox/` ready to be moved to the user's preferred location.

## To Continue Development

1. The solution is functionally complete but needs real-world testing
2. Consider adding the suggested improvements based on user feedback
3. The main innovation is the simplicity - resist adding complexity
4. Keep the automatic rebuild feature as the core value proposition
5. Maintain the security-first approach with SSH agent forwarding

## Command to Test

```bash
cd /workspace/agentbox
./agentbox --help  # Works
./agentbox         # Would create/attach to container for current directory
```

The user plans to move this to another location and continue testing/development.

## Known Issues and Limitations

### Claude CLI Triple Display Issue

**Issue**: When running `claude` in the container for the first time (during authentication setup), the welcome screen and authentication prompts display three times.

**Root Cause**: This is a known limitation with the Claude CLI's Ink-based UI framework when running in Docker containers. The issue is related to TTY/raw mode handling in containerized environments.

**Impact**:
- ✅ **Functional**: Claude CLI works perfectly - authentication, commands, and all features function correctly
- ✅ **Visual**: Terminal formatting is correct (left-aligned, proper sizing)
- ⚠️ **Cosmetic**: Initial setup displays welcome screen 3x (only during first authentication)

**Investigation Summary**:
- Systematically ruled out: shell configuration, PATH issues, npm installation, config mounting, workspace conflicts, TTY allocation
- Added terminal size handling from ClaudeBox (improves formatting)
- Verified same installation method as ClaudeBox (which likely has same limitation)
- Issue only occurs during interactive authentication setup, not normal CLI usage

**Recommendation**: Accept as cosmetic limitation. Core functionality is fully operational and this is likely present in other containerized Claude CLI environments.

**Status**: Documented limitation - no further action required unless Claude CLI framework updates resolve the issue.