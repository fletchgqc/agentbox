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
   # npm ist global verfügbar
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

3. **WICHTIG: Executable machen** (erforderlich!):
   ```bash
   chmod +x agents.d/my-agent/install.sh
   chmod +x agents.d/my-agent/start.sh
   ```
   
   **Hinweis**: Docker's `COPY` Befehl behält Datei-Permissions bei. Die Scripts müssen auf dem Host executable sein, da `chmod` im Container fehlschlagen kann.

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
   - [ ] Scripts sind executable (`ls -l agents.d/my-agent/*.sh` zeigt `-rwxr-xr-x`)
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
**Lösung**: Scripts müssen auf dem Host executable gemacht werden:
```bash
chmod +x agents.d/my-agent/*.sh
```

### chmod Operation not permitted (im Docker Build)
```
chmod: changing permissions of '/opt/agentbox/agents.d/my-agent/install.sh': Operation not permitted
```
**Ursache**: Scripts wurden bereits vom Host mit korrekten Permissions kopiert.  
**Lösung**: Stelle sicher, dass Scripts auf dem Host executable sind (`chmod +x`). Docker's `COPY` behält Permissions bei - kein `chmod` im Dockerfile/entrypoint nötig.

## Weitere Dokumentation

- **Architektur**: `../HOOK_ARCHITECTURE.md`
- **Implementierungsplan**: `../HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`
- **Template-Guide**: `.template/README.md`
- **Development Notes**: `../DEVELOPMENT_NOTES.md`
