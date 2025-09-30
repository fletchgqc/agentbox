# AgentBox Development Notes

## Context for Future Development

### Project Origin
This is a simplified replacement for ClaudeBox - a complex Docker-based development environment that the user found useful but difficult to maintain. The user wanted a slimmed-down version without profiles, slots, or complex bash abstractions.

### Key Design Decisions

1. **Single Dockerfile**: No profile system - all languages (Python, Node.js, Java, Shell) in one image
2. **Automatic Rebuilds**: Hash-based detection of Dockerfile/entrypoint changes triggers automatic rebuild
3. **Per-Project Isolation**: Each project directory gets its own container name (using path hash) - containers are ephemeral with `--rm` but caches persist
4. **Dedicated SSH Directory**: Uses `~/.agentbox/ssh/` for SSH keys (isolated from main `~/.ssh/` directory)

### Current Implementation

**Core Files:**
- `Dockerfile` - Unified multi-language image (Python via uv, Node via NVM, Java via SDKMAN)
- `entrypoint.sh` - Minimal initialization (sets PATH, auto-creates Python venvs)
- `agentbox` - Main wrapper script with auto-rebuild and container management

**Key Features Implemented:**
- Automatic image rebuild when Dockerfile/entrypoint changes (via hash tracking)
- Ephemeral containers with `--rm` (automatically cleaned up on exit)
- Package manager cache persistence in `~/.cache/agentbox/<container-name>/`
- Shell history persistence in `~/.agentbox/projects/<container-name>/history/` (zsh, bash)
- Claude CLI configuration uses Docker named volumes per project (initialized from `~/.claude` if present)
- Automatic cleanup of outdated containers after rebuild
- Dedicated SSH directory mounting from `~/.agentbox/ssh/` (provides isolation from main SSH keys)
- Support for running multiple projects simultaneously

### Architecture Notes

```
Single Dockerfile → Build once → agentbox:latest image
                                         ↓
                    ┌────────────────────┼────────────────────┐
                    ↓                    ↓                    ↓
          Container: project1    Container: project2    Container: project3
          (ephemeral, --rm)      (ephemeral, --rm)      (ephemeral, --rm)
          Mounts: ~/code/api    Mounts: ~/code/web     Mounts: ~/code/cli

Persistent data (survives container removal):
  Cache: ~/.cache/agentbox/agentbox-<hash>/
  History: ~/.agentbox/projects/agentbox-<hash>/history/
  Claude: Docker volume agentbox-claude-<hash>
```

### Migration from ClaudeBox

The user has been maintaining their own patches to ClaudeBox but wants to stop. This agentbox solution is meant to be:
- Simpler (4 files vs 20+)
- More maintainable (no Bash 3.2 compatibility requirements)
- More predictable (no slot management complexity)
- Equally functional for their use cases (Python, JavaScript, Java, Shell development)

### ClaudeBox Comparison

ClaudeBox features not needed in AgentBox:
- Complex slot system for container management
- Bash 3.2 compatibility requirements
- 20+ language profiles (AgentBox uses single unified image)
- Firewall rules and project isolation modes
- tmux-based multi-instance communication

### Design Requirements

- Support for Python, JavaScript, Java, and Shell development in single image
- Independent containers for different project directories
- Simultaneous container support for multiple projects
- Automatic behavior without prompts (auto-rebuild on changes)
- Security isolation (dedicated SSH directory at `~/.agentbox/ssh/`)


## To Continue Development

1. The main innovation is the simplicity - resist adding complexity
4. Keep the automatic rebuild feature as the core value proposition

## Quick Start

```bash
./agentbox --help        # Show help
./agentbox               # Start Claude CLI in container
./agentbox shell         # Start interactive shell
./agentbox shell --admin # Start shell with sudo privileges
./agentbox ssh-init      # Set up SSH keys for AgentBox
```

## Known Issues and Limitations

### Claude CLI Triple Display Issue

**Issue**: When running `claude` in the container for the first time (during authentication setup), the welcome screen and authentication prompts display three times.

**Root Cause**: This is a known limitation with the Claude CLI's Ink-based UI framework when running in Docker containers. The issue is related to TTY/raw mode handling in containerized environments.

**Impact**:
- ✅ **Functional**: Claude CLI works perfectly - authentication, commands, and all features function correctly
- ✅ **Visual**: Terminal formatting is correct (left-aligned, proper sizing)
- ⚠️ **Cosmetic**: Initial setup displays welcome screen 3x (only during first authentication)

**Status**: Known cosmetic issue with Ink-based UI in containers. Does not affect functionality.

### ZSH History File Permission Issue

**Issue**: When exiting the container shell, users see: `zsh: can't rename /home/claude/.zsh_history.new to $HISTFILE`

**Root Cause**: Permission mismatch between host-created files and container user (UID 1000).

**Impact**: History persists correctly - error message is cosmetic and can be ignored.

## Volume Management

AgentBox uses Docker named volumes to store Claude CLI authentication data persistently. Each project gets its own volume based on the project directory path.

### Normal Usage
- Volumes are automatically created when you first use AgentBox in a directory
- Authentication persists across container restarts
- No manual management needed

### Cleanup (Optional)
If you want to clean up volumes for old projects:

```bash
# List all AgentBox volumes
docker volume ls | grep agentbox-claude

# Remove specific volume (clears auth for that project)
docker volume rm agentbox-claude-f9fd7e1d1c5c

# Remove all AgentBox volumes (clears all authentication)
docker volume ls -q | grep agentbox-claude | xargs docker volume rm
```

**Note**: Removing volumes only affects authentication - your project files remain untouched.