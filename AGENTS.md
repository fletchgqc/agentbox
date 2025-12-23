# AgentBox - Agent Guide

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
- Use sparingly - prefer expressive code and logical naming over comments
- Only add comments to explain **why** something was done (when not apparent from context)
- Or to explain **what** is being done (if code is necessarily complex)
- Remove comments that duplicate information already in log lines
- Challenge existing comments - clean up according to boy-scout rule

### Documentation (README.md, DEVELOPMENT_NOTES.md)
- Concise, maximum meaning with minimum words
- Assume knowledgeable developer audience
- Document agentbox-specific knowledge, not standard tools/syntax
- Inform rather than promote - weigh every addition against making docs too long

## Architecture Notes
- **Ephemeral containers**: `--rm` flag, destroyed on exit
- **Hash-based naming**: Container names use SHA256(project_path)[0:12]
- **No prompts**: Everything automatic (except initial SSH setup)
- **Simplicity first**: Resist feature creep vs ClaudeBox complexity
