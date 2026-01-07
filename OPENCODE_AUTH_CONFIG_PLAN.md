# OpenCode Auth + Config Integration Plan

## Goal
Persist both OpenCode configuration (settings) and authentication/session data inside AgentBox containers so the CLI has seamless access to users' global state (`~/.config/opencode`, `.opencode/`, `~/.local/share/opencode`).

## Step-by-step Implementation Outline

1. **Validate OpenCode storage requirements**
   - Confirm from docs that OpenCode merges configuration from `~/.config/opencode/opencode.json`, project-level `opencode.json`, and `.opencode/` directories.
   - Note that credentials and provider keys from `opencode auth login` are stored at `~/.local/share/opencode/auth.json`, alongside session exports and other runtime data.
   - Capture relevant environment variables: `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG`, `OPENCODE_CONFIG_CONTENT`, `OPENCODE_DATA_DIR` so we know which ones AgentBox should set.
   - Decide which directories must be persisted by AgentBox: config (`~/.config/opencode` + `.opencode/` if present), session/auth data (`~/.local/share/opencode`), and optionally cache (`~/.cache/opencode`) if required for future features.

2. **Audit current AgentBox behavior**
   - Review `agentbox` to ensure it already initializes and mounts a Docker volume seeded from host `~/.config/opencode` to `/home/claude/.config/opencode`, setting `OPENCODE_CONFIG_DIR`.
   - Confirm no mount exists for `~/.local/share/opencode`; auth/session data is currently lost between container runs, so we need a bind mount similar to the existing shell-history mount.
   - Verify there is no special handling for `.opencode/` directories or per-project configs beyond mounting `/workspace`.
   - Identify touch points requiring changes: mount options array, host-directory creation logic, log messages, environment-variable exports, and any helper functions reused for bind mounts.
   - Ensure `entrypoint.sh` or other scripts do not already manipulate these directories; document any interactions that new mounts must respect.

3. **Design bind-mount workflow**
   - Treat host `~/.local/share/opencode` (default `OPENCODE_DATA_DIR`) as authoritative; create it if it does not exist so the bind mount succeeds.
   - Add a bind mount entry similar to the shell history block: `-v "${HOME}/.local/share/opencode:/home/claude/.local/share/opencode"` so changes sync directly between host and container.
   - Ensure directory permissions allow the container user (UID 1000) to read/write; if needed, run `chown` once when creating the directory, but avoid docker-run copy steps.
   - Export environment variables so OpenCode honors the mounted location (`OPENCODE_DATA_DIR=/home/claude/.local/share/opencode`).
   - Log distinct messages so users know both config and auth/session data are mounted and persisted on the host.

4. **Update cleanup + documentation**
   - Document the new behavior in README, DEVELOPMENT_NOTES, and MIGRATION_PLAN: explain how host auth/config is imported, what persists, and how to reset (e.g., delete `~/.local/share/opencode`).
   - Mention environment variables users can override if they store OpenCode data elsewhere, plus any optional cache mounts if we add them later.

5. **Validation plan**
   - Manual test: run `./agentbox shell`, check `opencode auth list` to confirm imported providers appear; perform `opencode auth login` to add a new key, exit, restart, and verify persistence.
   - Run `./agentbox` (TUI mode) to ensure sessions resume with existing credentials.
   - Verify cleanup removes both config and data volumes, forcing a fresh import next run.
   - Optional: document expectations for users who need to back up or migrate their OpenCode state.
