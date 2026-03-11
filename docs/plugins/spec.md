# Plugin System Specification

## Problem Statement

Current agentbox uses a single Dockerfile containing all possible dev tools, leading to:
- Large image size (~2GB)
- Risk of version conflicts between projects (e.g., different JDK versions)
- Unnecessary tools in every container
- Difficulty maintaining multiple language versions

## Solution Overview

Transform agentbox into a modular system where projects specify required development tools via a `.agentbox` configuration file. Each project gets a custom-built image with only the needed modules, while maintaining fast container startup through pre-built images with hash-based rebuild detection.

## Architecture

### 1. Base Image

**File**: `Dockerfile.base`

Contains only:
- Linux base (Debian Trixie)
- Essential tools (git, vim, curl, wget, jq, yq, etc.)
- Build tools (gcc, make, cmake, build-essential)
- Python (with uv) - AI agent default language
- Claude Code and OpenCode
- User setup (`agent` user with UID 1000, sudo access)
- Shell configuration (bash, zsh)

**User Context**: All tools installed as/for `agent` user in `/home/agent/`. Modules continue as `USER agent` (no root escalation needed).

Language-specific tools (Node.js, Java, Rust, etc.) are stripped from the current Dockerfile and converted to modules.

### 2. Module System

#### Module Location

Modules are searched in order of precedence:
1. `~/.agentbox/modules/` (user custom modules)
2. `<agentbox-repo>/modules/` (built-in modules)

**Security Validation**:
- Module names must match `^[a-z0-9_-]+$` (lowercase alphanumeric, underscores, hyphens only)
- Path traversal attempts (`/`, `..`, absolute paths) are rejected
- Module directories must not be symlinks outside `~/.agentbox/` or agentbox repo
- File integrity: reject empty files, files >1MB, non-regular files (devices, symlinks)

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
~/.npm:/home/agent/.npm
~/.cache/node:/home/agent/.cache/node
```
Each line: `<host-path>:<container-path>`

**Mount Security**: Paths validated with whitelist (only `~/.cache/`, `~/.config/`, `~/.npm/`, `~/.m2/`, `~/.gradle/`, `~/.cargo/`, `~/.rustup/`, `~/.sdkman/`, `~/.nvm/` allowed). Sensitive paths blacklisted (`/var/run/docker.sock`, `/etc/`, `/sys/`, `/proc/`, `/dev/`). Missing host directories created automatically with mode 0755.

**Environment** (`<version>.env`):
```
NVM_DIR=/home/agent/.nvm
PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH
```
Each line: `<VAR>=<value>`

**Environment Security**: Blacklist: `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DOCKER_HOST`, `DOCKER_TLS_VERIFY`, `DOCKER_CERT_PATH`. PATH validation ensures no `.` or `./` entries, no writable system paths.

**PATH Merging**: When multiple modules define PATH, all prepends are combined in module order:
```bash
# Module 1: nodejs → PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH
# Module 2: java   → PATH=/home/agent/.sdkman/candidates/java/current/bin:$PATH
# Result:          → PATH=/home/agent/.nvm/.../bin:/home/agent/.sdkman/.../bin:$PATH
```

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

#### No-Config Fallback

If `.agentbox` file is not found after searching upward to `/`:
- Build image from `Dockerfile.base` only (no modules)
- Image named `agentbox:base`
- User can explicitly request base-only with empty `modules:` list

### 4. Image Management

#### Image Naming

Format: `agentbox:<config-hash>`

**Hash Calculation**: SHA-256 hash (first 8 characters) of:
1. Absolute path to directory containing `.agentbox` (project root)
2. Content of `.agentbox` config file
3. Content of `Dockerfile.base`
4. Content of all referenced module files (`.dockerfile`, `.mounts`, `.env`)

Examples:
- `agentbox:7a3f9c2e` (project with nodejs:20, java:17)
- `agentbox:base` (no `.agentbox` found)

#### Image Composition

Image built from:
1. Base Dockerfile
2. Selected module `.dockerfile` files (in order specified)

Container configured with:
- Current working directory mounted
- Module-specified volume mounts
- Module-specified environment variables

#### Rebuild Detection

Image stores combined hash in label: `agentbox.build.hash=<sha256-of-all-inputs>`

Rebuild triggers:
1. Target image doesn't exist
2. Image has no `agentbox.build.hash` label
3. Stored hash ≠ current hash

**Concurrent Build Protection**: Docker's native locking handles concurrent builds. Later build wins (overwrites tag).

#### Image Reuse

Projects with identical configs in different directories will have different hashes (path included). This is intentional - allows projects to diverge independently.

### 5. Build Behavior

On `agentbox` execution:

1. **Locate configuration**: Search upward from cwd for `.agentbox`
   - If not found: use base image only (no modules)
2. **Parse and validate config**:
   - Check YAML syntax
   - Validate module names (format `name:version` or `name`)
   - Normalize to lowercase
   - Check for duplicates
3. **Validate modules**: Verify all requested modules exist in search paths
4. **Calculate hash**: Combine all build inputs (see Hash Calculation above)
5. **Check rebuild trigger**: Compare hash with image label
6. **Build if needed**: Generate temporary Dockerfile, build with hash-based tag
7. **Run container**: Start container with configured mounts and environment

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

#### Security Violations

```
Error: Insecure mount path in module nodejs:20
Path: /etc/passwd:/container/etc/passwd
Reason: Absolute paths outside user home are not allowed

Allowed prefixes: ~/.cache, ~/.config, ~/.npm, ~/.m2, ~/.gradle, ~/.cargo

Error: Blocked environment variable in module custom:1
Variable: LD_PRELOAD=/malicious/lib.so
Reason: LD_PRELOAD is blacklisted for security

Blocked variables: LD_PRELOAD, LD_LIBRARY_PATH, DOCKER_HOST, DOCKER_TLS_VERIFY
```

#### Duplicate Modules

```
Error: Duplicate module in .agentbox
Module: nodejs:20 (appears 2 times)
```

#### Module Conflicts

Build and let Docker/tooling handle conflicts. If build fails, surface Docker error.

Example: Two modules both try to install conflicting packages → Docker build fails with clear error.

## Module Discovery CLI

New commands for exploring available modules:

```bash
agentbox modules list              # Show all available modules
agentbox modules list nodejs       # Show nodejs versions
agentbox modules info nodejs:20    # Show module details
```

**Example Output**:
```
$ agentbox modules list
Available modules:

nodejs:
  - 20
  - 22

java:
  - 17
  - 21

rust (version managed by rustup)

$ agentbox modules info nodejs:20
Module: nodejs:20
Location: /opt/agentbox/modules/nodejs/20.dockerfile

Mounts:
  ~/.npm -> /home/agent/.npm

Environment:
  NVM_DIR=/home/agent/.nvm
  PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH

Installs:
  - Node.js 20 (via nvm)
  - npm global: typescript, ts-node, eslint, prettier, yarn, pnpm
```

## Security Model

### Trust Boundary

**Modules execute arbitrary code during build**. Users are responsible for auditing custom modules like any software installation.

- **Built-in modules**: Trusted (maintained by agentbox)
- **Custom modules**: User responsibility to audit
- **Cannot prevent**: Malicious Dockerfile instructions (by design)
- **Defense-in-depth**: Mount/env validation provides additional protection layer

### Validation Layers

1. **Module Name Validation**: Prevent path traversal (`^[a-z0-9_-]+$`)
2. **Module Directory Validation**: Reject symlinks to system directories
3. **Mount Path Validation**: Whitelist home directories, blacklist sensitive paths
4. **Environment Variable Validation**: Blacklist injection vectors
5. **File Integrity**: Verify file types, sizes, permissions

### Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Malicious custom modules | High | Users audit modules; prominent documentation warning |
| PATH injection | Medium | Validate no `.` or `./` entries, restrict to home paths |
| Path traversal | Medium | Validate module names and mount paths |
| Environment injection | Medium | Blacklist critical variables, sanitize values |
| Hash collision | Low | Use SHA-256 with 8-char prefix (1 in 4B collision risk) |

## Initial Module Set

Built-in modules extracted from current Dockerfile:

### nodejs/20
- Node.js 20 via nvm
- Global packages: typescript, ts-node, eslint, prettier, yarn, pnpm
- Mounts: `~/.npm`
- Environment: `NVM_DIR`, `PATH`

### nodejs/22
- Node.js 22 via nvm
- Same global packages
- Separate mount for npm cache

### java/17
- Java 17 via SDKMAN
- Gradle and Maven via SDKMAN
- Mounts: `~/.m2`, `~/.gradle`
- Environment: `SDKMAN_DIR`, `PATH`

### java/21
- Java 21 via SDKMAN
- Same build tools
- Separate caches

### rust
- Rust via rustup (manages own version)
- Mounts: `~/.cargo`, `~/.rustup`
- Environment: `CARGO_HOME`, `RUSTUP_HOME`, `PATH`

## Non-Requirements

The following are explicitly out of scope:

- Port exposure configuration
- Custom Docker run flags (e.g., `--privileged`)
- Entrypoint/CMD modifications
- Module dependency resolution
- Module versioning/updates
- Automatic migration from monolithic Dockerfile

## Migration Strategy

1. Use existing Dockerfile as starting point for base image
2. Strip language-specific tooling into initial built-in module set
3. Add all modules for the languages that are currently included in the `Dockerfile`
4. Existing single-Dockerfile workflow continues to work during transition
5. Keep current `Dockerfile` as `Dockerfile.legacy` during development
6. After stable release, `Dockerfile.base` becomes primary

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
