# AgentBox - Agent Guide

## Required Context
- Read `DEVELOPMENT_NOTES.md` before starting any task to stay aligned with current expectations.

## Collaboration Style
- Exercise full agency: push back on mistakes, flag issues early, ask when direction is unclear.
- Keep communication direct—no emojis, hype, praise, or flattery.
- Give blunt, honest feedback even when it is uncomfortable; accuracy beats politeness.

## Build/Test Commands
- **No automated tests exist**: Test manually using `./agentbox --help` and `./agentbox shell`
- **Lint/Format**: No linters configured - this is a Bash project
- **Build**: Docker image builds automatically on first run or when Dockerfile/entrypoint.sh changes
- **Manual rebuild**: `./agentbox --rebuild`

## Code Style

### Bash Script (agentbox)
- **Bash version**: Requires Bash 4.0+ (enforced in script)
- **Error handling**: Use `set -euo pipefail` at script start
- **Readonly vars**: Configuration constants marked `readonly`
- **Function naming**: snake_case (e.g., `check_docker`, `build_image`)
- **Logging**: Use helper functions `log_info`, `log_error`, `log_success`, `log_warning`, `log_build`
- **Validation**: Fail early with clear error messages, batch validation errors when possible

### Comments
- Comments add code bloat—default to expressive naming and clear structure instead.
- Only add comments to explain **why** something was done (when not apparent from context) or **what** is occurring when the code is necessarily complex.
- If a log line communicates the same information, delete the redundant comment.
- Continuously challenge and clean up existing comments according to the boy-scout rule.

### Documentation (README.md, DEVELOPMENT_NOTES.md)
- Keep docs concise: maximum meaning with minimum words.
- Assume a knowledgeable developer: document each command-line flag; let readers combine flags themselves.
- Focus on agentbox-specific knowledge—reference standard tooling instead of re-explaining it.
- Share only genuinely helpful information; longer docs are less likely to be read.

## Skills and Sub-agents
- Before starting a task, check whether a relevant skill or sub-agent exists and delegate when appropriate.

## Architecture Notes
- **Ephemeral containers**: `--rm` flag, destroyed on exit
- **Hash-based naming**: Container names use SHA256(project_path)[0:12]
- **No prompts**: Everything automatic (except initial SSH setup)
- **Simplicity first**: Resist feature creep vs ClaudeBox complexity
