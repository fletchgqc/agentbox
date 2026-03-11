# Plugin System Specification

## Problem Statement

Current agentbox uses a single Dockerfile containing all possible dev tools, leading to:
- Large image size
- Risk of version conflicts between projects (e.g., different JDK versions)
- Unnecessary tools in every container

## Solution Overview

Implement a module system allowing per-project tool configuration while maintaining fast container startup times through pre-built images.

## Architecture

### 1. Base Image

Minimal Dockerfile containing:
- Linux base
- Basic C dev tools
- Python (AI agent default)
- Claude Code and OpenCode

Language-specific tools are stripped from the current Dockerfile and converted to modules.

### 2. Module System

#### Module Location

Modules are searched in order of precedence:
1. `~/.agentbox/modules/` (user custom modules)
2. `<agentbox-repo>/modules/` (built-in modules)

#### Module Structure

```
modules/
  nodejs/
    20.dockerfile
    20.mounts (optional)
    20.env (optional)
    22.dockerfile
    22.mounts
    ...
  java/
    17.dockerfile
    17.mounts
    17.env
    21.dockerfile
    ...
```

If a module manages its own version, like for example rustup, just use the files without a version

```
modules/
  rust/
    dockerfile
    mounts (optional)
    env (optional)
```

#### Module File Formats

**Dockerfile** (`<version>.dockerfile`):
```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get install -y nodejs
```

**Mounts** (`<version>.mounts`):
```
~/.npm:/root/.npm
~/.cache/node:/root/.cache/node
```
Each line: `<host-path>:<container-path>`

**Environment** (`<version>.env`):
```
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH
```
Each line: `<VAR>=<value>`

#### Module Capabilities

Modules can specify:
- Dockerfile instructions (required)
- Volume mounts (optional)
- Environment variables (optional)

Modules cannot specify:
- Exposed ports
- Docker run flags
- Entrypoint/CMD modifications

### 3. Project Configuration

#### Configuration File

- **Name**: `.agentbox`
- **Format**: YAML
- **Discovery**: Search upward from current working directory until found (like `.git`)

#### Configuration Syntax

```yaml
modules:
  - nodejs:20
  - java:17
  - rust
```

Since rustup manages its version on its own, no version number is needed for `rust`.

### 4. Image Management

#### Image Naming

Format: `agentbox:<hash-of-full-project-path>`

Example: `agentbox:7a3f9c2e` (hash of `/home/user/projects/myapp`)

#### Image Composition

Image built from:
1. Base Dockerfile
2. Selected module `.dockerfile` files (in order specified)

Container configured with:
- Current working directory mounted
- Module-specified volume mounts
- Module-specified environment variables

#### Image Reuse

Images are locked to the directory path. If two projects have identical `.agentbox` configurations but different paths, separate images are created.

Optional optimization: Detect and reuse identical module combinations (not required for initial implementation).

### 5. Build Behavior

On `agentbox` execution:

1. **Locate configuration**: Search upward from cwd for `.agentbox`
2. **Validate modules**: Check all requested modules exist in search paths
3. **Check rebuild trigger**:
   - Base Dockerfile modified (hash/timestamp)
   - Any referenced module definition modified
   - `.agentbox` config modified
   - Target image doesn't exist
4. **Build if needed**: Create image with hash-based tag
5. **Run container**: Start container with configured mounts and environment

### 6. Error Handling

#### Missing Module

```
Error: Module not found: java:21

Searched in:
  - /home/user/.agentbox/modules/java/21.dockerfile
  - /opt/agentbox/modules/java/21.dockerfile

Available java versions:
  - 17
```

#### Invalid Configuration

```
Error: Invalid .agentbox syntax

File: /home/user/project/.agentbox
Line 3: Expected 'modules:' key at root level
```

#### Module Conflicts

Build and let Docker/tooling handle conflicts. If build fails, surface Docker error.

Example: Two modules both try to install conflicting packages → Docker build fails with clear error.

## Non-Requirements

The following are explicitly out of scope:

- Port exposure configuration
- Custom Docker run flags (e.g., `--privileged`)
- Entrypoint/CMD modifications
- Automatic image sharing across projects with identical configs
- Module dependency resolution
- Module versioning/updates

## Migration Strategy

1. Use existing Dockerfile as starting point for base image
2. Strip language-specific tooling into initial built-in module set
3. Add all modules for the languages that are currently included in the `Dockerfile`
4. Existing single-Dockerfile workflow continues to work during transition

## Success Criteria

- Projects can specify different tool versions without conflicts
- Container startup time remains fast (tools pre-installed in image)
- Clear, actionable error messages when configuration invalid
- Users can add custom modules without modifying agentbox repository
- Module definitions are simple and maintainable

## Future Considerations

Not planned for initial implementation, but possible future enhancements:

- Module dependency declaration (e.g., `maven` requires `java`)
- Module aliases (e.g., `node` → `nodejs`)
- Remote module repositories
- Module update notifications
- Shared base layers across projects with overlapping modules
