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

3. **Bind Over Volume**: Claude CLI and OpenCode use bind mounts to host directories.

4. **SSH Implementation**: Currently mounts `~/.agentbox/ssh/` directory directly (not true SSH agent forwarding). Future improvement could use Docker's `--ssh` flag for better security.

5. **UID/GID Handling**: Dockerfile builds with host user's UID/GID passed as build args to minimize permission issues, but some remain (see ZSH history issue).

## Implementation Details

### File Responsibilities
- `Dockerfile`: Multi-stage build with all language toolchains. Uses `USER agent` (UID 1000)
- `entrypoint.sh`: Minimal - only sets PATH and creates Python venvs
- `agentbox`: Main logic - rebuild detection, container lifecycle, mount management

### Rebuild Detection
Automatic rebuilds are triggered by:
1. **File changes**: SHA256 hash of Dockerfile + entrypoint.sh stored as Docker image label. Compares on each run.
2. **Time-based**: If image is older than 48 hours, rebuild automatically to get latest tool versions (Claude Code/OpenCode).

This ensures tools stay updated without manual intervention or version checking overhead.

### Container Lifecycle
1. Detect container runtime (Docker or Podman)
2. Compare hashes → rebuild if needed (on rebuild: build new image, auto-prune dangling images)
3. Run ephemeral container with all mounts
4. Container removed automatically on exit

### Container Runtime Detection

AgentBox supports both Docker and Podman via automatic detection:

**Detection Logic**:
1. Check if `docker` command exists AND daemon is running (`docker info` succeeds)
2. Fall back to `podman` if Docker check fails
3. Error if neither is available

**Runtime Variable**: Set once at startup in `main()`, used throughout via `$RUNTIME` variable substitution.

**Compatibility**: All Docker commands used are Podman-compatible:
- `build`, `run`, `inspect`, `image prune` - identical syntax
- All flags (`--rm`, `-it`, `-v`, `--env`, etc.) - fully compatible
- SELinux `:z` flag - supported by both runtimes
- Labels system - identical implementation

**Docker Preference**: Docker is tried first because:
- Larger user base (more tested)
- Daemon check ensures it's actually running
- Podman users typically understand they're using a Docker alternative

**Podman-Specific Handling**:
- `--userns=keep-id` flag added for Podman rootless mode to maintain UID/GID mapping between host and container
- Without this flag, Podman's user namespace mapping causes ownership mismatches on mounted volumes
- This flag is not supported by Docker, so it's only added when using Podman

### Image Cleanup Strategy
After each successful rebuild, `$RUNTIME image prune -f --filter "label=agentbox.version"` removes dangling agentbox images. This prevents accumulation over time without manual intervention.

### Mount Points
```bash
$PROJECT_DIR            # Project directory (mounted at full host path)
<additional_dirs>       # Additional directories via --add-dir (also mounted at full host paths)
/home/agent/.ssh        # SSH keys from ~/.agentbox/ssh/
/home/agent/.gitconfig  # Git config (read-only)
/home/agent/.npm        # NPM cache
/home/agent/.cache/pip  # Pip cache
/home/agent/.m2         # Maven cache
/home/agent/.gradle     # Gradle cache
/home/agent/.shell_history  # History directory (HISTFILE env var points to zsh_history inside)
/home/agent/.claude     # Claude config
/home/agent/.config/opencode  # OpenCode config
/home/agent/.local/share/opencode  # OpenCode auth
/home/agent/.agent-browser  # Agent-browser data (sessions, config) — see below
```

**Agent-Browser Support**: The mount point for `~/.agent-browser/` persists session state across container restarts. agent-browser itself is not baked into the image — it is installed at runtime via the `docker-agent-browser` skill from [github.com/shrwnsan/agents](https://github.com/shrwnsan/agents). This avoids ~300-400MB image bloat and works with any tool (Claude, OpenCode, Pi).

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
- `detect_runtime()`: Detect available container runtime (Docker or Podman)
- `check_runtime()`: Verify a container runtime is available
- `calculate_hash()`: SHA256 hash for change detection
- `needs_rebuild()`: Compare hashes with image label
- `build_image()`: Docker build with proper args
- `mount_additional_dirs()`: Mount extra directories with intuitive folder names (e.g., /foo, /bar)
- `validate_dir_path()`: Validate directory paths (traversal check, system dirs, existence, duplicates)
- `run_container()`: Main container execution logic with all mounts and command execution
- `ssh_setup()`: Initialize ~/.agentbox/ssh/ directory

## Critical Implementation Notes

1. **Never use `-i` flag**: Git commands like `git rebase -i` won't work in non-interactive container context

2. **Path Hashing**: Container names use first 12 chars of SHA256(project_path) - collision risk is negligible

3. **Container Naming**: `agentbox-<hash>` pattern ensures per-project container isolation (separate caches and history, but shared tool authentication)

4. **Shell Mode**: When using `shell` command, execution goes through zsh even for bash (ensures environment is loaded)

5. **Admin Mode**: `--admin` flag doesn't actually grant sudo (would need Dockerfile changes) - currently just shows a message

## File Count
- Core files: 3 (Dockerfile, entrypoint.sh, agentbox)
- Documentation: 2 (README.md, DEVELOPMENT_NOTES.md)
- Other: .gitignore, LICENSE, CLAUDE.md
- Total: ~8 files (vs ClaudeBox's 20+)
