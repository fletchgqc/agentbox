# AgentBox Hook-based Architecture

**Version**: 2.0.0  
**Created**: 2025-12-28  
**Updated**: 2025-12-28 (Revision 2: 2 Hooks + Metadata)  
**Status**: Active

---

## Overview

AgentBox verwendet eine **Hook-basierte Architektur** für maximale Flexibilität beim Austausch von CLI Agents.

## Problem mit der alten Architektur

Die vorherige config-basierte Architektur (`agents.conf.d/*.conf`) hatte mehrere Nachteile:
- Viele Variablen (20+) pro Agent
- Änderungen an mehreren Stellen notwendig
- Schwer zu verstehen und zu warten
- Tight Coupling zwischen AgentBox und Agent-Details

## Lösung: Hook-basierte Architektur

### Konzept

Statt Konfigurationsvariablen definiert jeder Agent **2 Hooks + 1 Metadaten-Datei**:

1. **install.sh** - Installation im Container (Hook)
2. **config** - Volume/Config-Metadaten (Datei)
3. **start.sh** - Welcome + MCP Detection + Agent Start (Hook)

### Vorteile

- ✅ **Minimale Kopplung**: Nur 2 Hooks + 1 Metadaten-Datei
- ✅ **Klare Trennung**: Scripts (imperative) vs. Metadaten (deklarativ)
- ✅ **Maximale Flexibilität**: Agents definieren eigene Pfade
- ✅ **Explizit**: Keine Conventions, alle Werte müssen gesetzt sein
- ✅ **Keine Core-Änderungen**: Neue Agents = neue Dateien

## Interface-Spezifikation

### 1. install.sh (Hook)

**Zweck**: Agent im Docker Container installieren

**Aufgerufen**: Während `docker build`

**Input**: Keine

**Output**: Exit code 0 bei Erfolg

**Beispiel**:
```bash
#!/bin/bash
set -euo pipefail
npm install -g opencode-ai
opencode --version
```

### 2. config (Metadaten)

**Zweck**: Volume- und Config-Pfade definieren

**Aufgerufen**: In `agentbox` script vor `docker run` (via `source`)

**Format**: Key-Value Paare (Bash-Variablen)

**Verpflichtende Variablen**:
- `VOLUME_NAME` - Docker Volume Name
- `MOUNT_PATH` - Mount-Pfad im Container
- `HOST_CONFIG_DIR` - Config-Verzeichnis auf Host (kann leer sein `""`)

**Platzhalter** (werden von AgentBox ersetzt):
- `${HASH}` - Container-Hash (z.B. "abc123")
- `${AGENT}` - Agent-Name (z.B. "opencode")

**WICHTIG**: Alle 3 Variablen müssen gesetzt sein (keine Defaults)!

**Hinweis**: `HOST_CONFIG_DIR` kann leer sein (`""`), muss aber explizit gesetzt werden.

**Beispiel**:
```bash
# OpenCode Configuration Metadata
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.config/opencode"
HOST_CONFIG_DIR="${HOME}/.config/opencode"
```

**Beispiel mit leerem HOST_CONFIG_DIR**:
```bash
# Agent ohne Host-Config-Initialisierung
VOLUME_NAME="agentbox-config-${HASH}"
MOUNT_PATH="/home/claude/.some-agent"
HOST_CONFIG_DIR=""  # Keine Host-Config zum Kopieren
```

### 3. start.sh (Hook)

**Zweck**: Agent starten (inkl. Welcome Message + MCP Detection)

**Aufgerufen**: Von `entrypoint.sh` als letzter Schritt

**Input**: `$@` = User-Argumente (z.B. "chat", "--help")

**Output**: Startet den Agent (sollte mit `exec` enden)

**Sollte enthalten**:
1. Welcome Message anzeigen
2. MCP Configuration Detection (optional)
3. Agent starten (mit `exec`)

**Beispiel**:
```bash
#!/bin/bash
set -euo pipefail

# Welcome Message
echo "🤖 OpenCode: $(opencode --version)"

# MCP Detection
if [ -f "/workspace/opencode.json" ] && grep -q '"mcp"' /workspace/opencode.json; then
    echo "🔌 MCP configuration detected"
fi

# Start Agent
exec opencode "$@"
```

## Lifecycle & Datenfluss

```
User Command
    ↓
./agentbox --agent=opencode
    ↓
┌─────────────────────────────┐
│ Build Phase (Dockerfile)    │
│ - COPY agents.d/            │
│ - RUN install.sh            │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Runtime Phase (agentbox)    │
│ - Read config metadata      │
│ - Substitute placeholders   │
│ - Create volumes            │
│ - docker run ...            │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Container Start (entrypoint)│
│ - SSH setup                 │
│ - direnv setup              │
│ - exec start.sh             │
└─────────────┬───────────────┘
              ↓
┌─────────────────────────────┐
│ Agent Running               │
│ (OpenCode/Claude/etc)       │
└─────────────────────────────┘
```

## Multi-Agent Isolation

Verschiedene Projekte können gleichzeitig verschiedene Agents nutzen:

```
Project A                    Project B
/home/user/project-a        /home/user/project-b
    ↓                            ↓
./agentbox --agent=opencode      ./agentbox --agent=claude-code
    ↓                            ↓
Container: agentbox-abc123       Container: agentbox-def456
Volume: agentbox-config-abc123   Volume: agentbox-config-def456
Binary: opencode                 Binary: claude
```

## Neuen Agent hinzufügen

```bash
# 1. Template kopieren
cp -r agents.d/.template agents.d/my-agent

# 2. Dateien anpassen (install.sh, config, start.sh)

# 3. Executable machen
chmod +x agents.d/my-agent/*.sh

# 4. Testen
./agentbox --rebuild --agent=my-agent
./agentbox --agent=my-agent
```

Keine Core-Code-Änderungen notwendig.

**Detaillierte Anleitung**: Siehe [`agents.d/README.md`](agents.d/README.md)

## Agent Selection

### CLI Flag (empfohlen)
```bash
./agentbox --agent=opencode
./agentbox --agent=claude-code
```

### Default Agent
Wenn kein `--agent` Flag angegeben wird, wird `claude-code` verwendet.  
Falls `claude-code` nicht verfügbar ist, wird automatisch auf `opencode` zurückgefallen.

## Verzeichnisstruktur

```
agents.d/
├── .template/          # Template für neue Agents
│   ├── install.sh      # Installation Hook
│   ├── config          # Metadaten (Key-Value)
│   ├── start.sh        # Start Hook
│   └── README.md       # Template-Anleitung
├── opencode/           # OpenCode Implementation
│   ├── install.sh
│   ├── config
│   └── start.sh
├── claude-code/        # Claude Code (geplant)
└── README.md           # Agents Directory Docs
```

## Design Principles

### 1. Explizit über Implizit
- Keine Conventions oder Defaults
- Alle Werte müssen explizit in `config` gesetzt sein
- Klares Verhalten, keine Überraschungen

### 2. Separation of Concerns
- **Hooks (Scripts)**: Imperative Logik (was tun?)
- **Metadaten (config)**: Deklarative Daten (wo, wie?)

### 3. Minimal Interface
- Nur 2 Hooks + 1 Metadaten-Datei
- Jede Datei hat EINE klare Aufgabe
- Kein Overhead

### 4. Flexibilität
- Agents können beliebige Pfade verwenden
- Platzhalter für dynamische Werte
- Optionale Werte können leer sein

## Erfolgs-Kriterien

Die Hook-basierte Architektur ist erfolgreich, wenn:

- ✅ Neuer Agent in <10 Minuten hinzugefügt (Template kopieren + anpassen)
- ✅ Keine hard-coded Agent-Referenzen in Core-Files (außer Default)
- ✅ Multi-Agent Support funktioniert out-of-the-box
- ✅ Alle 3 config-Variablen sind verpflichtend (explizit)
- ✅ Alle Tests bestehen (Build, Start, Volume, Multi-Project)

## Referenzen

- [`agents.d/README.md`](agents.d/README.md) - Agent-Entwicklung (Anleitung + Troubleshooting)
- [`HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`](HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md) - Implementierungsplan (Templates, Code-Snippets, Tests)
