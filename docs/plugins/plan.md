# Plugin System Implementation Plan

## Overview

Transform agentbox from a monolithic Dockerfile to a modular system where projects can specify required development tools via a `.agentbox` configuration file.

## Implementation Phases

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
validate_module()       # Check module files exist and are readable
load_module_dockerfile() # Return Dockerfile instructions
load_module_mounts()    # Return mount specifications
load_module_env()       # Return environment variables
list_available_versions() # For error messages
```

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
- Validate syntax
- Extract module list in format `name:version`

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
- Hash the full project directory path
- Use first 8 characters of hash
- Format: `agentbox:7a3f9c2e`

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

**New tracking:**
- Store hash of `.agentbox` config in image label
- Store hash of each module version in image label
- Store hash of base Dockerfile in image label
- Compare all hashes on startup

### Phase 5: Runtime Configuration

#### 5.1 Module Mounts

Integrate module-specified volume mounts:

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. Load mounts from each module's `.mounts` file
2. Expand `~` to `$HOME`
3. Add to mount_opts array
4. Create host directories if needed

#### 5.2 Module Environment Variables

Integrate module-specified environment variables:

**Modify Function:**
```bash
run_container()
```

**Logic:**
1. Load environment from each module's `.env` file
2. Parse `VAR=value` format
3. Add `--env` flags to docker run command

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
- Valid YAML syntax
- `modules:` key exists
- Module names follow `name:version` or `name` format
- No duplicate modules

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
- Testing modules
- Contributing modules to agentbox

#### 8.3 Migration Guide

Create `docs/plugins/migration.md`:
- How to migrate from monolithic Dockerfile
- Example `.agentbox` configurations
- Troubleshooting common issues

## Implementation Order

### Milestone 1: Core Infrastructure (Week 1)
- Phase 1: Module Infrastructure (1.1, 1.2)
- Phase 2: Configuration System (2.1, 2.2)
- Basic testing with hardcoded module

### Milestone 2: Dynamic Building (Week 2)
- Phase 3: Dynamic Image Building (3.1, 3.2, 3.3)
- Phase 4: Rebuild Detection (4.1)
- Test with single module

### Milestone 3: Runtime & Modules (Week 3)
- Phase 5: Runtime Configuration (5.1, 5.2)
- Phase 6: Initial Module Set (6.1)
- Integration testing

### Milestone 4: Polish & Docs (Week 4)
- Phase 7: Error Handling (7.1, 7.2)
- Phase 8: Documentation (8.1, 8.2, 8.3)
- User acceptance testing

## Testing Strategy

### Unit Tests
- Module file parsing
- Config file parsing
- Path resolution
- Hash calculation

### Integration Tests
- Build image with nodejs:20 module
- Build image with java:17 + nodejs:20
- Build image with rust (versionless)
- Verify mounts work correctly
- Verify environment variables applied

### Edge Cases
- Missing module
- Invalid YAML syntax
- Conflicting modules
- Module without mounts/env
- Empty .agentbox file
- No .agentbox file (fallback to base image)

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

## Future Enhancements (Out of Scope)

- Module dependency resolution
- Module versioning/update checking
- Remote module repositories
- Module aliases
- Shared image layers optimization
- Automatic migration tool
