# AgentBox - Agent Guide

## Orientation
- Treat this file as the single source of truth for agent instructions.
- Read `DEVELOPMENT_NOTES.md` before starting work to understand project context.

## Collaboration Style
- Exercise full agency to push back on mistakes. Flag issues early, ask questions if unsure of direction instead of choosing randomly.
- Eliminate emojis, praise, filler, hype.
- Don't flatter me. Give me honest feedback even if I don't want to hear it.

## Code Style

### Bash Script (agentbox)
- **Bash version**: Requires Bash 4.0+ (enforced in script)
- **Error handling**: Use `set -euo pipefail` at script start
- **Readonly vars**: Configuration constants marked `readonly`
- **Function naming**: snake_case (e.g., `check_docker`, `build_image`)
- **Logging**: Use helper functions `log_info`, `log_error`, `log_success`, `log_warning`, `log_build`
- **Validation**: Fail early with clear error messages, batch validation errors when possible

### Code comments
Code comments are used sparingly in this project, since they add to code bloat. Comprehensible and expressive code (eg. consistent, logical naming) is preferred to comments.

Comments are still added when they contribute to much faster, better understanding in two cases:
- To explain why something was done, when it is not apparent from the context.
- To explain what is being done, if the code is necessarily difficult to understand for an advanced programmer or agent.

If a log line is written explaining what is happening, any comment above that line which essentially says the same thing is removed, since a developer has the same information from the log line.

Developers challenge comments to ensure they match the criteria. Existing comments are cleaned up according to the boy-scout rule.

### Documentation
The user documentation (README.md, DEVELOPMENT_NOTES.md) is concise, delivering maximum meaning with a minimum amount of words and examples.

The documentation follows these principles:

- assume the reader is a knowledgeable developer.
    - good: document each available command line flag, assume reader will combine as needed.
    - bad: give examples of many combinations command-line flags.
- document agentbox-specific knowledge, do not replicate standard claude code documentation.
    - good: "mcp servers are supported according to standard syntax"
    - bad: "here is the syntax of a claude code mcp server file"
- aim to inform the user of genuinely important/helpful information, not promote the project by listing every internal implementation detail.
- weigh additions against the knowledge that the longer the documentation is, the less likely that anyone will read it at all.

## Skills and Sub-agents
- Before starting a task, check if a relevant skill or sub-agent exists and delegate if appropriate.

## Architecture Notes
- **Hook-based agents**: Each agent ships `install.sh`, `start.sh`, and a `config` file.
- **Ephemeral containers**: Containers run with `--rm` and are destroyed on exit.
- **Hash-based naming**: Container names use `SHA256(project_path)[0:12]`.
- **No prompts**: All actions run automatically aside from initial SSH setup.
- **Simplicity first**: Keep scope tight; avoid ClaudeBox-style feature creep.

### Add New Agent
See `agents.d/README.md` for step-by-step instructions.

## Operational References (read on demand)
- Detailed instructions for build/test workflows and agent selection live in `docs/ops-guidance.md`. Only open that file when you actively need those specifics.
