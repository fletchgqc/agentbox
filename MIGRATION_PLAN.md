# Migration Plan: Claude Code → OpenCode

**Status**: 🔄 In Implementierung (Phase 1-5 ✅ abgeschlossen, Phase 4 & 6 ausstehend)  
**Erstellt**: 2024-12-23  
**Letztes Update**: 2024-12-23  

---

## 🎯 Migration Intention & Ziel

### Warum diese Migration?

AgentBox wurde ursprünglich für Claude Code entwickelt. Diese Migration ersetzt Claude Code durch **OpenCode**, einen Open-Source AI-Coding-Agent mit folgenden Vorteilen:

- **Open Source**: Vollständig open source (41K+ GitHub Stars)
- **Multi-Provider**: Unterstützt 75+ LLM Provider (Anthropic, OpenAI, Google, lokale Modelle)
- **Flexibilität**: TUI, Desktop App, IDE Extension verfügbar
- **Gleiche Philosophie**: Container-Isolation für sichere AI-Agent-Operationen

### Ziel der Migration

Alle Referenzen und Funktionalität von Claude Code durch OpenCode ersetzen bei:
- ✅ Beibehaltung der Container-Architektur
- ✅ Beibehaltung des Benutzernamens "claude" (minimale Änderungen)
- ✅ Maximale Freiheit für den Agent (analog zu `--dangerously-skip-permissions`)
- ✅ Clean Break (keine Rückwärtskompatibilität zu alten Claude Volumes)
- ✅ Neutrale Volume-Namen (`agentbox-config-*` statt `agentbox-claude-*`)

### Technische Hauptunterschiede

| Aspekt | Claude Code | OpenCode |
|--------|-------------|----------|
| NPM Package | `@anthropic-ai/claude-code` | `opencode-ai` |
| Hauptbefehl | `claude` | `opencode` |
| Permissions | `--dangerously-skip-permissions` | Alles standardmäßig erlaubt |
| Config-Verzeichnis | `~/.claude` | `~/.config/opencode` |
| Auth-Datei | In `~/.claude` | `~/.local/share/opencode/auth.json` |
| Projekt-Instruktionen | `CLAUDE.md` | `AGENTS.md` |
| MCP Config | Custom | `mcp` key in `opencode.json` |

---

## 📋 Implementierungs-Checkliste

### Phase 1: Docker Image ✅ **DONE**
- [x] **Dockerfile Zeile 211**: Package ändern `@anthropic-ai/claude-code` → `opencode-ai`
- [x] **Dockerfile Zeile 213**: Version check `claude --version` → `opencode --version`
- [x] **Build testen**: `./agentbox --rebuild`

**Ergebnis**: OpenCode 1.0.191 erfolgreich installiert, Docker Image baut sauber.

### Phase 2: Container Scripts ✅ **DONE**
- [x] **entrypoint.sh Zeile 98**: Welcome message `Claude CLI` → `OpenCode`
- [x] **entrypoint.sh Zeilen 76-79**: MCP detection um `opencode.json` erweitern
- [ ] **entrypoint.sh Zeile 68**: Git identity `claude@agentbox` → `agent@agentbox` (optional, übersprungen)

**Ergebnis**: Welcome message und MCP detection aktualisiert.

### Phase 3: Main Script ✅ **DONE**
- [x] **agentbox Zeile 310**: Volume-Name `agentbox-claude-*` → `agentbox-config-*`
- [x] **agentbox Zeilen 313-336**: Volume creation logic für OpenCode anpassen
- [x] **agentbox Zeile 338**: Volume mount Pfad `~/.claude` → `~/.config/opencode`
- [x] **agentbox Zeilen 341-343**: Env var `CLAUDE_CONFIG_DIR` → `OPENCODE_CONFIG_DIR`
- [x] **agentbox Zeilen 367-374**: Command `claude --dangerously-skip-permissions` → `opencode`
- [x] **agentbox Zeilen 416, 429, 437, 441, 443**: Help text aktualisiert (alle Referenzen)
- [x] **agentbox Zeilen 468-482**: Cleanup function für neue Volume-Namen

**Ergebnis**: Alle Script-Änderungen abgeschlossen, neue Volumes werden korrekt erstellt (`agentbox-config-*`).

### Phase 4: Dokumentation ⏳ **TODO**
- [ ] **README.md Zeile 1-6**: Titel/Beschreibung Claude → OpenCode
- [ ] **README.md Zeile 15**: Features "Claude CLI Integration" → "OpenCode Integration"
- [ ] **README.md Zeilen 57-62**: Quick Start anpassen
- [ ] **README.md Zeile 90**: Volume-Name in Diagramm
- [ ] **README.md Zeile 101**: Languages Section
- [ ] **README.md Zeile 110**: Git Instruktionen CLAUDE.md → AGENTS.md
- [ ] **README.md Zeile 119**: Git Config default identity
- [ ] **README.md Zeilen 142-152**: MCP Section komplett neu (OpenCode Format)
- [ ] **README.md Zeilen 167-192**: Volume Management Section
- [ ] **README.md Zeile 217**: Anthropic DevContainer Referenz entfernen
- [ ] **DEVELOPMENT_NOTES.md Zeile 7-12**: Origin Story erweitern
- [ ] **DEVELOPMENT_NOTES.md Zeile 20**: Volume Strategy
- [ ] **DEVELOPMENT_NOTES.md Zeile 56**: Mount Points
- [ ] **DEVELOPMENT_NOTES.md Zeile 117**: Volume Naming
- [ ] **DEVELOPMENT_NOTES.md Zeile 126**: File Count
- [ ] **CLAUDE.md → OPENCODE.md**: Datei umbenennen
- [ ] **OPENCODE.md Zeile 1**: Verweis auf AGENTS.md hinzufügen
- [ ] **OPENCODE.md Zeilen 27-29**: Dokumentations-Guidelines anpassen

### Phase 5: Neue Dateien ✅ **DONE**
- [x] **opencode.json.example**: Beispiel-Config mit maximalen Permissions erstellt
- [x] **.gitignore**: `opencode.json` und `.opencode/` hinzugefügt

**Ergebnis**: Beispiel-Konfiguration für OpenCode bereitgestellt.

### Phase 6: Testing ⏳ **TODO**
- [ ] `./agentbox --rebuild` erfolgreich
- [ ] `./agentbox --help` zeigt korrekte Hilfe
- [ ] `./agentbox shell` startet, `opencode --version` funktioniert
- [ ] `./agentbox` startet OpenCode TUI
- [ ] Provider-Auth: `opencode auth login` funktioniert im Container
- [ ] File operations: OpenCode kann Dateien lesen/schreiben
- [ ] SSH: Git operations funktionieren
- [ ] Multi-project: Zwei Projekte gleichzeitig isoliert
- [ ] Persistence: Config bleibt nach Container-Neustart
- [ ] `./agentbox --cleanup` entfernt neue Volumes korrekt

---

## 🔧 Detaillierte Änderungen

### 1. Dockerfile

**Zeile 211** - NPM Package:
```dockerfile
# ALT:
    npm install -g \
        @anthropic-ai/claude-code && \

# NEU:
    npm install -g \
        opencode-ai && \
```

**Zeile 213** - Version Check:
```dockerfile
# ALT:
    which claude && claude --version"

# NEU:
    which opencode && opencode --version"
```

---

### 2. entrypoint.sh

**Zeile 98** - Welcome Message:
```bash
# ALT:
    echo "🤖 Claude CLI: $(claude --version 2>/dev/null || echo 'not found - check installation')"

# NEU:
    echo "🤖 OpenCode: $(opencode --version 2>/dev/null || echo 'not found - check installation')"
```

**Zeilen 76-79** - MCP Detection:
```bash
# ALT:
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ]; then
    echo "🔌 MCP configuration detected. To enable MCP servers, see AgentBox documentation."
fi

# NEU:
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ] || \
   [ -f "/workspace/opencode.json" ] || grep -q '"mcp"' /workspace/opencode.json 2>/dev/null; then
    echo "🔌 MCP configuration detected in opencode.json"
fi
```

**Zeile 68** - Git Identity (optional):
```bash
# ALT:
    email = claude@agentbox

# NEU:
    email = agent@agentbox
```

---

### 3. agentbox (Main Script)

**Zeile 310** - Volume Name:
```bash
# ALT:
    local claude_volume_name="agentbox-claude-${container_name#agentbox-}"

# NEU:
    local config_volume_name="agentbox-config-${container_name#agentbox-}"
```

**Zeilen 313-336** - Volume Creation:
```bash
# ALT:
    if ! docker volume inspect "$claude_volume_name" &>/dev/null; then
        log_info "Creating Claude CLI volume and copying authentication from global config"
        docker volume create "$claude_volume_name" &>/dev/null

        local uid=$(id -u)
        local gid=$(id -g)

        if [[ -d "${HOME}/.claude" ]]; then
            docker run --rm \
                -v "${HOME}/.claude:/source:ro" \
                -v "${claude_volume_name}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                sh -c "cp -r /source/* /dest/ 2>/dev/null; chown -R ${uid}:${gid} /dest"
        else
            docker run --rm \
                -v "${claude_volume_name}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                chown -R ${uid}:${gid} /dest
        fi
    fi

# NEU:
    if ! docker volume inspect "$config_volume_name" &>/dev/null; then
        log_info "Creating OpenCode config volume"
        docker volume create "$config_volume_name" &>/dev/null

        local uid=$(id -u)
        local gid=$(id -g)

        # Initialize with global OpenCode config if it exists
        if [[ -d "${HOME}/.config/opencode" ]]; then
            docker run --rm \
                -v "${HOME}/.config/opencode:/source:ro" \
                -v "${config_volume_name}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                sh -c "cp -r /source/* /dest/ 2>/dev/null || true; chown -R ${uid}:${gid} /dest"
        else
            docker run --rm \
                -v "${config_volume_name}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                chown -R ${uid}:${gid} /dest
        fi
    fi
```

**Zeile 338** - Volume Mount:
```bash
# ALT:
    mount_opts+=(-v "${claude_volume_name}:/home/claude/.claude")

# NEU:
    mount_opts+=(-v "${config_volume_name}:/home/claude/.config/opencode")
```

**Zeilen 341-343** - Environment Variable:
```bash
# ALT:
    # Set Claude config directory environment variable
    mount_opts+=(--env "CLAUDE_CONFIG_DIR=/home/claude/.claude")
    log_info "Claude CLI configuration mounted"

# NEU:
    # Set OpenCode config directory environment variable
    mount_opts+=(--env "OPENCODE_CONFIG_DIR=/home/claude/.config/opencode")
    log_info "OpenCode configuration mounted"
```

**Zeilen 367-374** - Command Execution:
```bash
# ALT:
        # Run claude through zsh to get proper environment
        # Always include --dangerously-skip-permissions, append any additional flags
        local claude_cmd="claude --dangerously-skip-permissions"
        if [[ ${#cmd_args[@]} -gt 0 ]]; then
            claude_cmd="$claude_cmd ${cmd_args[*]}"
        fi
        container_cmd=(zsh -c "source ~/.zshrc && exec $claude_cmd")

# NEU:
        # Run opencode through zsh to get proper environment
        # OpenCode allows all operations by default (no skip-permissions flag needed)
        local opencode_cmd="opencode"
        if [[ ${#cmd_args[@]} -gt 0 ]]; then
            opencode_cmd="$opencode_cmd ${cmd_args[*]}"
        fi
        container_cmd=(zsh -c "source ~/.zshrc && exec $opencode_cmd")
```

**Zeile 416** - Help Title:
```bash
# ALT:
AgentBox - Simplified Docker environment for Claude development

# NEU:
AgentBox - Simplified Docker environment for OpenCode/AI development
```

**Zeile 437** - Help Example:
```bash
# ALT:
    agentbox                            # Start Claude CLI for current project

# NEU:
    agentbox                            # Start OpenCode for current project
```

**Zeilen 468-482** - Cleanup Function:
```bash
# ALT:
    # Remove cached data (optional - ask user)
    local cache_base="${HOME}/.cache/agentbox"
    local project_base="${HOME}/.agentbox/projects"

    if [[ -d "$cache_base" ]] || [[ -d "$project_base" ]]; then
        log_warning "This will also remove cached packages and shell history."
        echo -n "Remove cached data? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            [[ -d "$cache_base" ]] && rm -rf "$cache_base"
            [[ -d "$project_base" ]] && rm -rf "$project_base"
            log_success "Cached data removed"
        else
            log_info "Cached data preserved"
        fi
    fi

# NEU:
    # Remove Docker volumes
    log_info "Removing AgentBox config volumes..."
    docker volume ls -q | grep "agentbox-config" | xargs -r docker volume rm 2>/dev/null || true

    # Remove cached data (optional - ask user)
    local cache_base="${HOME}/.cache/agentbox"
    local project_base="${HOME}/.agentbox/projects"

    if [[ -d "$cache_base" ]] || [[ -d "$project_base" ]]; then
        log_warning "This will also remove cached packages and shell history."
        echo -n "Remove cached data? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            [[ -d "$cache_base" ]] && rm -rf "$cache_base"
            [[ -d "$project_base" ]] && rm -rf "$project_base"
            log_success "Cached data removed"
        else
            log_info "Cached data preserved"
        fi
    fi
```

---

### 4. README.md (Dokumentation)

**Zeilen 1-6** - Titel:
```markdown
# ALT:
A Docker-based development environment for running Claude CLI in a more safe, isolated fashion. This makes it less dangerous to use YOLO mode (`--dangerously-skip-permissions`), which is, in my opinion, the only way to use AI agents.

# NEU:
A Docker-based development environment for running OpenCode in a safe, isolated fashion. Provides full container isolation while maintaining seamless access to your project files.
```

**Zeile 15** - Features:
```markdown
# ALT:
- **Claude CLI Integration**: Built-in support for Claude CLI with per-project authentication

# NEU:
- **OpenCode Integration**: Built-in support for OpenCode with per-project configuration
```

**Weitere Änderungen**: Siehe detaillierten Plan oben, Abschnitt "📄 Datei 4: README.md"

---

### 5. Neue Dateien

**opencode.json.example**:
```json
{
  "$schema": "https://opencode.ai/opencode.schema.json",
  
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow",
    "doom_loop": "ask",
    "external_directory": "ask"
  },
  
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem"],
      "environment": {
        "ALLOWED_PATHS": "/workspace"
      },
      "enabled": false
    }
  },
  
  "comment": "AgentBox OpenCode configuration - maximale Freiheit für AI Agent"
}
```

**.gitignore** Ergänzung:
```
opencode.json
.opencode/
```

---

## ⏱️ Geschätzter Zeitaufwand

- **Phase 1 (Docker)**: 5 Minuten
- **Phase 2 (Entrypoint)**: 5 Minuten
- **Phase 3 (Main Script)**: 15 Minuten
- **Phase 4 (Docs)**: 20 Minuten
- **Phase 5 (Neue Dateien)**: 5 Minuten
- **Phase 6 (Testing)**: 30 Minuten

**Total**: ~1.5 Stunden

---

## ⚠️ Bekannte Risiken & Lösungen

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| OpenCode benötigt `~/.local/share/opencode` zusätzlich | Mittel | Mittel | Zweiten Mount oder Symlink hinzufügen |
| OpenCode config Format anders | Niedrig | Hoch | In Testing Phase validieren |
| Permissions zu permissiv | Niedrig | Mittel | Dokumentieren in opencode.json.example |
| Auth-Flow anders | Mittel | Mittel | Dokumentation mit `opencode auth login` ergänzen |

---

## 🔄 Nächste Schritte für Fortsetzung

1. **Phase 1 starten**: Docker Image anpassen
2. **Quick Test**: Build testen mit `./agentbox --rebuild`
3. **Phase 2+3**: Scripts anpassen
4. **Functional Test**: OpenCode im Container starten
5. **Phase 4+5**: Dokumentation vervollständigen
6. **Phase 6**: Vollständiges Testing

---

## 📝 Entscheidungslog

| Datum | Entscheidung | Begründung |
|-------|--------------|------------|
| 2024-12-23 | Username "claude" beibehalten | Minimale Änderungen, viele Pfade betroffen |
| 2024-12-23 | Volume-Namen neutral: `agentbox-config-*` | Provider-unabhängig, zukunftssicher |
| 2024-12-23 | Maximale Freiheit (allow all) | Analog zu bisherigem `--dangerously-skip-permissions` |
| 2024-12-23 | Clean Break, keine Migration | Einfachheit, Test-Projekt |
| 2024-12-23 | GitHub Actions ignorieren | Nicht essentiell für Kern-Funktionalität |

---

**Status-Legende**:
- ⏳ TODO - Noch nicht begonnen
- 🔄 IN PROGRESS - In Arbeit
- ✅ DONE - Abgeschlossen
- ⚠️ BLOCKED - Blockiert, benötigt Entscheidung/Input
