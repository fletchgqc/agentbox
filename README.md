![AgentBox Logo](media/logo-image-only-150.png)

# AgentBox

A container-based development environment for running agentic coding tools in a more safe, isolated fashion. This makes it less dangerous to give your agent full permissions (YOLO mode / `--dangerously-skip-permissions`), which is, in my opinion, the only way to use AI agents.

## Features

- **Shares project directory with host**: Maps a volume with the source code so that you can see and modify the agent's changes on the host machine - just like if you were running your tool without a container.
- **Multi-Tool Support**: All agentic coding tools are supported, some built-in, others [via prompt](#adding-tools).
- **Unified Development Environment**: Single container image with Python, Node.js, Java, and Shell support
- **Isolated SSH**: Dedicated SSH directory for secure Git operations
- **Low-Maintenance Philosophy**: Always uses latest LTS tool versions, rebuilds container automatically when necessary

## Requirements

- **Container Runtime**: Docker or Podman (only rootless podman has been tested)
- **Bash 4.0+**: macOS ships with Bash 3.2, I recommend upgrading via Homebrew (`brew install bash`).

## Container Runtime

AgentBox works with Docker or Podman. The runtime is automatically detected:
- Docker is used if available and running
- Podman is used if Docker is unavailable
- Error if neither is available

No configuration needed - just install either runtime.

## Installation and Quick Start

1. Clone AgentBox to your preferred location (e.g. `~/code/agentbox/agentbox`)
2. Ensure Docker or Podman is installed and running
3. Make the script executable: `chmod +x agentbox`
4. (Strongly recommended) add an alias for global access - e.g. alias `agentbox` to `~/code/agentbox/agentbox`.
5. Run `agentbox` from your desired working directory (wherever you would normally start your agentic coding tool).

## CLI Agent Support

- claude code: built-in
- opencode: built-in
- any other agents (copilot CLI, Aider, Cursor CLI...): easily add it yourself using the prompt at [docs/prompts/add-tool.md](docs/prompts/add-tool.md).

### Adding tools

Start your coding agent in the agentbox directory and issue this (example) prompt:
> Add support for Copilot CLI to this project using the instructions at @docs/prompts/add-tool.md.

Then you can go to your project directory and run (e.g.) `agentbox --tool copilot`. Thanks to [Felix Medam](https://github.com/SputnikTea) for this very cool idea.

## Helpful Commands

```bash
# Start Claude CLI in container (--dangerously-skip-permissions is automatically included)
agentbox

# Use OpenCode instead of Claude
agentbox --tool opencode

# Or set via environment variable
AGENTBOX_TOOL=opencode agentbox

# Show available commands
agentbox --help

# Non-agentbox CLI flags are passed through to claude.
# For example, to continue the most recent session
agentbox -c

# Mount additional directories for multi-project access
agentbox --add-dir ~/proj1 --add-dir ~/proj2

# Restrict outbound network to allowlisted domains
agentbox --proxy

# Start shell with sudo privileges
agentbox shell --admin

# Set up SSH keys for AgentBox
agentbox ssh-init
```

**Note**: Tool selection via `--tool` flag takes precedence over the `AGENTBOX_TOOL` environment variable.

## How It Works

AgentBox creates ephemeral containers (with `--rm`) that are automatically removed when you exit. However, important data persists between sessions:

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
  Claude: ~/.claude
  OpenCode: ~/.config/opencode and ~/.local/share/opencode
```

## Languages and Tools

The unified container image includes:

- **Python**: Latest version with `uv` for fast package management
- **Node.js**: Latest LTS via NVM with npm, yarn, and pnpm
- **Java**: Latest LTS via SDKMAN with Gradle
- **Shell**: Zsh (default) and Bash with common utilities
- **Claude CLI**: Pre-installed with per-project authentication
- **OpenCode**: Pre-installed as an alternative AI coding tool

## Authenticating to Git or other SCC Providers

### GitHub
The `gh` tool is included in the image and can be used for all GitHub operations. My recommendation:
- Visit this link to configure a [fine-grained access-token](https://github.com/settings/personal-access-tokens/new?name=MyRepo-AI&description=For%20AI%20Agent%20Usage&contents=write&pull_requests=write&issues=write) with a sensible set of permissions predefined.
- On that page, restrict the token to the project repository.
- Create a .env file at the root of your project repository with entry `GH_TOKEN=<token>`
- Add some instructions to the CLAUDE.md file, telling it to use the `gh` tool for Git operations. You can see a slightly more complicated example in this repo, there is a sub-agent for git operations in .claude/agents and instructions in CLAUDE.md to remember to use agents.

You or your agent should convert ssh git remotes to https, ssh remotes don't work with tokens.

### GitLab
 The `glab` tool is included in the image. You can use it with a GitLab token for API operations, but not for git operations as far as I know. So for GitLab I recommend the SSH configuration detailed below.

## Git Configuration

AgentBox copies your host `~/.gitconfig` into the container on each startup. If you don't have a host gitconfig, it uses `agent@agentbox` as the default identity.

## SSH Configuration

AgentBox uses a dedicated SSH directory (`~/.agentbox/ssh/`) isolated from your main SSH keys:

```bash
# Initialize SSH for AgentBox
agentbox ssh-init
```

This will:
1. Create ~/.agentbox/ssh/ directory
2. Copy your known_hosts for host verification
3. Generate a new Ed25519 key pair (if preferred, delete them and manually place your desired SSH keys in `~/.agentbox/ssh/`).

### Environment Variables
Environment variables are loaded from `.env` files in this order (later overrides earlier):
1. `~/.agentbox/.env` (global)
2. `<project-dir>/.env` (project-specific)

AgentBox includes `direnv` support - `.envrc` files are evaluated if `direnv allow`ed on the host.

## MCP Server Configuration

Due to [Claude Code bug #6130](https://github.com/anthropics/claude-code/issues/6130), by default you won't be prompted to enable MCP servers when running `agentbox` directly.

**Workaround options:**

1. **Enable individual MCP servers interactively:**
   ```bash
   agentbox shell
   claude
   ```

2. **Enable all MCP servers by default** by adding `"enableAllProjectMcpServers": true` to your Claude project or user settings.

## Data Persistence

### Package Caches
Package manager caches are stored in `~/.cache/agentbox/<container-name>/`:
- npm packages: `~/.cache/agentbox/<container-name>/npm`
- pip packages: `~/.cache/agentbox/<container-name>/pip`
- Maven artifacts: `~/.cache/agentbox/<container-name>/maven`
- Gradle cache: `~/.cache/agentbox/<container-name>/gradle`

### Shell History
Zsh history is preserved in `~/.agentbox/projects/<container-name>/history`

### Tool Authentication

Both tools use bind mounts to share authentication across all AgentBox projects:

**Claude CLI**:
- `~/.claude` mounted at `/home/agent/.claude`

**OpenCode**:
- Config: `~/.config/opencode` mounted at `/home/agent/.config/opencode`
- Auth: `~/.local/share/opencode` mounted at `/home/agent/.local/share/opencode`

## Network Proxy

The `--proxy` flag restricts outbound network access to an allowlisted set of domains using a sidecar tinyproxy container on an isolated network. All HTTP/HTTPS traffic must pass through the proxy; non-HTTP traffic (including git-over-SSH) is blocked.

A default allowlist covering package registries, git hosts, and AI APIs is created per-project at `~/.agentbox/proxy/<container-name>/allowlist.txt` on first use.

```bash
# Manage the per-project allowlist
agentbox proxy list                 # Show allowed domains
agentbox proxy allow example.com    # Add a domain
agentbox proxy block example.com    # Remove a domain
agentbox proxy reset                # Reset to defaults

# Inspect proxy activity (requires running proxy)
agentbox proxy log [-f]             # View proxy log
agentbox proxy blocked              # Show denied domains with hit counts
```

Limitations: only HTTPS on port 443 is tunneled (non-standard ports like 8443 are blocked). Allowlist patterns use POSIX basic regex — extended syntax (`+`, `?`, `|`) is not supported.

## Advanced Usage

### Running One-Off Commands
If you need to run a single command in the containerized environment without starting Claude CLI or an interactive shell:

```bash
# Run any command
agentbox npm test
```

### Rebuild Control
```bash
# Force rebuild the container image
agentbox --rebuild
```

The image automatically rebuilds when:
- Dockerfile or entrypoint.sh changes
- Image is older than 48 hours (to get latest tool versions)

## Tool / Dependency Versions
The Dockerfile is configured to pull the latest stable version of each tool (NVM, GitLab CLI, etc.) during the build process. This makes maintenance easy and ensures that we always use current software. It also means that rebuilding the container image may automatically result in newer versions of tools being installed, which could introduce unexpected behavior or breaking changes. If you require specific tool versions, consider pinning them in the Dockerfile.

## Alternatives
### Anthropic DevContainer
Anthropic offers a [devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) which achieves a similar goal. If you like devcontainers, that's a good option. Unfortunately, I find that devcontainers sometimes have weird bugs, problematic support in IntelliJ/Mac, or they are just more cumbersome to use (try switching to a recent project with a shortcut, for example). I don't want to force people to use a devcontainer if what they really want is safe YOLO-mode isolation - the simpler solution to the problem is just containers, hence, this project.

### Comparison with ClaudeBox
AgentBox began as a simplified replacement for [ClaudeBox](https://github.com/RchGrav/claudebox). I liked the ClaudeBox project, but its complexity caused a lot of bugs and I found myself maintaning my own fork with my not-yet-merged PRs. It became easier for me to build something leaner for my own needs. Comparison:

| Feature | AgentBox | ClaudeBox |
|---------|----------|-----------|
| Files | 3 core files | 20+ files |
| Profiles | Single unified image | 20+ language profiles |
| Container Management | Simple per-project | Advanced slot system |
| Setup | Automatic | Manual configuration |

## Support and Contributing
I make no guarantee to support this project in the future, however the history is positive: I've actively supported it since September 2025. Feel free to create issues and submit PRs. The project is designed to be understandable enough that if you need specific custom changes which we don't want centrally, you can fork or just make them locally for yourself.

If you do contribute, consider that AgentBox is designed to be simple and maintainable. The value of new features will always be weighed against the added complexity. Try to find the simplest possible way to get things done and control the AI's desire to write such bloated doco.
