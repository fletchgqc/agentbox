![AgentBox Logo](media/logo-image-only-150.png)

# AgentBox

A Docker-based development environment for running AI coding agents in a safe, isolated fashion. Supports multiple agents (OpenCode, Claude Code, etc.) via a simple hook-based architecture.

## Features

- **Multi-Agent Support**: Easily switch between OpenCode, Claude Code, and other AI coding agents
- **Hook-based Architecture**: Add new agents without modifying core code
- **Shares project directory with host**: Maps a volume with the source code so that you can see and modify the agent's changes on the host machine
- **Multi-Directory Support**: Mount additional project directories for cross-project development
- **Unified Development Environment**: Single Docker image with Python, Node.js, Java, and Shell support
- **Automatic Rebuilds**: Detects changes to Dockerfile/entrypoint and rebuilds automatically
- **Per-Project Isolation**: Each project directory gets its own isolated container environment
- **Persistent Data**: Package caches and shell history persist between sessions
- **SSH Support**: Dedicated SSH directory for secure Git operations

## Agent Architecture

AgentBox uses a **hook-based architecture** for maximum flexibility. Each agent provides 2 hooks + 1 metadata file, enabling new agents to be added without core code changes.

See [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md) for details.

## Supported Agents

- **OpenCode** - Open-source AI coding agent with 75+ LLM providers
- **Claude Code** - Anthropic's Claude Code (planned)

See [`agents.d/README.md`](agents.d/README.md) for how to add new agents.

## Requirements

- **Docker**: Must be installed and running
- **Bash 4.0+**: macOS ships with Bash 3.2, I recommend upgrading via Homebrew (`brew install bash`).

## Multi-Directory Support

AgentBox supports mounting additional directories for scenarios where your agent needs access to multiple projects:

```bash
# Mount a single additional directory
agentbox --add-dir ~/other-project

# Mount multiple directories (repeatable flag)
agentbox --add-dir ~/proj1 --add-dir ~/proj2 --add-dir ~/proj3

# Works with shell mode too
agentbox --add-dir ~/library-code shell
```

**How it works:**
- Your current directory is always mounted as `/workspace`
- Additional directories are mounted using their folder names (e.g., `/foo`, `/bar`)
- All directories are writable - changes sync back to the host
- The mounting order follows the order you specify in the flag

## Installation

1. Clone AgentBox to your preferred location
2. Ensure Docker is installed and running
3. Make the script executable: `chmod +x agentbox`
4. Optionally add to your PATH for global access

## Quick Start

```bash
# Show available commands
agentbox --help

# Build with specific agent (default: claude-code, fallback: opencode)
./agentbox --rebuild --agent=opencode

# Start agent (with specific agent selection)
./agentbox --agent=opencode

# Or use default agent
./agentbox

# Mount additional directories for multi-project access
agentbox --add-dir ~/proj1 --add-dir ~/proj2

# Start shell with sudo privileges
agentbox shell --admin

# Set up SSH keys for AgentBox
agentbox ssh-init
```

## How It Works

AgentBox creates ephemeral Docker containers (with `--rm`) that are automatically removed when you exit. However, important data persists between sessions:

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
  Agent Config: Docker volume agentbox-config-<hash>
```

## Languages and Tools

The unified Docker image includes:

- **Python**: Latest version with `uv` for fast package management
- **Node.js**: Latest LTS via NVM with npm, yarn, and pnpm
- **Java**: Latest LTS via SDKMAN with Gradle
- **Shell**: Zsh (default) and Bash with common utilities
- **AI Agents**: OpenCode, Claude Code (planned) - see Agent Selection below

## Authenticating to Git or other SCC Providers

### GitHub
The `gh` tool is included in the image and can be used for all GitHub operations. My recommendation:
- Visit this link to configure a [fine-grained access-token](https://github.com/settings/personal-access-tokens/new?name=MyRepo-AI&description=For%20AI%20Agent%20Usage&contents=write&pull_requests=write&issues=write) with a sensible set of permissions predefined.
- On that page, restrict the token to the project repository.
- Create a .env file at the root of your project repository with entry `GH_TOKEN=<token>`
- Add some instructions to the CLAUDE.md file, telling it to use the `gh` tool for Git operations. You can see a slightly more complicated example in this repo, there is a sub-agent for git operations in .claude/agents and instructions in CLAUDE.md to remember to use agents.

Note that Claude will convert your git remotes to https, ssh remotes don't work with tokens.

### GitLab
 The `glab` tool is included in the image. You can use it with a GitLab token for API operations, but not for git operations as far as I know. So for GitLab I recommend the SSH configuration detailed below.

## Git Configuration

AgentBox copies your host `~/.gitconfig` into the container on each startup. If you don't have a host gitconfig, it uses `agent@agentbox` / `AI Agent (AgentBox)` as the default identity.

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
If a `.env` file exists in your project directory, the environment variables defined there will automatically be loaded into the container.

AgentBox also includes `direnv` support - if you have a `.envrc` file in your project directory, it will be automatically evaluated inside the container if you have `direnv allow`ed it on your host machine.

## MCP Server Configuration

MCP (Model Context Protocol) support depends on the selected agent:

### OpenCode
Configure MCP servers in `opencode.json`:
```json
{
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem"],
      "enabled": true
    }
  }
}
```

See `opencode.json.example` for a complete configuration template.

### Claude Code (planned)
Configuration details will be added when Claude Code agent is implemented.

## Data Persistence

### Package Caches
Package manager caches are stored in `~/.cache/agentbox/<container-name>/`:
- npm packages: `~/.cache/agentbox/<container-name>/npm`
- pip packages: `~/.cache/agentbox/<container-name>/pip`
- Maven artifacts: `~/.cache/agentbox/<container-name>/maven`
- Gradle cache: `~/.cache/agentbox/<container-name>/gradle`

### Shell History
Zsh history is preserved in `~/.agentbox/projects/<container-name>/history`

### Agent Configuration
Agent configuration data is stored in Docker named volumes (`agentbox-config-<hash>`), providing:
- Per-project agent configuration
- Persistent configuration across container restarts
- Isolation between different projects

## Volume Management

### Listing Volumes
```bash
# List all AgentBox volumes
docker volume ls | grep agentbox-config
```

### Cleanup
```bash
# Remove specific project's configuration
docker volume rm agentbox-config-<hash>

# Remove all AgentBox volumes (clears all configurations)
docker volume ls -q | grep agentbox-config | xargs docker volume rm

# Full cleanup (removes image and optionally cached data)
agentbox --cleanup
```

**Note**: Removing volumes only affects agent configuration - your project files remain untouched.

## Advanced Usage

### Running One-Off Commands
If you need to run a single command in the containerized environment without starting the agent or an interactive shell:

```bash
# Run any command
agentbox npm test
```

### Rebuild Control
```bash
# Force rebuild the Docker image
agentbox --rebuild
```

The image automatically rebuilds when the Dockerfile or entrypoint.sh changes

## Tool / Dependency Versions
The Dockerfile is configured to pull the latest stable version of each tool (NVM, GitLab CLI, etc.) during the build process. This makes maintenance easy and ensures that we always use current software. It also means that rebuilding the Docker image may automatically result in newer versions of tools being installed, which could introduce unexpected behavior or breaking changes. If you require specific tool versions, consider pinning them in the Dockerfile.

## Alternatives
### Anthropic DevContainer
Anthropic offers a [devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) which achieves a similar goal. If you like devcontainers, that's a good option. Unfortunately, I find that devcontainers sometimes have weird bugs, problematic support in IntelliJ/Mac, or they are just more cumbersome to use (try switching to a recent project with a shortcut, for example). I don't want to force people to use a devcontainer if what they really want is safe YOLO-mode isolation - the simpler solution to the problem is just Docker, hence, this project.

### Comparison with ClaudeBox
AgentBox began as a simplified replacement for [ClaudeBox](https://github.com/RchGrav/claudebox). I liked the ClaudeBox project, but its complexity caused a lot of bugs and I found myself maintaning my own fork with my not-yet-merged PRs. It became easier for me to build something leaner for my own needs. Comparison:

| Feature | AgentBox | ClaudeBox |
|---------|----------|-----------|
| Files | 3 core files | 20+ files |
| Profiles | Single unified image | 20+ language profiles |
| Container Management | Simple per-project | Advanced slot system |
| Setup | Automatic | Manual configuration |

## Support and Contributing
I make no guarantee to support this project in the long term. Feel free to create issues and submit PRs. I like to think that I will attend to them. The project is designed to be understandable enough that if you need specific custom changes, which you may well do, you can fork or just make them locally for yourself. Theoretically you could easily this project to other AI Agents, for example.

If you do contribute, consider that AgentBox is designed to be simple and maintainable. The value of new features will always be weighed against the added complexity.

