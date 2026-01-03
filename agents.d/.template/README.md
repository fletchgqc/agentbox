# Agent Template

This template is meant as a guide for creating new agent implementations.

## Usage

1. Copy the template:
   ```bash
   cp -r agents.d/.template agents.d/my-agent
   ```

2. Adjust the files:
   - `install.sh` – installs your agent
   - `config` – metadata for volumes and configs
   - `start.sh` – welcome message + agent start

3. **IMPORTANT: Make the scripts executable** (required!)
   - Docker's `COPY` preserves file permissions, so the hook scripts must already be executable before adding them to the image.
   ```bash
   chmod +x agents.d/my-agent/*.sh
   ```

4. Test the implementation:
   ```bash
   ./agentbox --rebuild --agent=my-agent
   ./agentbox --agent=my-agent
   ```

**Note**: Docker's `COPY` keeps host permissions, so ensure the hook scripts are executable before building.

## File specification

### install.sh

**Purpose**: install the agent

**Invoked**: during `docker build`

**Input**: none

**Output**: exit code 0 on success

**Important**:
- must be executable: `chmod +x install.sh`

**Example**:
```bash
#!/bin/bash
set -euo pipefail
npm install -g my-agent
my-agent --version
```

### config

**Purpose**: metadata for the volume/config setup

**Invoked**: sourced by the `agentbox` script

**Format**: key-value pairs (Bash variables)

**Mandatory variables**:
- `VOLUME_NAME` – Docker volume name
- `MOUNT_PATH` – mount path in the container
- `HOST_CONFIG_DIR` – host config directory (can be empty)

**Placeholders** (substituted by AgentBox):
- `${HASH}` – container hash
- `${AGENT}` – agent name

**Example**:
```bash
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.config/my-agent"
HOST_CONFIG_DIR="${HOME}/.config/my-agent"
```

### start.sh

**Purpose**: launch the agent

**Invoked**: by `entrypoint.sh` when the container starts

**Input**: `$@` = user arguments

**Output**: starts the agent (with `exec`)

**Important**: must be executable: `chmod +x start.sh`

**Should include**:
1. welcome message
2. MCP detection (optional)
3. agent start (exec)

**Example**:
```bash
#!/bin/bash
set -euo pipefail

echo "🤖 My Agent: $(my-agent --version)"
exec my-agent "$@"
```

## Validation

Before you mark your agent as "done":

- [ ] Scripts are executable: `chmod +x agents.d/my-agent/*.sh`
- [ ] `install.sh` installs the agent successfully
- [ ] `config` sets all three required variables
- [ ] `start.sh` displays a welcome message
- [ ] `start.sh` launches the agent with `exec`
- [ ] Build test: `./agentbox --rebuild --agent=my-agent`
- [ ] Start test: `./agentbox --agent=my-agent`
- [ ] Volume test: configuration persists after container restart

## Example: OpenCode

See `agents.d/opencode/` for a full reference implementation.
