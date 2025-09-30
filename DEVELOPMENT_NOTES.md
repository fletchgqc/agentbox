# AgentBox Development Notes (For Agents)

**Note**: Also read README.md for user-facing features, command usage, and Git authentication setup.

## Technical Context

### Project Origin
AgentBox is a simplified replacement for ClaudeBox. The user was maintaining patches to ClaudeBox but wanted to stop due to complexity. Key motivations:
- ClaudeBox has 1000+ users but too many features the user doesn't need
- Complex slot system and Bash 3.2 compatibility requirements made it hard to maintain
- Python profile in ClaudeBox was buggy
- User wanted automatic behavior without prompts

### Architecture Decisions

1. **Ephemeral Containers**: Containers use `--rm` flag and are destroyed on exit. This differs from ClaudeBox's persistent slot-based containers.

2. **Hash-Based Naming**: Container names use SHA256 hash of project directory path (first 12 chars) to ensure uniqueness and avoid conflicts.

3. **Volume Strategy**: Claude CLI config uses Docker named volumes (not bind mounts) to avoid permission issues. Initialized from `~/.claude` if it exists.

4. **SSH Implementation**: Currently mounts `~/.agentbox/ssh/` directory directly (not true SSH agent forwarding). Future improvement could use Docker's `--ssh` flag for better security.

5. **UID/GID Handling**: Dockerfile builds with host user's UID/GID passed as build args to minimize permission issues, but some remain (see ZSH history issue).

## Implementation Details

### File Responsibilities
- `Dockerfile`: Multi-stage build with all language toolchains. Uses `USER claude` (UID 1000)
- `entrypoint.sh`: Minimal - only sets PATH and creates Python venvs
- `agentbox`: Main logic - rebuild detection, container lifecycle, mount management

### Rebuild Detection
Uses SHA256 hash of Dockerfile + entrypoint.sh stored as Docker image label. Compares on each run to trigger automatic rebuilds.

### Container Lifecycle
1. Check Docker daemon
2. Compare hashes → rebuild if needed
3. Clean up old containers using outdated image
4. Run ephemeral container with all mounts
5. Container removed automatically on exit

### Mount Points
```bash
/workspace              # Project directory (main mount)
/home/claude/.ssh       # SSH keys from ~/.agentbox/ssh/
/home/claude/.gitconfig # Git config (read-only)
/home/claude/.npm       # NPM cache
/home/claude/.cache/pip # Pip cache
/home/claude/.m2        # Maven cache
/home/claude/.gradle    # Gradle cache
/home/claude/.zsh_history   # ZSH history
/home/claude/.bash_history  # Bash history
/home/claude/.claude    # Claude config (Docker volume)
```

## Testing Status
- Basic functionality verified (help command, shell mode)
- Full Docker build/run cycle needs real environment testing
- Multi-project isolation designed but not stress-tested
- SSH operations need testing with actual Git repositories

## Potential Future Improvements

1. **True SSH Agent Forwarding**: Replace key mounting with Docker's `--ssh` flag
2. **Build Cache Optimization**: Better layer ordering for faster rebuilds
3. **Permission Fixes**: Solve ZSH history permission issue properly
4. **Debug Mode**: Add verbose logging for troubleshooting
5. **Config File**: Support `.agentboxrc` for user preferences
6. **WSL2 Optimizations**: Specific handling for WSL2 environments

## Known Technical Issues

### Claude CLI Triple Display
- **Root Cause**: Ink framework's TTY handling in containers
- **Attempted Fixes**: Terminal size handling, TTY allocation modes
- **Status**: Unfixable without Claude CLI framework changes

### ZSH History Permissions
- **Root Cause**: Host file ownership (host UID) vs container user (UID 1000)
- **Attempted Fixes**: Various permission strategies, all had side effects
- **Status**: Cosmetic issue, functionality works

### Image Size
Current image is large (~2GB) due to multiple language toolchains. Could optimize with:
- Multi-stage builds with slimmer final stage
- Optional language support via build args
- Better layer caching strategies

## Development Philosophy

1. **Simplicity First**: Resist feature creep. The value is in being simpler than ClaudeBox.
2. **Automatic Behavior**: Users shouldn't need to think about container management.
3. **No Prompts**: Everything should work without user interaction (except initial SSH setup).
4. **Fail Gracefully**: Clear error messages, automatic recovery where possible.

## Command Analysis

The `agentbox` script has these key functions:
- `check_docker()`: Verify Docker daemon is running
- `calculate_hash()`: SHA256 hash for change detection
- `needs_rebuild()`: Compare hashes with image label
- `build_image()`: Docker build with proper args
- `cleanup_old_containers()`: Remove containers using old images
- `run_container()`: Main container execution logic
- `ssh_setup()`: Initialize ~/.agentbox/ssh/ directory

## Critical Implementation Notes

1. **Never use `-i` flag**: Git commands like `git rebase -i` won't work in non-interactive container context

2. **Path Hashing**: Container names use first 12 chars of SHA256(project_path) - collision risk is negligible

3. **Volume Naming**: `agentbox-claude-<hash>` pattern ensures per-project isolation

4. **Shell Mode**: When using `shell` command, execution goes through zsh even for bash (ensures environment is loaded)

5. **Admin Mode**: `--admin` flag doesn't actually grant sudo (would need Dockerfile changes) - currently just shows a message

## File Count
- Core files: 3 (Dockerfile, entrypoint.sh, agentbox)
- Documentation: 2 (README.md, DEVELOPMENT_NOTES.md)
- Other: .gitignore, LICENSE, CLAUDE.md
- Total: ~8 files (vs ClaudeBox's 20+)