# AgentBox Hook-based Architecture

**Version**: 2.0.0  
**Created**: 2025-12-28  
**Updated**: 2025-12-28 (Revision 2: 2 Hooks + Metadata)  
**Status**: Active

---

## Overview

AgentBox uses a **hook-based architecture** to keep CLI agent swaps flexible.

## Hook-based architecture

### Concept

Instead of configuration variables, each agent now provides **2 hooks + 1 metadata file**:

1. **install.sh** – installation inside the container (hook)
2. **config** – volume/config metadata (file)
3. **start.sh** – welcome message, MCP detection, agent launch (hook)

### Benefits

- ✅ **Minimal coupling**: only two hooks plus a metadata file
- ✅ **Clear separation**: imperative scripts versus declarative metadata
- ✅ **Maximum flexibility**: agents declare their own paths
- ✅ **Explicit**: nothing is implicit; every value must be set
- ✅ **No core changes**: adding a new agent just means new files

## Interface specification

### 1. install.sh (hook)

**Purpose**: install the agent inside the Docker container

**Invoked**: during `docker build`

**Input**: none

**Output**: exit code 0 on success

**Important**: must be executable on the host (`chmod +x install.sh`)

**Example**:
```bash
#!/bin/bash
set -euo pipefail
npm install -g opencode-ai
opencode --version
```

### 2. config (metadata)

**Purpose**: define the volume and config paths

**Invoked**: sourced by the `agentbox` script before `docker run`

**Format**: key-value pairs (Bash variables)

**Mandatory variables**:
- `VOLUME_NAME` – Docker volume name
- `MOUNT_PATH` – mount location inside the container
- `HOST_CONFIG_DIR` – host configuration directory (can be empty string `""`)

**Placeholders** (substituted by AgentBox):
- `${HASH}` – container hash (e.g., `abc123`)
- `${AGENT}` – agent name (e.g., `opencode`)

**Important**: all three variables must be set explicitly; there are no defaults.

**Note**: `HOST_CONFIG_DIR` may be an empty string, but it must still be assigned.

**Example**:
```bash
# OpenCode configuration metadata
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.config/opencode"
HOST_CONFIG_DIR="${HOME}/.config/opencode"
```

**Example with empty host directory**:
```bash
# Agent without host configuration
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.some-agent"
HOST_CONFIG_DIR=""  # no host config to copy
```

### 3. start.sh (hook)

**Purpose**: launch the agent (includes welcome message and optional MCP detection)

**Invoked**: by `entrypoint.sh` as the final step

**Input**: `$@` = user arguments (e.g., `chat`, `--help`)

**Output**: starts the agent (should finish with `exec`)

**Important**: must be executable on the host (`chmod +x start.sh`)

**Should include**:
1. display a welcome message
2. optionally detect MCP configuration
3. start the agent with `exec`

**Example**:
```bash
#!/bin/bash
set -euo pipefail

# Welcome
echo "🤖 OpenCode: $(opencode --version)"

# MCP detection
if [ -f "/workspace/opencode.json" ] && grep -q '"mcp"' /workspace/opencode.json; then
    echo "🔌 MCP configuration detected"
fi

# Launch agent
exec opencode "$@"
```

## Lifecycle & data flow

```
User command
    ↓
./agentbox --agent=opencode
    ↓
┌─────────────────────────────┐
│ Build phase (Dockerfile)   │
│ - COPY agents.d/           │
│ - RUN install.sh           │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Runtime phase (agentbox)    │
│ - Read config metadata      │
│ - Substitute placeholders   │
│ - Create volumes            │
│ - docker run ...            │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Container start (entrypoint)│
│ - SSH setup                 │
│ - direnv setup              │
│ - exec start.sh             │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Agent running               │
│ (OpenCode/Claude/etc)       │
└─────────────────────────────┘
```

## Multi-Agent isolation

Different projects can run different agents at the same time:

```
Project A                    Project B
/home/user/project-a        /home/user/project-b
    ↓                            ↓
./agentbox --agent=opencode      ./agentbox --agent=claude-code
    ↓                            ↓
Container: agentbox-abc123       Container: agentbox-def456
Volume: agentbox-config-abc123   Volume: agentbox-config-def456
Binary: opencode                 Binary: claude
```

## Adding a new agent

If a new agent should be added, see [`agents.d/README.md`](agents.d/README.md), the canonical step-by-step guide for adding agents.

## Agent selection

### CLI flag (recommended)
```bash
./agentbox --agent=opencode
./agentbox --agent=claude-code
```

### Default agent
If no `--agent` flag is provided, `claude-code` is used. If `claude-code` is unavailable, execution falls back to `opencode` automatically.

## Directory structure

```
agents.d/
├── .template/          # template for new agents
│   ├── install.sh      # installation hook
│   ├── config          # metadata (key-value)
│   ├── start.sh        # start hook
│   └── README.md       # template guide
├── opencode/           # OpenCode implementation
│   ├── install.sh
│   ├── config
│   └── start.sh
├── claude-code/        # Claude Code
└── README.md           # agents directory documentation
```

## Design principles

### 1. Explicit over implicit
- no conventions or defaults
- every value in `config` must be explicitly set
- predictable behavior, no surprises

### 2. Separation of concerns
- **Hooks (scripts)**: imperative logic (what to do)
- **Metadata (config)**: declarative data (where and how)

### 3. Minimal interface
- only two hooks plus one metadata file
- each file serves a single clear purpose
- no unnecessary overhead

### 4. Flexibility
- agents can select arbitrary paths
- placeholders allow dynamic values
- optional values can remain empty

## Technical details

### File permissions
**Important**: hook scripts (`*.sh`) must be executable on the host!

```bash
chmod +x agents.d/my-agent/install.sh
chmod +x agents.d/my-agent/start.sh
```

**Reason**: Docker's `COPY` copies the host permissions. Redundant `chmod` commands inside the Dockerfile or entrypoint are unnecessary and prone to failure.

### npm/node availability
**install.sh scripts**: `npm` and `node` are available via the Dockerfile's `ENV PATH`.

**No manual NVM initialization required**:
```bash
# ❌ do not do this:
# source "$NVM_DIR/nvm.sh"

# ✅ just run:
npm install -g my-agent
```

The Dockerfile sets a global symlink:
```dockerfile
ENV PATH="/home/claude/.nvm/current/bin:${PATH}"
```

## Success criteria

The hook-based architecture is successful when:

- ✅ a new agent can be added in under 10 minutes (copy + tweak template)
- ✅ no hard-coded agent references exist in the core files (aside from the default)
- ✅ multi-agent support works out of the box
- ✅ all three config variables are mandatory and explicit
- ✅ all tests pass (build, start, volume, multi-project)

## References

- [`agents.d/README.md`](agents.d/README.md) – agent development guide (instructions + troubleshooting)
