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
