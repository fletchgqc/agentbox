# Plugin System Implementation Plan

## Overview

Transform agentbox from a monolithic Dockerfile to a modular system where projects can specify required development tools via a `.agentbox` configuration file.

## Implementation Phases

### Phase 1: Module Infrastructure & Security

#### 1.1 Create Module Directory Structure

Create the basic module system infrastructure:

```
modules/
  nodejs/
    20.dockerfile
    20.mounts
    22.dockerfile
  java/
    17.dockerfile
    17.mounts
    17.env
    21.dockerfile
  rust/
    dockerfile
    mounts
```

**Tasks:**
- Create `modules/` directory in agentbox repo
- Define module file format specification
- Document that modules install tools as `agent` user in `/home/agent/`

#### 1.2 Module Loading & Validation System

Create bash functions with integrated security validation:

**New Functions:**
```bash
# Module discovery
find_module()              # Locate module by name:version
list_available_versions()  # For error messages

# Security validation
validate_module_name()     # Prevent path traversal (^[a-z0-9_-]+$)
validate_module_directory() # Reject symlinks outside ~/.agentbox/
validate_mount_path()      # Whitelist home prefixes, reject sensitive paths
validate_env_var()         # Blacklist LD_PRELOAD, DOCKER_HOST, etc.

# Module loading (includes validation)
load_module()              # Load and validate all module files
load_module_dockerfile()   # Return Dockerfile instructions
load_module_mounts()       # Return validated mount specifications
load_module_env()          # Return validated environment variables

# Error handling
show_module_error()        # Display helpful error with available versions
```

**Module Name Security:**
- Format: `^[a-z0-9_-]+$` (lowercase only for consistency)
- Reject: `/`, `..`, absolute paths
- Case-insensitive lookup (convert to lowercase)

**Module Directory Security:**
- Verify module directories are not symlinks
- If symlink, verify target is within `~/.agentbox/` or agentbox repo
- Reject symlinks to system directories

**Mount Path Security:**
- Expand `~` to `$HOME` before validation
- Whitelist: `~/.cache/`, `~/.config/`, `~/.npm/`, `~/.m2/`, `~/.gradle/`, `~/.cargo/`, `~/.rustup/`, `~/.sdkman/`, `~/.nvm/`
- Blacklist: `/var/run/docker.sock`, `/etc/`, `/sys/`, `/proc/`, `/dev/`
- Reject: paths with `..`, absolute paths outside home
- Create missing directories with mode 0755
- Fail if path exists as file (not directory)
- Fail if directory creation fails (permissions)

**Environment Variable Security:**
- Blacklist: `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DOCKER_HOST`, `DOCKER_TLS_VERIFY`, `DOCKER_CERT_PATH`
- Validate `PATH`: no `.` or `./` entries, no writable system paths
- Support `$VAR` references to existing env vars
- Variables processed in module order (later modules can reference earlier ones)

**PATH Variable Merging:**
When multiple modules define `PATH`:
```bash
# Module 1: nodejs
PATH=$HOME/.nvm/versions/node/v20/bin:$PATH

# Module 2: java
PATH=$HOME/.sdkman/candidates/java/current/bin:$PATH

# Result: prepend all module paths in order
PATH=$HOME/.nvm/versions/node/v20/bin:$HOME/.sdkman/candidates/java/current/bin:$PATH
```

Logic:
1. Parse each module's PATH value
2. Extract the prepend portion (before `:$PATH`)
3. Combine all prepends in module order
4. Set final PATH with all prepends + original container PATH

**File Integrity Checks:**
- Verify `.dockerfile` exists and is readable
- Verify `.mounts` and `.env` are readable (if present)
- Check files are regular files (not symlinks, devices, etc.)
- Validate file size (reject empty or >1MB files)
- Fail early with actionable error

**Error Messages:**
```
Error: Module not found: java:21

Searched in:
  - /home/user/.agentbox/modules/java/21.dockerfile
  - /opt/agentbox/modules/java/21.dockerfile

Available java versions:
  - 17

Error: Insecure mount path in module nodejs:20
Path: /etc/passwd:/container/etc/passwd
Reason: Absolute paths outside user home are not allowed

Allowed prefixes: ~/.cache, ~/.config, ~/.npm, ~/.m2, ~/.gradle, ~/.cargo

Error: Blocked environment variable in module custom:1
Variable: LD_PRELOAD=/malicious/lib.so
Reason: LD_PRELOAD is blacklisted for security

Blocked variables: LD_PRELOAD, LD_LIBRARY_PATH, DOCKER_HOST, DOCKER_TLS_VERIFY
```

### Phase 2: Configuration System

#### 2.1 Config File Discovery & No-Config Fallback

Implement upward search for `.agentbox` file:

**New Function:**
```bash
find_agentbox_config()  # Search upward from cwd, like .git
```

**Logic:**
- Start in current directory
- Search upward until `.agentbox` found or reach `/`
- Return path to config file or empty if not found
- If not found: use base image only (no modules)

**No-Config Behavior:**
- Missing `.agentbox`: build image with base Dockerfile only
- Empty `modules:` list: same as missing file
- User can explicitly request base-only with empty modules list

#### 2.2 Config File Parser & Validation

Parse and validate YAML `.agentbox` configuration:

**New Function:**
```bash
parse_agentbox_config()  # Parse YAML, extract and validate modules
```

**Validation Steps:**
1. Check YAML syntax (use `yq` with error handling)
2. Verify `modules:` key exists
3. Extract module list
4. For each module:
   - Validate format: `name:version` or `name`
   - Normalize name to lowercase
   - Validate name with `validate_module_name()`
   - Check for duplicates
5. Return validated module list

**Error Handling:**
```
Error: Invalid .agentbox syntax

File: /home/user/project/.agentbox
Line 3: Expected 'modules:' key at root level

Error: Duplicate module in .agentbox
Module: nodejs:20 (appears 2 times)
```

### Phase 3: Dynamic Image Building

#### 3.1 Refactor Base Dockerfile

Create `Dockerfile.base` containing only:
- Linux base (Debian Trixie)
- Essential tools (git, vim, curl, wget, jq, yq, etc.)
- Build tools (gcc, make, cmake, build-essential)
- Python (with uv)
- Claude Code and OpenCode
- User setup (`agent` user with sudo)
- Shell configuration (bash, zsh)

**User Context:**
- All tools installed as/for `agent` user
- Installation directories: `/home/agent/.nvm`, `/home/agent/.sdkman`, etc.
- Modules continue as `USER agent` (no root escalation needed)

**Tasks:**
- Strip language-specific installations from current Dockerfile
- Create `Dockerfile.base`
- Keep current Dockerfile as `Dockerfile.legacy` during transition

#### 3.2 Dynamic Dockerfile Generation

Generate project-specific Dockerfiles on-the-fly:

**New Function:**
```bash
generate_dockerfile()  # Build Dockerfile from base + modules
```

**Logic:**
1. Start with `Dockerfile.base` content
2. For each module in `.agentbox` (in order):
   - Load module's `.dockerfile` content
   - Append to combined Dockerfile
3. Write to temporary file in `/tmp/agentbox-build-XXXXXX/`
4. Return path to generated Dockerfile

**Generated Dockerfile Structure:**
```dockerfile
# From Dockerfile.base
FROM debian:trixie
...
USER agent

# From modules/nodejs/20.dockerfile
ENV NVM_DIR="/home/agent/.nvm"
RUN curl -o- ... | bash
...

# From modules/java/17.dockerfile
RUN curl -s "https://get.sdkman.io" | bash
...
```

#### 3.3 Image Naming and Hashing

**Image Naming:**
Format: `agentbox:<config-hash>`

**Hash Calculation:**
```bash
get_image_hash()  # Calculate hash of all build inputs
```

Combine and hash:
1. Absolute path to directory containing `.agentbox` (project root)
2. Content of `.agentbox` config file
3. Content of `Dockerfile.base`
4. Content of all referenced module files (`.dockerfile`, `.mounts`, `.env`)

Use first 8 characters of SHA-256 hash.

**Examples:**
- `agentbox:7a3f9c2e` (project with nodejs:20, java:17)
- `agentbox:base` (no `.agentbox` found, base-only)

**Image Reuse:**
Projects with identical configs in different directories will have different hashes (path included). This is intentional - allows projects to diverge independently.

### Phase 4: Rebuild Detection

**Modify Function:**
```bash
needs_rebuild()
```

**Simplified Approach:**
Store single combined hash in image label:
```
agentbox.build.hash=<sha256-of-all-inputs>
```

**Rebuild Triggers:**
1. Target image doesn't exist
2. Image has no `agentbox.build.hash` label
3. Stored hash ≠ current hash (calculated by `get_image_hash()`)

**Hash Input Changes:**
- `.agentbox` config modified
- `Dockerfile.base` modified
- Any referenced module file modified
- Project directory path changed

**Concurrent Build Protection:**
Use Docker's native locking:
```bash
docker build --tag "$image_name" --iidfile /tmp/build-$$.iid ...
```

If concurrent build occurs, Docker handles it. Later build wins (overwrites tag).

### Phase 5: Runtime Configuration

#### 5.1 Module Mounts Integration

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. For each module in `.agentbox` (in order):
   - Load mounts from `.mounts` file
   - For each mount `host:container`:
     - Validate with `validate_mount_path()`
     - Expand `~` to `$HOME`
     - If host path missing: create directory (fail if creation fails)
     - Verify host path is directory
     - Add `-v host:container` to mount_opts
2. Add mounts to docker run command

#### 5.2 Module Environment Variables Integration

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. Initialize env_vars array
2. For each module in `.agentbox` (in order):
   - Load environment from `.env` file
   - For each `VAR=value`:
     - Validate with `validate_env_var()`
     - If `VAR=PATH`: merge with existing PATH (prepend logic)
     - Else: store variable
3. Add all variables with `-e VAR=value` to docker run command

**PATH Merging Example:**
```bash
# Module 1: nodejs
PATH=$HOME/.nvm/versions/node/v20/bin:$PATH

# Module 2: java
PATH=$HOME/.sdkman/candidates/java/current/bin:$PATH

# Generated docker run:
-e PATH=/home/agent/.nvm/versions/node/v20/bin:/home/agent/.sdkman/candidates/java/current/bin:$PATH
```

### Phase 6: Initial Module Set

Extract language modules from current Dockerfile:

#### nodejs/20.dockerfile
```dockerfile
# Install Node.js via NVM as agent user
ENV NVM_DIR="/home/agent/.nvm"
RUN NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install 20 && \
    nvm alias default 20 && \
    nvm use default && \
    npm install -g typescript ts-node eslint prettier yarn pnpm

RUN echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
```

#### nodejs/20.mounts
```
~/.npm:/home/agent/.npm
```

#### nodejs/20.env
```
NVM_DIR=/home/agent/.nvm
PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH
```

#### java/17.dockerfile
```dockerfile
# Install Java 17 via SDKMAN as agent user
RUN curl -s "https://get.sdkman.io?rcupdate=false" | bash && \
    bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
        sdk install java 17.0.9-tem && \
        sdk install gradle && \
        sdk install maven"

RUN echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc
```

#### java/17.mounts
```
~/.m2:/home/agent/.m2
~/.gradle:/home/agent/.gradle
```

#### java/17.env
```
SDKMAN_DIR=/home/agent/.sdkman
PATH=/home/agent/.sdkman/candidates/java/current/bin:/home/agent/.sdkman/candidates/gradle/current/bin:/home/agent/.sdkman/candidates/maven/current/bin:$PATH
```

#### rust/dockerfile
```dockerfile
# Install Rust via rustup as agent user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc && \
    echo 'source "$HOME/.cargo/env"' >> ~/.zshrc
```

#### rust/mounts
```
~/.cargo:/home/agent/.cargo
~/.rustup:/home/agent/.rustup
```

#### rust/env
```
CARGO_HOME=/home/agent/.cargo
RUSTUP_HOME=/home/agent/.rustup
PATH=/home/agent/.cargo/bin:$PATH
```

### Phase 7: Module Discovery CLI

Add commands for users to explore available modules:

**New Functions:**
```bash
cmd_modules_list()      # List all modules or filter by name
cmd_modules_info()      # Show details for specific module:version
```

**Commands:**
```bash
agentbox modules list              # Show all available modules
agentbox modules list nodejs       # Show nodejs versions
agentbox modules info nodejs:20    # Show module details
```

**Output Examples:**
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

### Phase 8: Documentation

#### 8.1 Update README

Add sections:
- Module system overview
- `.agentbox` configuration syntax
- Available built-in modules
- Creating custom modules (link to guide)

#### 8.2 Module Development Guide

Create `docs/plugins/module-development.md`:

**Contents:**
- Module file format specification
- User context (`agent` user, `/home/agent/` paths)
- PATH merging behavior
- Security guidelines:
  - **Warning:** Modules execute arbitrary code during build
  - Built-in modules are trusted (maintained by agentbox)
  - Audit custom modules like any software installation
  - Cannot validate Dockerfile instructions (by design)
  - Mount/env validation provides defense-in-depth only
- Testing modules locally
- Contributing modules to agentbox

#### 8.3 Migration Guide

Create `docs/plugins/migration.md`:
- How to migrate from monolithic Dockerfile
- Example `.agentbox` configurations
- Common issues (PATH not set, mounts missing, etc.)
- How to verify module setup

## Implementation Order

### Milestone 1: Core Infrastructure
- Phase 1: Module Infrastructure & Security (1.1, 1.2)
- Phase 2: Configuration System (2.1, 2.2)
- Test: Load module, validate security, parse config

### Milestone 2: Dynamic Building
- Phase 3: Dynamic Image Building (3.1, 3.2, 3.3)
- Phase 4: Rebuild Detection
- Test: Build image with single module

### Milestone 3: Runtime & Modules
- Phase 5: Runtime Configuration (5.1, 5.2)
- Phase 6: Initial Module Set
- Test: Run container with nodejs:20, verify mounts and PATH

### Milestone 4: Polish & Documentation
- Phase 7: Module Discovery CLI
- Phase 8: Documentation (8.1, 8.2, 8.3)
- Test: User acceptance testing

## Testing Strategy

### Security Tests
- Reject path traversal: `../../etc/passwd`, `../malicious`
- Reject symlinks to system dirs
- Reject sensitive mounts: `/var/run/docker.sock`, `/etc/`
- Reject blacklisted env vars: `LD_PRELOAD`, `DOCKER_HOST`
- Reject PATH with `.` or `./`
- Handle missing file permissions gracefully
- Verify built-in modules pass validation

### Module Loading Tests
- Load module with all files present
- Load module with only .dockerfile
- Reject module with missing .dockerfile
- Reject empty .dockerfile
- Reject oversized module file (>1MB)
- Case-insensitive module lookup: `NodeJS:20` → `nodejs:20`

### Config Parsing Tests
- Valid YAML with modules
- Empty modules list → base image only
- Missing .agentbox → base image only
- Duplicate modules → error
- Invalid module name → error
- Malformed YAML → error

### Build Tests
- Build with single module (nodejs:20)
- Build with multiple modules (nodejs:20 + java:17)
- Build with versionless module (rust)
- Verify PATH merging: nodejs + java both add to PATH
- Rebuild only when needed (hash unchanged)
- Rebuild when config changes
- Rebuild when module file changes

### Runtime Tests
- Mounts created for missing directories
- Mounts fail if path is file
- Environment variables applied
- PATH includes all module paths in order
- Module-specific caches persist (npm, maven, cargo)

### Edge Cases
- No .agentbox file
- Empty .agentbox file
- Module without mounts/env
- Conflicting modules (both install same tool)
- Host mount directory creation fails (permissions)
- Concurrent builds (same project)

## Rollback Strategy

During development:
1. Keep current `Dockerfile` as `Dockerfile.legacy`
2. Add `--legacy` flag to force use of legacy Dockerfile
3. If `.agentbox` not found, default to base image

After stable release:
1. Remove `--legacy` flag and `Dockerfile.legacy`
2. `Dockerfile.base` becomes primary Dockerfile

## Success Metrics

- Build image with nodejs:20 module
- Build image with multiple modules (nodejs + java)
- Verify PATH contains all module paths
- Verify mounts work (npm cache persists)
- Rebuild only when needed
- Error messages clear and actionable
- Custom modules work from `~/.agentbox/modules/`
- Documentation complete and tested

## Dependencies

### External
- `yq` (YAML parsing)
- `sha256sum` (hashing)
- `realpath` (path resolution)
- Bash 4+ (arrays, associative arrays)

### Internal
- Current agentbox script
- Current Dockerfile
- entrypoint.sh

## Risks and Mitigations

### Risk: Malicious custom modules
**Severity:** High (arbitrary code execution during build)
**Mitigation:**
- **Primary:** Users responsible for auditing custom modules
- **Defense-in-depth:** Validate mounts and env vars
- **Cannot prevent:** Malicious Dockerfile instructions (by design)
- **Documentation:** Prominent warning that modules are trusted code

### Risk: PATH injection
**Severity:** Medium
**Mitigation:**
- Validate PATH has no `.` or `./` entries
- Validate PATH entries are within user home
- Reject PATH pointing to writable system paths

### Risk: Path traversal
**Severity:** Medium
**Mitigation:**
- Validate module names: `^[a-z0-9_-]+$`
- Validate mount paths: no `..`, restricted to home
- Verify module directories aren't symlinks to system paths

### Risk: Environment variable injection
**Severity:** Medium
**Mitigation:**
- Blacklist critical variables: `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DOCKER_HOST`
- Sanitize values to prevent shell injection

### Risk: Concurrent builds
**Severity:** Low
**Mitigation:**
- Rely on Docker's native build locking
- Last build wins (acceptable for local development)

### Risk: Hash collision
**Severity:** Low (1 in 4 billion with 8-char hash)
**Mitigation:**
- Use SHA-256 for quality distribution
- Document the risk
- Can extend to 12 chars if needed

### Risk: Module complexity creep
**Mitigation:**
- Keep module format simple (3 file types max)
- Document limitations clearly
- Reject feature requests that add complexity

## Future Enhancements (Out of Scope)

- Module dependency declaration (e.g., `maven` requires `java`)
- Module aliases (e.g., `node` → `nodejs`)
- Remote module repositories
- Module update notifications
- Shared base layers across projects
- Module versioning/update checking
- Automatic migration tool
