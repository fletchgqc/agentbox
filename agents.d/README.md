# AgentBox Agents Directory

This directory contains the agent-specific hook implementations for AgentBox.

## Structure

```
agents.d/
├── .template/          # template for new agents
│   ├── install.sh      # installation hook
│   ├── config          # metadata
│   ├── start.sh        # start hook
│   └── README.md       # template guide
├── opencode/           # OpenCode implementation
│   ├── install.sh
│   ├── config
│   └── start.sh
└── README.md           # this file
```

## Available agents

### Implemented
- **opencode** – Open-source AI coding agent with 75+ LLM providers

### Planned
- **claude-code** – Anthropic's Claude Code CLI

## Adding a new agent

### Step-by-step

1. **Copy the template:**
   ```bash
   cp -r agents.d/.template agents.d/my-agent
   ```

2. **Customize the files:**
   
   **a) `install.sh`** – installation:
   ```bash
   #!/bin/bash
   set -euo pipefail
   # npm is available globally
   npm install -g my-agent-package
   my-agent --version
   ```
   
   **b) `config`** – metadata (ALL variables are required):
   ```bash
   VOLUME_NAME="agentbox-config-${HASH}"
   MOUNT_PATH="/home/claude/.config/my-agent"
   HOST_CONFIG_DIR="${HOME}/.config/my-agent"
   ```
   
   **c) `start.sh`** – start + welcome message:
   ```bash
   #!/bin/bash
   set -euo pipefail
   echo "🤖 My Agent: $(my-agent --version)"
   exec my-agent "$@"
   ```

3. **IMPORTANT: make the scripts executable** (required!)
   ```bash
   chmod +x agents.d/my-agent/install.sh
   chmod +x agents.d/my-agent/start.sh
   ```
   
   **Note**: Docker's `COPY` preserves file permissions. The scripts must be executable on the host because `chmod` inside the container can fail.

4. **Test**:
   ```bash
   ./agentbox --rebuild --agent=my-agent
   ./agentbox --agent=my-agent
   ./agentbox --agent=my-agent shell
   ```

5. **Validate**:
   - [ ] Scripts are executable (`ls -l agents.d/my-agent/*.sh` shows `-rwxr-xr-x`)
   - [ ] Build succeeds
   - [ ] Agent starts
   - [ ] Welcome message appears
   - [ ] Volumes remain persistent

## Agent interface

Each agent must provide **2 hooks + 1 metadata file**:

### 1. install.sh (hook)
Installation inside the container (during `docker build`)

### 2. config (metadata)
Volume/config metadata (sourced by the script)

**Mandatory variables**:
- `VOLUME_NAME` – Docker volume name
- `MOUNT_PATH` – mount path inside the container
- `HOST_CONFIG_DIR` – config path on the host (or empty)

### 3. start.sh (hook)
Starts the agent + welcome message + optional MCP detection

## Agent selection

```bash
# use a specific agent
./agentbox --agent=opencode

# default agent (claude-code, fallback: opencode)
./agentbox
```

## Troubleshooting

### Agent not found
```
ERROR: Agent 'my-agent' not found in agents.d/
```
**Fix**: Ensure the `agents.d/my-agent/` directory exists.

### install.sh missing
```
ERROR: Agent my-agent incomplete: install.sh missing
```
**Fix**: Provide both hooks and the config file.

### config error
```
ERROR: Agent config did not set VOLUME_NAME
```
**Fix**: The `config` file must define all three variables.

### Permission denied
```
bash: ./agents.d/my-agent/install.sh: Permission denied
```
**Fix**: Make the scripts executable on the host:
```bash
chmod +x agents.d/my-agent/*.sh
```

### chmod operation not permitted (during Docker build)
```
chmod: changing permissions of '/opt/agentbox/agents.d/my-agent/install.sh': Operation not permitted
```
**Cause**: The scripts already had the correct permissions when copied from the host.
**Fix**: Ensure they are executable locally (`chmod +x`). Docker's `COPY` preserves permissions, so avoid redundant `chmod` in the Dockerfile or entrypoint.

## Additional documentation

- **Architecture**: `../HOOK_ARCHITECTURE.md`
- **Implementation plan**: `../HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`
- **Template guide**: `.template/README.md`
- **Development notes**: `../DEVELOPMENT_NOTES.md`
