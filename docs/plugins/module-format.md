# Module File Format Specification

## Overview

Modules are the building blocks of AgentBox's plugin system. Each module defines a development tool or language runtime that can be installed in an AgentBox container.

## Module Location

Modules are searched in precedence order:
1. `~/.agentbox/modules/` (user custom modules)
2. `<agentbox-repo>/modules/` (built-in modules)

## Module Structure

### Versioned Modules

For tools that support multiple versions:

```
modules/
  nodejs/
    20.dockerfile
    20.mounts (optional)
    20.env (optional)
    22.dockerfile
    22.mounts
    22.env
  java/
    17.dockerfile
    17.mounts
    17.env
    21.dockerfile
    21.mounts
    21.env
```

### Version-Managed Modules

For tools that manage their own versions (e.g., rustup):

```
modules/
  rust/
    dockerfile
    mounts (optional)
    env (optional)
```

## File Formats

### Dockerfile (`<version>.dockerfile` or `dockerfile`)

Contains Dockerfile instructions to install the tool.

**Requirements:**
- Must be a regular file (not symlink)
- Must be readable
- Must not be empty
- Must be ≤1MB in size
- Runs as `USER agent` (no root escalation needed)
- Tools install to `/home/agent/` directories

**Example:**
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
```

### Mounts (`<version>.mounts` or `mounts`)

Optional file defining volume mounts for persistent data (caches, configs).

**Format:** One mount per line: `<host-path>:<container-path>`

**Security:**
- Host paths must use `~` prefix for user home
- Whitelist: `~/.cache/`, `~/.config/`, `~/.npm/`, `~/.m2/`, `~/.gradle/`, `~/.cargo/`, `~/.rustup/`, `~/.sdkman/`, `~/.nvm/`
- Blacklist: `/var/run/docker.sock`, `/etc/`, `/sys/`, `/proc/`, `/dev/`
- Missing host directories created automatically (mode 0755)
- Fails if host path exists as file (not directory)

**Example:**
```
~/.npm:/home/agent/.npm
~/.cache/node:/home/agent/.cache/node
```

### Environment (`<version>.env` or `env`)

Optional file defining environment variables.

**Format:** One variable per line: `<VAR>=<value>`

**Security:**
- Blacklist: `LD_PRELOAD`, `LD_LIBRARY_PATH`, `DOCKER_HOST`, `DOCKER_TLS_VERIFY`, `DOCKER_CERT_PATH`
- PATH validation: no `.` or `./` entries, no writable system paths
- Supports `$VAR` references to existing environment variables

**PATH Merging:**
When multiple modules define PATH, all prepends combine in module order:
```bash
# Module 1: nodejs
PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH

# Module 2: java
PATH=/home/agent/.sdkman/candidates/java/current/bin:$PATH

# Result
PATH=/home/agent/.nvm/versions/node/v20/bin:/home/agent/.sdkman/candidates/java/current/bin:$PATH
```

**Example:**
```
NVM_DIR=/home/agent/.nvm
PATH=/home/agent/.nvm/versions/node/v20/bin:$PATH
```

## Module Naming

- Format: `^[a-z0-9_-]+$` (lowercase alphanumeric, underscores, hyphens only)
- Case-insensitive lookup (converted to lowercase)
- Path traversal (`/`, `..`, absolute paths) rejected
- Module directories must not be symlinks outside `~/.agentbox/` or agentbox repo

## User Context

All module installations run as `agent` user with UID 1000:
- Installation directory: `/home/agent/`
- No root escalation needed
- Tools installed to user-writable locations

## Security Model

**Trust Boundary:**
Modules execute arbitrary code during build. Users are responsible for auditing custom modules.

- **Built-in modules:** Trusted (maintained by agentbox)
- **Custom modules:** User responsibility to audit
- **Cannot prevent:** Malicious Dockerfile instructions (by design)
- **Defense-in-depth:** Mount/env validation provides additional protection

## Testing Modules

Test a module locally before using:

```bash
# Create test .agentbox config
echo "modules:
  - mymodule:1" > /tmp/test/.agentbox

# Test in isolated directory
cd /tmp/test && agentbox shell
```

## Module Capabilities

Modules can specify:
- Dockerfile instructions (required)
- Volume mounts (optional)
- Environment variables (optional)

Modules cannot specify:
- Exposed ports
- Docker run flags
- Entrypoint/CMD modifications
