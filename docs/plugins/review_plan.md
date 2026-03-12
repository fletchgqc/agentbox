# Review: Blocking Issues Fix Plan

Three issues that prevent deployment of the module system.

## Issue 1: PATH-Merge loses container-internal PATH

**Location**: `agentbox:510`

**Problem**: When modules define PATH entries, the merge logic replaces `$PATH` with a hardcoded system fallback:
```bash
PATH=${merged_path}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

The container's actual PATH (set by Dockerfile.base, entrypoint, .zshrc) includes `$HOME/.local/bin` where Claude CLI, OpenCode, uv-installed tools (black, ruff, pytest) live. These become unreachable when any module is active.

**Fix**: Don't set PATH via `docker run -e` at all. Instead, inject module PATH entries into the generated Dockerfile as ENV instructions. This way Docker's layer system handles the merging naturally, and .zshrc/entrypoint additions stack on top.

**Changes**:
1. `generate_dockerfile()` in `modules.sh`: After appending each module's dockerfile content, also read the module's `.env` file. For each `PATH=...` entry, emit an `ENV PATH=...` line into the generated Dockerfile. For non-PATH variables, emit `ENV VAR=value`.
2. `run_container()` in `agentbox`: Remove the entire module env-var processing block (lines 470-516: the `declare -A module_env_vars`, PATH merging logic, and the loop that adds `--env` flags). Module environment is now baked into the image.
3. `get_image_hash()` already includes `.env` file contents in the hash, so rebuild detection remains correct.

**Trade-off**: Environment changes require a rebuild instead of being applied at `docker run` time. This is acceptable because module selection already requires a rebuild, and the env files are tightly coupled to the module installation anyway.

## Issue 2: Rust mounts overwrite the installation

**Location**: `modules/rust/mounts`

**Problem**: Mounting `~/.cargo:/home/agent/.cargo` and `~/.rustup:/home/agent/.rustup` from the host shadows the entire directory that rustup populated during image build. On first run, host directories are empty, so `rustc`, `cargo` etc. disappear.

The same pattern affects `~/.npm` for Node.js, but there it only shadows the npm cache (node itself lives in `~/.nvm/versions/`), so it's less destructive.

**Fix**: Mount only the cache/registry subdirectories that benefit from persistence, not the root directories containing binaries and toolchain data.

**Changes**:
1. `modules/rust/mounts`: Replace with:
   ```
   ~/.cargo/registry:/home/agent/.cargo/registry
   ~/.cargo/git:/home/agent/.cargo/git
   ```
   Drop `~/.rustup` mount entirely — the toolchain is baked into the image and should not be overridden by host state.
2. `modules/rust/env`: Remove `CARGO_HOME` and `RUSTUP_HOME` lines. These are already set correctly inside the container by rustup's installation. Keep only the PATH line.
3. `validate_mount_path()` whitelist in `modules.sh`: The existing `~/.cargo` prefix already covers `~/.cargo/registry` and `~/.cargo/git`, so no whitelist changes needed.

**Consideration**: Users who want to share a single Rust toolchain across projects can create a custom module with the full mount. The built-in module should be safe by default.

## Issue 3: `agentbox_env` used before declaration

**Location**: `agentbox:521` (read) vs `agentbox:456` (write)

**Problem**: The variable `agentbox_env` is set inside the `if [[ "$ignore_dot_env" != "true" ]]` block (line 456). But line 521 reads it unconditionally to parse `AGENTBOX_EXTRA_HOSTS`. With `set -u` (via `set -euo pipefail`), using `--ignore-dot-env` causes an unbound variable error.

**Fix**: Move the `agentbox_env` declaration before the conditional block so it's always defined.

**Changes**:
1. `run_container()` in `agentbox`: Declare `local agentbox_env="${HOME}/.agentbox/.env"` once, before the `if` block at line 454. The env-file loading logic stays inside the conditional, but the variable is always available for the AGENTBOX_EXTRA_HOSTS parsing at line 521.

## Implementation Order

1. **Issue 3** first — one-line fix, eliminates runtime crash.
2. **Issue 2** second — mount file edits only, no logic changes.
3. **Issue 1** last — largest change, touches both `modules.sh` and `agentbox`.

## Verification

After all changes:
- `agentbox` with no `.agentbox` config: should work as before (base image).
- `agentbox` with `modules: [nodejs:20]`: Claude CLI must be in PATH, `node` must be in PATH.
- `agentbox` with `modules: [rust]`: `rustc --version` must work, `~/.cargo/bin` must be in PATH.
- `agentbox --ignore-dot-env`: must not crash.
- `agentbox` with `modules: [nodejs:20, java:17, rust]`: all three toolchains plus Claude CLI must coexist in PATH.
