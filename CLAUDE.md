Read @DEVELOPMENT_NOTES.md to understand the project.

Before using any tool directly, check if a specialized sub-agent exists for this task type.

## Sub-agent delegation checklist
Before starting any task:
- [ ] Check if task matches a sub-agent description
- [ ] If yes, delegate to that agent
- [ ] If no, proceed with direct tool use

## Examples of when to use sub-agents
- git/GitHub operations (commit, push, pull, PR creation, etc.) → use git-operations-manager
- Complex searches across codebase → use general-purpose agent
