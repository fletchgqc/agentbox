# AgentBox Operational Guidance

This document consolidates operational instructions that agents only need to consult when running builds/tests, selecting agents. Refer to this file only when that deeper context is required.

## Build/Test Commands
- **No automated tests exist**: Test manually using `./agentbox --help` and `./agentbox shell`.
- **Lint/Format**: No linters configured; treat as a Bash project.
- **Build**: Docker image rebuilds automatically whenever `Dockerfile` or `entrypoint.sh` changes.
- **Manual rebuild**: Run `./agentbox --rebuild`.

## Agent Selection

AgentBox supports multiple CLI agents via a hook-based architecture. Full details live in `HOOK_ARCHITECTURE.md`.

### Available Agents
- **opencode** – Open-source AI agent (75+ LLM providers).
- **claude-code** – Anthropic's Claude Code (planned).

### Select Agent
```bash
./agentbox --agent=opencode           # Pick specific agent
./agentbox --rebuild --agent=opencode # Force rebuild with agent
./agentbox                            # Default (claude-code, fallback: opencode)
```

### Add New Agent
See `agents.d/README.md` for the canonical step-by-step instructions on adding agents.

## Architecture Notes
- **Hook-based agents**: Each agent ships `install.sh`, `start.sh`, and a `config` file.
- **Ephemeral containers**: Containers run with `--rm` and are destroyed on exit.
- **Hash-based naming**: Container names use `SHA256(project_path)[0:12]`.
- **No prompts**: All actions run automatically aside from initial SSH setup.
- **Simplicity first**: Keep scope tight; avoid ClaudeBox-style feature creep.
