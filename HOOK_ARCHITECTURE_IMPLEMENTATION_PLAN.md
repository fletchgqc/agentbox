# AgentBox Hook-basierte Architektur - Implementierungsplan

**Status**: Phase 0 ✅ Abgeschlossen, Phase 1+ Bereit  
**Architektur-Dokumentation**: [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md)

---

## Übersicht

Dieser Plan beschreibt die **konkrete Implementierung** der Hook-basierten Architektur.

Für das **Architektur-Konzept** (Interface-Spezifikation, Design-Prinzipien, Lifecycle) siehe [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md).

### 🎯 Kern-Prinzipien dieser Implementierung

1. **Minimale Komplexität**: Validierung nur an 2 kritischen Stellen (agentbox + entrypoint.sh)
2. **DRY (Don't Repeat Yourself)**: Zentrale `validate_agent()` Funktion ersetzt 4 redundante Validierungen
3. **Fail Fast**: Klare Fehlermeldungen, kein Over-Engineering
---

## Ziel-Verzeichnisstruktur

```
agents.d/
├── .template/
│   ├── install.sh              # Template für Installation
│   ├── config                  # Template für Metadaten
│   ├── start.sh                # Template für Agent-Start
│   └── README.md               # Template-Dokumentation
├── opencode/
│   ├── install.sh              # OpenCode Installation
│   ├── config                  # OpenCode Metadaten
│   └── start.sh                # OpenCode Start
└── README.md                   # Agents-Directory Dokumentation
```

---

## Implementierungsplan

### Phasen-Übersicht

| Phase | Beschreibung | Status |
|-------|--------------|--------|
| 0 | Dokumentation | ✅ Done |
| 1 | Verzeichnisstruktur & Templates | ⏳ Next |
| 2 | OpenCode Agent Implementation | ⏳ Pending |
| 3 | Dockerfile Änderungen | ⏳ Pending |
| 4 | agentbox Script Änderungen | ⏳ Pending |
| 5 | entrypoint.sh Änderungen | ⏳ Pending |
| 6 | Testing & Validation | ⏳ Pending |

**Wichtig**: Phasen müssen **sequenziell** durchgeführt werden.

---

## ⚠️ Bekannte Stolpersteine (vor Implementierung beachten!)

### 1. Shell-Modus muss separat behandelt werden

**Problem**: Phase 4.6 schlägt vor, einfach `container_cmd=("${cmd_args[@]}")` zu setzen.
Das bricht den Shell-Modus, weil `./agentbox shell` dann `start.sh shell` aufruft.

**Lösung**: Die Shell-Modus-Logik muss erhalten bleiben:
```bash
if [[ "$shell_mode" == "true" ]]; then
    # Shell mode: bypass agent start.sh, run shell directly
    container_cmd=("${cmd_args[@]:-/bin/zsh}")
else
    # Agent mode: pass args to entrypoint (which calls start.sh)
    container_cmd=("${cmd_args[@]}")
fi
```

### 2. Pfade müssen SCRIPT_DIR verwenden

**Problem**: Der Plan verwendet relative Pfade wie `agents.d/${AGENT}`.
Das `agentbox` Script wird aber vom User's PROJECT_DIR aufgerufen.

**Lösung**: Immer `${SCRIPT_DIR}/agents.d/${AGENT}` verwenden.

### 3. HOST_CONFIG_DIR Validierung

**Problem**: Die Variable muss gesetzt sein (auch wenn leer), wird aber nicht geprüft.

**Lösung**: Prüfung hinzufügen:
```bash
if [[ -z "${HOST_CONFIG_DIR+x}" ]]; then
    log_error "Agent config did not set HOST_CONFIG_DIR (use empty string if not needed)"
    return 1
fi
```

### 4. Ein Image = Ein Agent (Design-Entscheidung)

Das aktuelle Design installiert nur EINEN Agent pro Docker-Image.
- `--agent=opencode` bei Build installiert OpenCode
- Späterer Wechsel zu anderem Agent erfordert `--rebuild`
- Verschiedene Projekte mit verschiedenen Agents = verschiedene Images

Dies ist beabsichtigt (kleinere Images), muss aber klar dokumentiert sein.

### 5. README.md dokumentiert `-c` Flag, das nicht existiert

Die README erwähnt `agentbox -c` für Session-Fortsetzung.
Dies ist OpenCode-interne Funktionalität (Sessions im Volume).
Das `-c` Flag existiert nicht im `agentbox` Script und muss entfernt oder implementiert werden.

---

## Phase 1: Verzeichnisstruktur & Templates

### 1.1 Agents-Verzeichnis erstellen

```bash
mkdir -p agents.d/.template
mkdir -p agents.d/opencode
```

### 1.2 Template-Dateien erstellen

**Datei: `agents.d/.template/install.sh`**

```bash
#!/bin/bash
# Agent Installation Script
# 
# Zweck: Installiert den Agent im Docker Container
# Aufgerufen: Während docker build
# Input: Keine
# Output: Exit code 0 bei Erfolg
#
# Beispiel:
#   npm install -g your-agent-package
#   your-agent --version

set -euo pipefail

# TODO: Implementiere Installation
echo "ERROR: install.sh not implemented for this agent"
exit 1
```

**Datei: `agents.d/.template/config`**

```bash
# Agent Configuration Metadata
#
# Zweck: Definiert Volume- und Config-Pfade für AgentBox
# Aufgerufen: In agentbox script vor docker run (via source)
# Format: Key-Value Paare (Bash-kompatibel)
#
# WICHTIG: Alle Variablen sind VERPFLICHTEND!
# AgentBox ersetzt automatisch Platzhalter:
#   ${HASH} - Container-Hash (z.B. "abc123")
#   ${AGENT} - Agent-Name (z.B. "opencode")

# Docker Volume Name (wird automatisch erstellt)
VOLUME_NAME="agentbox-config-${HASH}"

# Mount-Pfad im Container (wo der Agent seine Config erwartet)
MOUNT_PATH="/home/claude/.config/your-agent"

# Config-Verzeichnis auf Host (für Volume-Initialisierung, optional leer lassen)
HOST_CONFIG_DIR="${HOME}/.config/your-agent"
```

**Datei: `agents.d/.template/start.sh`**

```bash
#!/bin/bash
# Agent Start Script
#
# Zweck: Agent starten (inkl. Welcome Message + MCP Detection)
# Aufgerufen: Von entrypoint.sh als letzter Schritt
# Input: $@ = User-Argumente (z.B. "chat", "--help")
# Output: Startet den Agent (sollte mit 'exec' enden)
#
# Dieses Script sollte enthalten:
#   1. Welcome Message anzeigen
#   2. MCP Configuration Detection (optional)
#   3. Agent starten (exec)

set -euo pipefail

# 1. Welcome Message
echo "════════════════════════════════════════════════════════════════"
echo "🤖 Your Agent: $(your-agent --version 2>/dev/null || echo 'not found')"
echo "════════════════════════════════════════════════════════════════"

# 2. MCP Detection (optional, anpassen für deinen Agent)
if [ -f "/workspace/your-agent.json" ] && grep -q '"mcp"' /workspace/your-agent.json 2>/dev/null; then
    echo "🔌 MCP configuration detected"
fi

echo ""

# 3. Start Agent
exec your-agent "$@"
```

**Datei: `agents.d/.template/README.md`**

```markdown
# Agent Template

Dieses Template dient als Vorlage für neue Agent-Implementierungen.

## Verwendung

1. Kopiere das Template-Verzeichnis:
   ```bash
   cp -r agents.d/.template agents.d/my-agent
   ```

2. Passe die Dateien an:
   - `install.sh` - Installation deines Agents
   - `config` - Volume/Config-Metadaten
   - `start.sh` - Welcome Message + Agent-Start

3. Teste die Implementation:
   ```bash
   ./agentbox --rebuild --agent=my-agent
   ./agentbox --agent=my-agent
   ```

## Dateien-Spezifikation

### install.sh

**Zweck**: Agent installieren

**Aufruf**: Während `docker build`

**Input**: Keine

**Output**: Exit code 0 bei Erfolg

**Beispiel**:
```bash
#!/bin/bash
set -euo pipefail
npm install -g my-agent
my-agent --version
```

### config

**Zweck**: Metadaten für Volume/Config-Setup

**Aufruf**: In `agentbox` script (via `source`)

**Format**: Key-Value Paare (Bash-Variablen)

**Verpflichtende Variablen**:
- `VOLUME_NAME` - Docker Volume Name
- `MOUNT_PATH` - Mount-Pfad im Container
- `HOST_CONFIG_DIR` - Config-Verzeichnis auf Host (kann leer sein)

**Platzhalter** (werden von AgentBox ersetzt):
- `${HASH}` - Container-Hash
- `${AGENT}` - Agent-Name

**Beispiel**:
```bash
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.config/my-agent"
HOST_CONFIG_DIR="${HOME}/.config/my-agent"
```

### start.sh

**Zweck**: Agent starten

**Aufruf**: Von `entrypoint.sh` beim Container-Start

**Input**: `$@` = User-Argumente

**Output**: Startet Agent (mit `exec`)

**Sollte enthalten**:
1. Welcome Message
2. MCP Detection (optional)
3. Agent Start (exec)

**Beispiel**:
```bash
#!/bin/bash
set -euo pipefail
echo "🤖 My Agent: $(my-agent --version)"
exec my-agent "$@"
```

## Validierung

Bevor du deinen Agent als "fertig" markierst:

- [ ] `install.sh` installiert den Agent erfolgreich
- [ ] `config` setzt alle 3 erforderlichen Variablen
- [ ] `start.sh` zeigt Welcome Message
- [ ] `start.sh` startet den Agent mit `exec`
- [ ] Build Test: `./agentbox --rebuild --agent=my-agent`
- [ ] Start Test: `./agentbox --agent=my-agent`
- [ ] Volume Test: Config bleibt nach Container-Neustart

## Beispiel: OpenCode

Siehe `agents.d/opencode/` für eine vollständige Referenz-Implementierung.
```

### 1.3 Agents Directory README erstellen

**Datei: `agents.d/README.md`**

```markdown
# AgentBox Agents Directory

Dieses Verzeichnis enthält agent-spezifische Hook-Implementierungen für AgentBox.

## Struktur

```
agents.d/
├── .template/          # Template für neue Agents
│   ├── install.sh      # Installation Hook
│   ├── config          # Metadaten
│   ├── start.sh        # Start Hook
│   └── README.md       # Template-Anleitung
├── opencode/           # OpenCode Implementation
│   ├── install.sh
│   ├── config
│   └── start.sh
└── README.md           # Diese Datei
```

## Verfügbare Agents

### Implementiert
- **opencode** - Open-source AI coding agent mit 75+ LLM Providern

### Geplant
- **claude-code** - Anthropic's Claude Code CLI

## Neuen Agent hinzufügen

### Schritt-für-Schritt

1. **Template kopieren**:
   ```bash
   cp -r agents.d/.template agents.d/my-agent
   ```

2. **Dateien anpassen**:
   
   **a) `install.sh`** - Installation:
   ```bash
   #!/bin/bash
   set -euo pipefail
   npm install -g my-agent-package
   my-agent --version
   ```
   
   **b) `config`** - Metadaten (ALLE Variablen erforderlich):
   ```bash
   VOLUME_NAME="agentbox-config-${HASH}"
   MOUNT_PATH="/home/claude/.config/my-agent"
   HOST_CONFIG_DIR="${HOME}/.config/my-agent"
   ```
   
   **c) `start.sh`** - Start + Welcome:
   ```bash
   #!/bin/bash
   set -euo pipefail
   echo "🤖 My Agent: $(my-agent --version)"
   exec my-agent "$@"
   ```

3. **Executable machen**:
   ```bash
   chmod +x agents.d/my-agent/install.sh
   chmod +x agents.d/my-agent/start.sh
   ```

4. **Testen**:
   ```bash
   # Build
   ./agentbox --rebuild --agent=my-agent
   
   # Start
   ./agentbox --agent=my-agent
   
   # Shell (für Debugging)
   ./agentbox --agent=my-agent shell
   ```

5. **Validieren**:
   - [ ] Build erfolgreich
   - [ ] Agent startet
   - [ ] Welcome Message erscheint
   - [ ] Volumes bleiben persistent

## Agent Interface

Jeder Agent muss **2 Hooks + 1 Metadaten-Datei** bereitstellen:

### 1. install.sh (Hook)
Installation im Container (während `docker build`)

### 2. config (Metadaten)
Volume/Config-Setup Metadaten (wird via `source` geladen)

**Verpflichtende Variablen**:
- `VOLUME_NAME` - Docker Volume Name
- `MOUNT_PATH` - Mount-Pfad im Container
- `HOST_CONFIG_DIR` - Config auf Host (oder leer)

### 3. start.sh (Hook)
Agent starten + Welcome Message + MCP Detection

## Agent Selection

```bash
# Spezifischen Agent verwenden
./agentbox --agent=opencode

# Default Agent (claude-code, fallback: opencode)
./agentbox
```

## Troubleshooting

### Agent nicht gefunden
```
ERROR: Agent 'my-agent' not found in agents.d/
```
**Lösung**: Prüfe ob `agents.d/my-agent/` Verzeichnis existiert

### install.sh fehlt
```
ERROR: Agent my-agent incomplete: install.sh missing
```
**Lösung**: Beide Hooks + config müssen vorhanden sein

### config Fehler
```
ERROR: Agent config did not set VOLUME_NAME
```
**Lösung**: `config` muss alle 3 Variablen setzen

### Permission denied
```
bash: ./agents.d/my-agent/install.sh: Permission denied
```
**Lösung**: `chmod +x agents.d/my-agent/*.sh`

## Weitere Dokumentation

- **Architektur**: `../HOOK_ARCHITECTURE.md`
- **Implementierungsplan**: `../HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`
- **Template-Guide**: `.template/README.md`
- **Development Notes**: `../DEVELOPMENT_NOTES.md`
```

---

## Phase 2: OpenCode Agent Implementation

### 2.1 OpenCode install.sh

**Datei: `agents.d/opencode/install.sh`**

```bash
#!/bin/bash
# OpenCode Installation Script

set -euo pipefail

echo "Installing OpenCode..."

# Install OpenCode via npm
npm install -g opencode-ai

# Verify installation
if ! which opencode >/dev/null 2>&1; then
    echo "ERROR: OpenCode installation failed - binary not found"
    exit 1
fi

# Print version
echo "OpenCode installed successfully:"
opencode --version
```

Executable machen:
```bash
chmod +x agents.d/opencode/install.sh
```

### 2.2 OpenCode config

**Datei: `agents.d/opencode/config`**

```bash
# OpenCode Configuration Metadata

# Docker Volume Name
VOLUME_NAME="agentbox-config-${HASH}"

# Mount-Pfad im Container
MOUNT_PATH="/home/claude/.config/opencode"

# Config-Verzeichnis auf Host (für Volume-Initialisierung)
HOST_CONFIG_DIR="${HOME}/.config/opencode"

# Environment Variable
```

### 2.3 OpenCode start.sh

**Datei: `agents.d/opencode/start.sh`**

```bash
#!/bin/bash
# OpenCode Start Script

set -euo pipefail

# Welcome Message
echo "════════════════════════════════════════════════════════════════"
echo "🤖 OpenCode: $(opencode --version 2>/dev/null || echo 'not found - check installation')"
echo "════════════════════════════════════════════════════════════════"

# MCP Detection - OpenCode specific
if [ -f "/workspace/opencode.json" ]; then
    if grep -q '"mcp"' /workspace/opencode.json 2>/dev/null; then
        echo "🔌 MCP configuration detected in opencode.json"
    fi
fi

# MCP Detection - Generic files (backward compatibility)
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ]; then
    echo "🔌 MCP configuration detected"
fi

echo ""

# Start OpenCode
# OpenCode allows all operations by default (no permission flags needed)
exec opencode "$@"
```

Executable machen:
```bash
chmod +x agents.d/opencode/start.sh
```

---

## Phase 3: Dockerfile Änderungen

### 3.1 Dockerfile anpassen

**Lokalisiere Zeilen ~207-213** (aktueller OpenCode Install Block):

```dockerfile
# Install AI Coding Assistants
RUN bash -c "set -euxo pipefail; \
    npm install -g \
        opencode-ai && \
    which opencode && opencode --version"
```

**Ersetze durch**:

```dockerfile
# Copy all agent implementations
COPY agents.d/ /opt/agentbox/agents.d/

# Install selected agent
ARG AGENTBOX_AGENT=claude-code
ENV AGENTBOX_AGENT=${AGENTBOX_AGENT}

# Install agent (validation happens in agentbox script before build)
RUN bash -c "set -euxo pipefail; \
    chmod +x /opt/agentbox/agents.d/\${AGENTBOX_AGENT}/*.sh; \
    /opt/agentbox/agents.d/\${AGENTBOX_AGENT}/install.sh"
```

**Hinweis**: Die Validierung (Agent existiert, Dateien vorhanden) passiert in Phase 4.1b im `agentbox` Script BEVOR der Build gestartet wird. Das Dockerfile kann sich darauf verlassen, dass der Agent valide ist.

---

## Phase 4: agentbox Script Änderungen

### 4.1 Agent Selection Variable hinzufügen

**Nach den `readonly` Declarations (~Zeile 180-200)**, füge hinzu:

```bash
# ============================================================================
# Agent Selection
# ============================================================================

# Default agent
DEFAULT_AGENT="claude-code"

# Selected agent (can be overridden by --agent flag)
AGENT="${DEFAULT_AGENT}"
```

### 4.1b Zentrale Agent-Validierungsfunktion hinzufügen

**Nach den Helper Functions (~Zeile 40-63)**, füge hinzu:

```bash
# Validate agent exists and has all required files
# Returns: validated agent name (or fallback agent)
# Exit code: 0 on success, 1 on failure
validate_agent() {
    local agent="$1"
    local agents_dir="${SCRIPT_DIR}/agents.d"
    
    # Check if agent directory exists
    if [[ ! -d "${agents_dir}/${agent}" ]]; then
        # Try fallback to opencode if default agent is not available
        if [[ "${agent}" == "${DEFAULT_AGENT}" ]] && [[ -d "${agents_dir}/opencode" ]]; then
            log_warning "Default agent '${agent}' not available, using 'opencode' instead"
            echo "opencode"
            return 0
        fi
        
        log_error "Agent '${agent}' not found in agents.d/"
        log_info "Available agents:"
        ls -1 "${agents_dir}" | grep -v '^\.' | sed 's/^/  - /' || echo "  (none found)"
        return 1
    fi
    
    # Validate all required files exist
    local required_files=("install.sh" "config" "start.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "${agents_dir}/${agent}/${file}" ]]; then
            log_error "Agent '${agent}' incomplete: ${file} missing"
            log_info "Required files: install.sh, config, start.sh"
            return 1
        fi
    done
    
    # Agent is valid
    echo "${agent}"
    return 0
}
```

### 4.2 Argument Parsing erweitern

**In der `case` Anweisung (~Zeile 415-450)**, füge hinzu:

```bash
        --agent)
            if [[ -z "${2:-}" ]]; then
                log_error "--agent requires an argument"
                exit 1
            fi
            AGENT="$2"
            shift 2
            ;;
        --agent=*)
            AGENT="${1#*=}"
            shift
            ;;
```

### 4.3 Help-Text aktualisieren

**In der `show_help()` Funktion (~Zeile 416-445)**, ändere:

**Zeile ~416** (Titel):
```bash
    cat << EOF
AgentBox - Simplified Docker environment for AI agent development
```

**Nach `--rebuild` Option (~Zeile 438)**, füge hinzu:
```bash
    --agent=<name>                  Select agent to use (default: claude-code)
                                      Available: opencode, claude-code (planned)
```

**Zeile ~437** (Beispiel):
```bash
    agentbox --agent=opencode       # Start OpenCode for current project
    agentbox                         # Start default agent (claude-code, fallback: opencode)
```

### 4.4 Build Function vereinfachen

**Ersetze die `build_image()` Funktion (~Zeile 97-127)** mit:

```bash
build_image() {
    log_info "Building Docker image with agent: ${AGENT}..."
    
    # NO VALIDATION - validate_agent() was already called in main()
    # Agent is guaranteed to be valid at this point
    
    # Calculate hash for rebuild detection (include agent in hash)
    local dockerfile_hash=$(calculate_hash "$DOCKERFILE_PATH")
    local entrypoint_hash=$(calculate_hash "$ENTRYPOINT_PATH")
    local combined_hash="${dockerfile_hash}-${entrypoint_hash}-${AGENT}"
    
    if ! docker build \
        --build-arg AGENTBOX_AGENT="${AGENT}" \
        --build-arg USER_ID="$(id -u)" \
        --build-arg GROUP_ID="$(id -g)" \
        --label "agentbox.hash=${combined_hash}" \
        --label "agentbox.version=1.0.0" \
        --label "agentbox.agent=${AGENT}" \
        -t "$IMAGE_NAME" \
        --progress=plain \
        "${SCRIPT_DIR}"; then
        log_error "Docker build failed - agent installation may have failed"
        return 1
    fi
    
    log_success "Docker image built successfully with agent: ${AGENT}"
    docker image prune -f --filter "label=agentbox.version" &>/dev/null || true
}
```

**Hinweis**: Der Docker build context ist `${SCRIPT_DIR}`, nicht `.` (aktuelles Verzeichnis)!

### 4.5 Volume Setup komplett ersetzen

**Lokalisiere die Volume Setup Logik (~Zeile 305-345)** und ersetze sie:

**Alt** (komplett entfernen):
```bash
    # Agent-specific volume configuration
    local config_volume_name="agentbox-config-${container_name#agentbox-}"
    
    if ! docker volume inspect "$config_volume_name" &>/dev/null; then
        log_info "Creating OpenCode config volume"
        # ... rest of old volume logic ...
    fi
    
    mount_opts+=(-v "${config_volume_name}:/home/claude/.config/opencode")
    mount_opts+=(--env "OPENCODE_CONFIG_DIR=/home/claude/.config/opencode")
    log_info "OpenCode configuration mounted"
```

**Neu** (einfügen):
```bash
    # ========================================================================
    # Agent Configuration Setup (via Metadata)
    # ========================================================================
    
    # NO VALIDATION - Agent was already validated in main() via validate_agent()
    # Agent is guaranteed to exist and have all required files
    
    # Read agent config metadata
    local agents_dir="${SCRIPT_DIR}/agents.d"
    local agent_config_file="${agents_dir}/${AGENT}/config"
    local hash="${container_name#agentbox-}"
    
    # Source config file with variable substitution
    local temp_config=$(mktemp)
    sed -e "s/\${HASH}/${hash}/g" \
        -e "s/\${AGENT}/${AGENT}/g" \
        "${agent_config_file}" > "${temp_config}"
    
    source "${temp_config}"
    rm -f "${temp_config}"
    
    # Validate required variables from config are set
    if [[ -z "${VOLUME_NAME:-}" ]]; then
        log_error "Agent config did not set VOLUME_NAME"
        return 1
    fi
    if [[ -z "${MOUNT_PATH:-}" ]]; then
        log_error "Agent config did not set MOUNT_PATH"
        return 1
    fi
    if [[ -z "${HOST_CONFIG_DIR+x}" ]]; then
        log_error "Agent config did not set HOST_CONFIG_DIR (use empty string if not needed)"
        return 1
    fi
    
    # Create volume if it doesn't exist
    if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
        log_info "Creating agent config volume: ${VOLUME_NAME}"
        docker volume create "$VOLUME_NAME" &>/dev/null
        
        local uid=$(id -u)
        local gid=$(id -g)
        
        # Initialize with global config if it exists and HOST_CONFIG_DIR is set
        if [[ -n "${HOST_CONFIG_DIR:-}" ]] && [[ -d "${HOST_CONFIG_DIR}" ]]; then
            log_info "Copying config from ${HOST_CONFIG_DIR}"
            docker run --rm \
                -v "${HOST_CONFIG_DIR}:/source:ro" \
                -v "${VOLUME_NAME}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                sh -c "cp -r /source/* /dest/ 2>/dev/null || true; chown -R ${uid}:${gid} /dest"
        else
            docker run --rm \
                -v "${VOLUME_NAME}:/dest" \
                --user root \
                "$IMAGE_NAME" \
                chown -R ${uid}:${gid} /dest
        fi
    fi
    
    # Mount agent config volume
    mount_opts+=(-v "${VOLUME_NAME}:${MOUNT_PATH}")
    
    # Pass agent name to container
    mount_opts+=(--env "AGENTBOX_AGENT=${AGENT}")
    
    log_info "Agent '${AGENT}' configuration mounted"
```

### 4.6 Command Execution ändern

**Lokalisiere Command Execution Logic (~Zeile 358-374)** und ersetze den gesamten Block:

**Alt**:
```bash
    # Prepare the command to run
    local container_cmd
    if [[ "$shell_mode" == "true" ]]; then
        if [[ "$admin_mode" == "true" ]]; then
            container_cmd=(bash -c "echo '🔒 Admin shell - sudo access enabled' && exec ${cmd_args[*]:-/bin/zsh}")
        else
            container_cmd=("${cmd_args[@]:-/bin/zsh}")
        fi
    else
        # Run opencode through zsh to get proper environment
        # OpenCode allows all operations by default (no skip-permissions flag needed)
        local opencode_cmd="opencode"
        if [[ ${#cmd_args[@]} -gt 0 ]]; then
            opencode_cmd="$opencode_cmd ${cmd_args[*]}"
        fi
        container_cmd=(zsh -c "source ~/.zshrc && exec $opencode_cmd")
    fi
```

**Neu**:
```bash
    # Prepare the command to run
    local container_cmd
    if [[ "$shell_mode" == "true" ]]; then
        # Shell mode: bypass agent start.sh, run shell directly
        if [[ "$admin_mode" == "true" ]]; then
            container_cmd=(bash -c "echo '🔒 Admin shell - sudo access enabled' && exec ${cmd_args[*]:-/bin/zsh}")
        else
            container_cmd=("${cmd_args[@]:-/bin/zsh}")
        fi
    else
        # Agent mode: entrypoint.sh will call /opt/agentbox/agents.d/${AGENT}/start.sh
        # Pass user arguments (e.g., "chat", "--help") to entrypoint
        # If no args, pass empty - start.sh handles defaults
        container_cmd=("${cmd_args[@]}")
    fi
```

**WICHTIG**: Die Shell-Modus-Logik MUSS erhalten bleiben! Nur der else-Zweig ändert sich.

### 4.7 Main Function - Agent-Validierung einbauen

**Lokalisiere die `main()` Funktion** und füge Agent-Validierung hinzu **NACH** Argument-Parsing, **VOR** dem `check_docker` Aufruf:

**Finde diese Sektion (~Zeile 590-600):**
```bash
    done
    
    # Check Docker
    check_docker
```

**Ersetze durch:**
```bash
    done
    
    # Validate agent early (before docker operations)
    # This is the ONLY place where agent validation happens
    AGENT=$(validate_agent "${AGENT}") || exit 1
    
    # Check Docker
    check_docker
```

**Wichtig**: Diese eine Zeile ersetzt ALLE Validierungen in `build_image()` und `run_container()`. Ab hier ist `AGENT` garantiert valide.

### 4.8 Cleanup Function aktualisieren

**Cleanup Function bleibt größtenteils gleich**, stelle nur sicher dass Volume-Pattern `agentbox-config-*` erkannt wird:

```bash
cleanup() {
    log_warning "This will remove ALL AgentBox containers and volumes"
    echo -n "Are you sure? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi

    log_info "Stopping and removing AgentBox containers..."
    docker ps -a --filter "name=agentbox-" --format "{{.Names}}" | \
        xargs -r docker rm -f 2>/dev/null || true

    log_info "Removing AgentBox config volumes..."
    docker volume ls -q | grep "^agentbox-config-" | \
        xargs -r docker volume rm 2>/dev/null || true

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

    log_success "Cleanup complete"
}
```

---

## Phase 5: entrypoint.sh Änderungen

### 5.1 Git Identity hart codieren

**Lokalisiere Git Config Setup (~Zeile 63-70)** und ändere:

**Alt**:
```bash
    cat > /home/claude/.gitconfig << 'EOF'
[user]
    name = Claude
    email = claude@agentbox
EOF
```

**Neu**:
```bash
    cat > /home/claude/.gitconfig << 'EOF'
[user]
    name = AI Agent (AgentBox)
    email = agent@agentbox
EOF
```

### 5.2 Welcome Message entfernen

**Lokalisiere und ENTFERNE die gesamte Welcome Section (~Zeile 95-105)**:

```bash
# Welcome message
echo "════════════════════════════════════════════════════════════════"
echo "🤖 OpenCode: $(opencode --version 2>/dev/null || echo 'not found - check installation')"
# ... weitere echo statements ...
echo "════════════════════════════════════════════════════════════════"
```

Ersetze durch einen Kommentar:
```bash
# Welcome message is handled by agent-specific start.sh hook
```

### 5.3 MCP Detection entfernen

**Lokalisiere und ENTFERNE MCP Detection (~Zeile 76-80)**:

```bash
# Check for MCP configuration
if [ -f "/workspace/.mcp.json" ] || [ -f "/workspace/mcp.json" ] || \
   [ -f "/workspace/opencode.json" ] || grep -q '"mcp"' /workspace/opencode.json 2>/dev/null; then
    echo "🔌 MCP configuration detected in opencode.json"
fi
```

Komplett entfernen (MCP Detection passiert jetzt in start.sh).

### 5.4 Agent Start Hook aufrufen

**Lokalisiere das Ende der Datei (~letzte Zeile)**:

**Alt**:
```bash
# Execute the command
exec "$@"
```

**Neu**:
```bash
# ============================================================================
# Agent Start Hook
# ============================================================================

# Determine agent from environment variable (set by agentbox script)
AGENT="${AGENTBOX_AGENT:-opencode}"

# Minimal validation as safety net (container could be misconfigured)
AGENT_START_SCRIPT="/opt/agentbox/agents.d/${AGENT}/start.sh"

if [ ! -f "${AGENT_START_SCRIPT}" ]; then
    echo "ERROR: Agent start script not found: ${AGENT_START_SCRIPT}"
    echo "Container was built incorrectly or agent '${AGENT}' is incomplete"
    echo ""
    echo "Available agents in this container:"
    ls -1 /opt/agentbox/agents.d/ 2>/dev/null | grep -v '^\.' || echo "  (none found)"
    exit 1
fi

# Make start script executable
chmod +x "${AGENT_START_SCRIPT}"

# Execute agent start script (which handles welcome, MCP detection, and agent start)
exec "${AGENT_START_SCRIPT}" "$@"
```

**Hinweis**: Keine Fallback-Logik mehr - wenn der Agent nicht im Container existiert, ist das ein Build-Fehler.

---

## Phase 6: Testing & Validation

### 6.1 Build Test

```bash
# Clean rebuild mit OpenCode
./agentbox --rebuild --agent=opencode
```

**Erwartetes Ergebnis**:
- ✅ Docker build erfolgreich
- ✅ `Installing OpenCode...` erscheint
- ✅ `OpenCode installed successfully: ...` mit Version
- ✅ Keine Fehler

### 6.2 Start Test

**Test 1: Standard Start**
```bash
./agentbox --agent=opencode
```

**Erwartetes Ergebnis**:
- ✅ Welcome Message von `start.sh` erscheint
- ✅ OpenCode TUI startet

**Test 2: Mit Arguments**
```bash
./agentbox --agent=opencode chat
```

**Erwartetes Ergebnis**:
- ✅ OpenCode startet im Chat-Mode

**Test 3: Default Agent (mit Fallback)**
```bash
./agentbox
```

**Erwartetes Ergebnis**:
- ⚠️ Warning: "Default agent 'claude-code' not available, using 'opencode' instead"
- ✅ OpenCode startet

### 6.3 Volume Persistence Test

```bash
# Test 1: Volume wird erstellt
./agentbox --agent=opencode shell

# Im Container:
ls -la ~/.config/opencode
# Sollte existieren

# Datei erstellen
echo "test-$(date)" > ~/.config/opencode/test.txt
cat ~/.config/opencode/test.txt
exit

# Test 2: Persistence
./agentbox --agent=opencode shell
cat ~/.config/opencode/test.txt
# Sollte gleichen Inhalt haben
exit
```

**Erwartetes Ergebnis**:
- ✅ Volume existiert
- ✅ Datei bleibt nach Container-Neustart

### 6.4 Multi-Project Isolation Test

```bash
# Terminal 1
mkdir -p /tmp/agentbox-test-project-a
cd /tmp/agentbox-test-project-a
./agentbox --agent=opencode shell &

# Terminal 2
mkdir -p /tmp/agentbox-test-project-b
cd /tmp/agentbox-test-project-b
./agentbox --agent=opencode shell &

# Prüfe Container
docker ps | grep agentbox

# Sollte zwei verschiedene Container zeigen
# Prüfe Volumes
docker volume ls | grep agentbox-config

# Sollte zwei verschiedene Volumes zeigen
```

**Erwartetes Ergebnis**:
- ✅ Zwei Container laufen parallel
- ✅ Zwei verschiedene Volumes
- ✅ Verschiedene Container-Hashes

### 6.5 MCP Detection Test

```bash
# Test Setup
mkdir -p /tmp/agentbox-mcp-test
cd /tmp/agentbox-mcp-test

# OpenCode config mit MCP erstellen
cat > opencode.json << 'EOF'
{
  "mcp": {
    "filesystem": {
      "type": "local"
    }
  }
}
EOF

# Test
./agentbox --agent=opencode
```

**Erwartetes Ergebnis**:
- ✅ Welcome Message
- ✅ "🔌 MCP configuration detected in opencode.json"
- ✅ OpenCode startet

### 6.6 Error Handling Tests

**Test 1: Ungültiger Agent**
```bash
./agentbox --rebuild --agent=nonexistent
```

**Erwartetes Ergebnis**:
- ❌ ERROR: Agent 'nonexistent' not found in agents.d/
- ℹ️ Available agents: (Liste)

**Test 2: Agent ohne install.sh**
```bash
mkdir -p agents.d/broken
./agentbox --rebuild --agent=broken
```

**Erwartetes Ergebnis**:
- ❌ ERROR: Agent 'broken' incomplete: install.sh missing

**Test 3: config fehlt**
```bash
mkdir -p agents.d/broken2
touch agents.d/broken2/install.sh
touch agents.d/broken2/start.sh
./agentbox --rebuild --agent=broken2
```

**Erwartetes Ergebnis**:
- ❌ ERROR: Agent 'broken2' incomplete: config missing

**Test 4: config setzt VOLUME_NAME nicht**
```bash
mkdir -p agents.d/broken3
cat > agents.d/broken3/config << 'EOF'
MOUNT_PATH=/test
EOF
./agentbox --agent=broken3
```

**Erwartetes Ergebnis**:
- ❌ ERROR: Agent config did not set VOLUME_NAME

### 6.7 Cleanup Test

```bash
# Volumes erstellen
./agentbox --agent=opencode shell
exit

# Prüfe Volumes vor Cleanup
docker volume ls | grep agentbox-config

# Cleanup
./agentbox --cleanup
# Confirm: y

# Prüfe Volumes nach Cleanup
docker volume ls | grep agentbox-config
# Sollte leer sein
```

**Erwartetes Ergebnis**:
- ✅ Alle agentbox-config-* Volumes entfernt

---

## Zusammenfassung der Änderungen

### Neue Dateien
```
agents.d/
├── .template/
│   ├── install.sh
│   ├── config           # NEU: Metadaten statt setup-config.sh
│   ├── start.sh
│   └── README.md
├── opencode/
│   ├── install.sh
│   ├── config           # NEU: Metadaten statt setup-config.sh
│   └── start.sh
└── README.md
```

### Geänderte Dateien
```
Dockerfile          - Vereinfacht: nur chmod + install.sh (keine Validierung)
agentbox            - Zentrale validate_agent() Funktion (Phase 4.1b)
                    - Validierung einmal in main() (Phase 4.7)
                    - build_image() ohne Validierung (Phase 4.4)
                    - run_container() ohne Agent-Validierung (Phase 4.5)
entrypoint.sh       - Minimale Validierung als Safety-Net
                    - Ruft start.sh Hook auf
```

### Entfernte Konzepte
```
setup-config.sh         - Ersetzt durch config (Metadaten-Datei)
Convention              - Keine Defaults, alle Werte explizit in config
```

---

## Erfolgs-Kriterien

Siehe [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md#erfolgs-kriterien) für die vollständige Liste.

---

## Quick Reference für neue Session

1. Phase 0 ist abgeschlossen
2. Starte mit **Phase 1** (Verzeichnisstruktur & Templates)
3. Arbeite Phasen **sequenziell** ab
4. Teste nach jeder Phase
