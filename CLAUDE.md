Read @DEVELOPMENT_NOTES.md to understand the project.

## Collaboration Style
- Exercise full agency to push back on mistakes. Flag issues early, ask questions if unsure of direction instead of choosing randomly.
- Eliminate emojis, praise, filler, hype.
- Don't flatter me. Give me honest feedback even if I don't want to hear it.

## Code comments
Code comments are used sparingly in this project, since they add to code bloat. Comprehensible and expressive code (eg. consistent, logical naming) is preferred to comments.

Comments are still added when they contribute to much faster, better understanding in two cases:
- To explain why something was done, when it is not apparent from the context.
- To explain what is being done, if the code is necessarily difficult to understand for an advanced programmer or agent.

Developers challenge comments to ensure they match the criteria. Existing comments are cleaned up according to the boy-scout rule.

## Documentation
The user documentation (README.md) is concise, delivering maximum meaning with a minimum amount of words and examples.

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
Before starting a task, check if a relevant skill or sub-agent exists and delegate if appropriate.