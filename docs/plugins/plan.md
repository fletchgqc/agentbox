# Plugin System Implementation Plan

## Overview

Transform agentbox from a monolithic Dockerfile to a modular system where projects can specify required development tools via a `.agentbox` configuration file.

## Implementation Phases

### Phase 0: Security and Validation Layer

Implement security controls before module loading system to prevent malicious module configurations.

#### 0.1 Input Validation Functions

**New Functions:**
```bash
validate_mount_path()       # Security check for mount paths
validate_env_var()          # Security check for environment variables
validate_module_name()      # Prevent path traversal in module names
sanitize_path()            # Remove ../ and ensure no traversal
```

**Mount Path Security:**
- Reject absolute paths outside user home directory
- Reject paths containing `..` (path traversal)
- Whitelist allowed prefixes: `~/.cache`, `~/.config`, `~/.npm`, `~/.m2`, `~/.gradle`, `~/.cargo`, `~/.rustup`, `~/.sdkman`, `~/.nvm`
- Reject sensitive paths: `/var/run/docker.sock`, `/etc`, `/root`, `/sys`, `/proc`

**Environment Variable Security:**
- Blacklist critical variables: `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DOCKER_HOST`, `DOCKER_TLS_VERIFY`
- Allow PATH modifications but validate no malicious prefixes
- Sanitize values to prevent injection

**Module Name Security:**
- Reject names containing `/`, `..`, or absolute paths
- Only allow alphanumeric, dash, underscore
- Format: `^[a-z0-9_-]+$`

#### 0.2 File Permission Checks

**New Functions:**
```bash
check_module_readable()     # Verify module files are readable
verify_module_integrity()   # Check all expected files present
```

**Checks:**
- Verify `.dockerfile` exists and is readable
- Verify `.mounts` and `.env` are readable (if present)
- Fail early with clear error if permission denied

### Phase 1: Module Infrastructure

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
- Create helper function to locate modules (search user dir, then repo dir)
- Create module validator to check syntax

#### 1.2 Module Loading System

Create bash functions to:
- Search for modules in precedence order (`~/.agentbox/modules/`, `<repo>/modules/`)
- Parse module files (`.dockerfile`, `.mounts`, `.env`)
- Validate module existence and completeness
- Generate helpful error messages for missing modules

**New Functions (in `agentbox` script):**
```bash
find_module()           # Locate module file by name:version
validate_module()       # Check module files exist, are readable, and pass security checks
load_module_dockerfile() # Return Dockerfile instructions
load_module_mounts()    # Return mount specifications (after security validation)
load_module_env()       # Return environment variables (after security validation)
list_available_versions() # For error messages
```

**Security Integration:**
- `find_module()` calls `validate_module_name()` before searching
- `validate_module()` calls `check_module_readable()` and `verify_module_integrity()`
- `load_module_mounts()` validates each mount path with `validate_mount_path()`
- `load_module_env()` validates each variable with `validate_env_var()`

### Phase 2: Configuration System

#### 2.1 Config File Discovery

Implement upward search for `.agentbox` file:

**New Function:**
```bash
find_agentbox_config()  # Search upward from cwd, like .git
```

**Logic:**
- Start in current directory
- Search upward until `.agentbox` found or reach `/`
- Return path to config file or empty if not found

#### 2.2 Config File Parser

Parse YAML `.agentbox` configuration:

**New Function:**
```bash
parse_agentbox_config()  # Parse YAML, extract modules list
```

**Dependencies:**
- Use `yq` (already in Dockerfile) for YAML parsing
- Validate YAML syntax before parsing (prevent injection)
- Extract module list in format `name:version`
- Validate each module name format with `validate_module_name()`

**Security:**
- Reject malformed YAML that could exploit parser
- Validate module names don't contain path traversal
- Check for duplicate modules

### Phase 3: Dynamic Image Building

#### 3.1 Refactor Base Dockerfile

Create `Dockerfile.base` containing only:
- Linux base (Debian Trixie)
- Essential tools (git, vim, curl, wget, etc.)
- Build tools (gcc, make, cmake)
- Python (with uv)
- Claude Code and OpenCode
- User setup and shell configuration

**Tasks:**
- Strip language-specific installations from current Dockerfile
- Rename to `Dockerfile.base`
- Keep current Dockerfile as fallback during transition

#### 3.2 Dynamic Dockerfile Generation

Generate project-specific Dockerfiles on-the-fly:

**New Function:**
```bash
generate_dockerfile()  # Build Dockerfile from base + modules
```

**Logic:**
1. Start with `Dockerfile.base`
2. For each module in `.agentbox`:
   - Validate module exists
   - Append module's `.dockerfile` content
3. Write to temporary location
4. Return path to generated Dockerfile

#### 3.3 Image Naming and Hashing

Update image naming to use project path hash:

**Modify Function:**
```bash
get_image_name()  # Return agentbox:<project-path-hash>
```

**Logic:**
- Hash the directory containing `.agentbox` file (project root)
- Use first 8 characters of SHA-256 hash
- Format: `agentbox:7a3f9c2e`

**Note:** Hash collision risk with 8 chars is ~1 in 4 billion. Acceptable for local development use case.

### Phase 4: Rebuild Detection

#### 4.1 Extend Rebuild Triggers

Enhance `needs_rebuild()` to check:
- Base Dockerfile modified
- Any referenced module definition modified
- `.agentbox` config modified
- Target image doesn't exist

**Modify Function:**
```bash
needs_rebuild()
```

**Image Label Format:**
```
agentbox.config.hash=<sha256-of-.agentbox>
agentbox.base.hash=<sha256-of-Dockerfile.base>
agentbox.module.<name>.<version>.hash=<sha256-of-module-files>
```

**Tracking Logic:**
- Store hash of `.agentbox` config in label `agentbox.config.hash`
- Store hash of each module's combined files in `agentbox.module.<name>.<version>.hash`
- Store hash of base Dockerfile in `agentbox.base.hash`
- Compare all hashes on startup; rebuild if any mismatch

### Phase 5: Runtime Configuration

#### 5.1 Module Mounts

Integrate module-specified volume mounts:

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. Load mounts from each module's `.mounts` file
2. Validate each mount path with `validate_mount_path()` (security)
3. Expand `~` to `$HOME`
4. Check if host path exists; if directory missing, attempt create
5. Handle creation failures gracefully (permission errors)
6. Verify host path is directory, not file
7. Add validated mounts to mount_opts array

#### 5.2 Module Environment Variables

Integrate module-specified environment variables:

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. Load environment from each module's `.env` file
2. Parse `VAR=value` format
3. Validate each variable with `validate_env_var()` (security)
4. Reject blacklisted variables (LD_PRELOAD, DOCKER_HOST, etc.)
5. Add validated variables to `--env` flags for docker run command

### Phase 6: Initial Module Set

#### 6.1 Extract Language Modules from Current Dockerfile

Create initial modules from existing Dockerfile:

**Modules to create:**

`modules/nodejs/20.dockerfile`:
```dockerfile
# Install Node.js via NVM
ENV NVM_DIR="/home/agent/.nvm"
RUN NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install 20 && \
    nvm alias default 20 && \
    nvm use default && \
    npm install -g typescript @types/node ts-node eslint prettier nodemon yarn pnpm
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
```

`modules/nodejs/20.mounts`:
```
~/.npm:/home/agent/.npm
```

`modules/java/17.dockerfile`:
```dockerfile
# Install Java 17 via SDKMAN
RUN curl -s "https://get.sdkman.io?rcupdate=false" | bash && \
    bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
        sdk install java 17.0.9-tem && \
        sdk install gradle && \
        sdk install maven" && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc
```

`modules/java/17.mounts`:
```
~/.m2:/home/agent/.m2
~/.gradle:/home/agent/.gradle
```

`modules/rust/dockerfile`:
```dockerfile
# Install Rust via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc && \
    echo 'source "$HOME/.cargo/env"' >> ~/.zshrc
```

`modules/rust/mounts`:
```
~/.cargo:/home/agent/.cargo
```

### Phase 7: Error Handling

#### 7.1 Missing Module Errors

Create clear error messages:

**Function:**
```bash
show_module_error()  # Display helpful error for missing module
```

**Error format:**
```
Error: Module not found: java:21

Searched in:
  - /home/user/.agentbox/modules/java/21.dockerfile
  - /opt/agentbox/modules/java/21.dockerfile

Available java versions:
  - 17
```

#### 7.2 Config Validation

Validate `.agentbox` syntax before processing:

**Function:**
```bash
validate_config()  # Check YAML syntax, module format
```

**Checks:**
- Valid YAML syntax (prevent parser exploits)
- `modules:` key exists
- Module names follow `name:version` or `name` format
- Module names pass `validate_module_name()` security check
- No duplicate modules
- Reject malformed structures

#### 7.3 Docker Build Error Handling

Improve Docker build failure messages:

**Function:**
```bash
parse_docker_error()  # Extract actionable error from Docker output
```

**Improvements:**
- Capture full Docker build output
- Extract specific failure line/command from multi-stage output
- Surface root cause, not just "build failed"
- Suggest common fixes for known issues

#### 7.4 Security Validation Errors

Clear messages for security violations:

**Error Examples:**
```
Error: Insecure mount path in module nodejs:20
Path: /etc/passwd:/container/etc/passwd
Reason: Absolute paths outside user home are not allowed

Allowed prefixes: ~/.cache, ~/.config, ~/.npm, ~/.m2, ~/.gradle, ~/.cargo
```

```
Error: Blocked environment variable in module custom:1
Variable: LD_PRELOAD=/malicious/lib.so
Reason: LD_PRELOAD is blacklisted for security

Blocked variables: LD_PRELOAD, LD_LIBRARY_PATH, DOCKER_HOST, DOCKER_TLS_VERIFY
```

### Phase 8: Documentation

#### 8.1 Update README

Add sections:
- Module system overview
- `.agentbox` configuration syntax
- Creating custom modules
- Available built-in modules

#### 8.2 Module Development Guide

Create `docs/plugins/module-development.md`:
- Module file format specification
- Best practices for writing modules
- Security guidelines for custom modules
- Testing modules
- Contributing modules to agentbox

**Security Documentation:**
- Warn users that custom modules in `~/.agentbox/modules/` execute arbitrary code
- Document mount path restrictions and allowed prefixes
- Document environment variable blacklist
- Explain that modules are trusted code (like installing packages)

#### 8.3 Migration Guide

Create `docs/plugins/migration.md`:
- How to migrate from monolithic Dockerfile
- Example `.agentbox` configurations
- Troubleshooting common issues

## Implementation Order

### Milestone 1: Security & Core Infrastructure
- Phase 0: Security and Validation Layer (0.1, 0.2)
- Phase 1: Module Infrastructure (1.1, 1.2)
- Phase 2: Configuration System (2.1, 2.2)
- Basic testing with hardcoded module

### Milestone 2: Dynamic Building
- Phase 3: Dynamic Image Building (3.1, 3.2, 3.3)
- Phase 4: Rebuild Detection (4.1)
- Test with single module

### Milestone 3: Runtime & Modules
- Phase 5: Runtime Configuration (5.1, 5.2)
- Phase 6: Initial Module Set (6.1)
- Integration testing

### Milestone 4: Error Handling & Documentation
- Phase 7: Error Handling (7.1, 7.2, 7.3, 7.4)
- Phase 8: Documentation (8.1, 8.2, 8.3)
- User acceptance testing

## Testing Strategy

### Unit Tests
- Module file parsing
- Config file parsing
- Path resolution
- Hash calculation
- Security validation functions (mount paths, env vars, module names)

### Integration Tests
- Build image with nodejs:20 module
- Build image with java:17 + nodejs:20
- Build image with rust (versionless)
- Verify mounts work correctly
- Verify environment variables applied

### Security Tests
- Reject malicious mount paths (`/etc/passwd`, `../../../etc`)
- Reject path traversal in module names (`../../malicious`)
- Reject sensitive environment variables (`LD_PRELOAD`)
- Reject absolute paths outside home in mounts
- Handle missing file permissions gracefully
- Verify built-in modules pass security validation

### Edge Cases
- Missing module
- Invalid YAML syntax
- Conflicting modules
- Module without mounts/env
- Empty .agentbox file
- No .agentbox file (fallback to base image)
- Host mount directory exists but is a file
- Host mount directory creation fails (permissions)
- Corrupt module file (partial download)

## Rollback Strategy

During development:
1. Keep current `Dockerfile` as `Dockerfile.legacy`
2. Add `--legacy` flag to use old Dockerfile
3. If `.agentbox` not found, use base image (close to current behavior)

After stable release:
1. Remove `--legacy` flag
2. Remove `Dockerfile.legacy`
3. Current Dockerfile becomes Dockerfile.base

## Success Metrics

- Can build image with nodejs:20 module
- Can build image with multiple modules
- Rebuild only triggers when needed
- Error messages are clear and actionable
- Custom modules in `~/.agentbox/modules/` work
- Documentation complete and tested
- Migration path validated with real projects

## Dependencies

### External
- `yq` (already in Dockerfile)
- `sha256sum` (already available)
- `realpath` (already available)
- Bash 4+ (already required)

### Internal
- Current agentbox script
- Current Dockerfile
- entrypoint.sh

## Risks and Mitigations

### Risk: Module complexity grows
**Mitigation:** Keep module format simple, document limitations clearly

### Risk: Build cache invalidation
**Mitigation:** Use precise hashing, only rebuild when truly needed

### Risk: User confusion during transition
**Mitigation:** Clear documentation, helpful error messages, migration guide

### Risk: Module conflicts
**Mitigation:** Let Docker fail fast, surface clear error to user

### Risk: Malicious custom modules
**Severity:** High (arbitrary code execution)
**Mitigation:** 
- Document that custom modules are trusted code
- Implement security validation for mounts and env vars
- Whitelist mount path prefixes
- Blacklist dangerous environment variables
- Cannot prevent malicious Dockerfile instructions (by design)
- Users responsible for auditing custom modules

### Risk: Path traversal attacks
**Severity:** Medium
**Mitigation:**
- Validate all module names (no `..` or `/`)
- Validate all mount paths (no `..`, restricted to home)
- Sanitize all user-provided paths

### Risk: Hash collision
**Severity:** Low (8-char hash = 1 in 4 billion)
**Mitigation:**
- Document the risk
- Use SHA-256 for quality hash distribution
- Consider extending to 12 chars if collisions occur in practice

## Future Enhancements (Out of Scope)

- Module dependency resolution
- Module versioning/update checking
- Remote module repositories
- Module aliases
- Shared image layers optimization
- Automatic migration tool
