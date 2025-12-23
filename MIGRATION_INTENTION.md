# Migration Intention: Claude Code → OpenCode

**Projekt**: AgentBox  
**Migration**: Von Claude Code zu OpenCode  
**Datum**: 2024-12-23  
**Status**: Planung abgeschlossen, Implementierung ausstehend  

---

## 🎯 Warum diese Migration?

### Ausgangssituation
AgentBox ist ein vereinfachtes Docker-Environment für AI-Coding-Agents. Es wurde ursprünglich für **Claude Code** (Anthropic's proprietärer CLI) entwickelt, um sichere Container-Isolation zu ermöglichen.

### Motivation für OpenCode

**OpenCode** ist ein Open-Source AI-Coding-Agent mit folgenden Vorteilen:

1. **Open Source**: 41K+ GitHub Stars, vollständig transparent
2. **Multi-Provider**: Unterstützt 75+ LLM-Provider (Anthropic, OpenAI, Google, lokale Modelle)
3. **Flexibilität**: TUI, Desktop App, IDE Extensions
4. **Community**: Aktive Entwicklung, keine Vendor-Lock-in
5. **Gleiche Philosophie**: Container-Isolation für sichere Agent-Operationen

### Projektziele bleiben gleich
- ✅ Container-Isolation für AI-Agents
- ✅ Sichere "YOLO-Mode" Nutzung ohne Risiko
- ✅ Per-Projekt Isolation
- ✅ Persistente Caches und History
- ✅ Einfache, wartbare Codebasis

---

## 📊 Technischer Vergleich

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| **Lizenz** | Proprietär (Anthropic) | Open Source (MIT) |
| **Provider** | Nur Anthropic/Claude | 75+ Provider |
| **Installation** | `@anthropic-ai/claude-code` | `opencode-ai` |
| **Befehl** | `claude` | `opencode` |
| **Permissions** | `--dangerously-skip-permissions` Flag | Standardmäßig allow-all |
| **Config** | `~/.claude/` | `~/.config/opencode/` |
| **Auth** | In config-dir | `~/.local/share/opencode/auth.json` |
| **MCP** | Custom Format | Native, RFC-konform |
| **Projekt-Setup** | `CLAUDE.md` | `AGENTS.md` |

---

## 🔧 Migrations-Strategie

### Entscheidungen (mit User abgestimmt)

1. **Username im Container**: Bei "claude" belassen
   - **Grund**: Minimale Änderungen, viele Pfade betroffen, Name ist nur historisch

2. **Volume-Namen**: Neutral → `agentbox-config-<hash>`
   - **Grund**: Provider-unabhängig, zukunftssicher, nicht "opencode-spezifisch"

3. **Permissions**: Explizit maximale Freiheit (allow all)
   - **Grund**: Analog zu bisherigem `--dangerously-skip-permissions` Ansatz
   - **Config**: `"edit": "allow"`, `"bash": "allow"`, etc.

4. **GitHub Actions**: Ignorieren (nicht anpassen)
   - **Grund**: Nicht essentiell, OpenCode GitHub Action existiert möglicherweise nicht

5. **Migration**: Clean Break, keine Rückwärtskompatibilität
   - **Grund**: Einfachheit, Test-Projekt, keine Production-User betroffen

### Implementierungs-Phasen

1. **Phase 1**: Docker Image (Dockerfile)
2. **Phase 2**: Container Scripts (entrypoint.sh)
3. **Phase 3**: Main Script (agentbox)
4. **Phase 4**: Dokumentation (README, DEVELOPMENT_NOTES)
5. **Phase 5**: Neue Dateien (opencode.json.example)
6. **Phase 6**: Testing & Validation

---

## 📂 Betroffene Dateien

### Core-Dateien (müssen geändert werden)
- ✅ `Dockerfile` - NPM package, version check
- ✅ `entrypoint.sh` - Welcome message, MCP detection
- ✅ `agentbox` - Volume names, command execution, config mounting
- ✅ `README.md` - Komplette Dokumentation
- ✅ `DEVELOPMENT_NOTES.md` - Technische Details

### Optionale Dateien
- ⚪ `CLAUDE.md` → `OPENCODE.md` umbenennen
- ⚪ `.gitignore` erweitern

### Neue Dateien
- ➕ `opencode.json.example` - Beispiel-Konfiguration
- ➕ `MIGRATION_PLAN.md` - Dieser Implementierungsplan
- ➕ `MIGRATION_INTENTION.md` - Dieses Dokument

### Nicht betroffen (bewusst ignoriert)
- ❌ `.github/workflows/claude.yml` - GitHub Actions
- ❌ `.github/workflows/claude-code-review.yml` - GitHub Actions

---

## 🎯 Erfolgskriterien

Die Migration gilt als erfolgreich, wenn:

1. ✅ **Docker Image baut**: `./agentbox --rebuild` erfolgreich
2. ✅ **OpenCode installiert**: `opencode --version` funktioniert im Container
3. ✅ **Container startet**: `./agentbox` öffnet OpenCode TUI
4. ✅ **Shell funktioniert**: `./agentbox shell` startet mit OpenCode verfügbar
5. ✅ **Auth funktioniert**: `opencode auth login` konfiguriert Provider
6. ✅ **File Ops**: OpenCode kann Dateien lesen/schreiben in /workspace
7. ✅ **SSH funktioniert**: Git operations über SSH keys
8. ✅ **Isolation**: Mehrere Projekte gleichzeitig isoliert
9. ✅ **Persistence**: Config bleibt nach Container-Neustart
10. ✅ **Cleanup**: `./agentbox --cleanup` entfernt neue Volumes

---

## 🚀 Für neue Session: Wie weiter machen?

### Schnellstart

1. **Lies dieses Dokument** (`MIGRATION_INTENTION.md`) - Kontext verstehen
2. **Lies den Plan** (`MIGRATION_PLAN.md`) - Was zu tun ist
3. **Prüfe Status**: Welche Checkboxen in `MIGRATION_PLAN.md` sind erledigt?
4. **Starte Phase 1**: Dockerfile anpassen (nur 2 Zeilen!)
5. **Test nach jeder Phase**: Inkrementell validieren

### Kommandos für Testing

```bash
# Nach Phase 1 (Docker):
./agentbox --rebuild

# Nach Phase 2+3 (Scripts):
./agentbox shell
# Im Container:
opencode --version

# Nach allem:
./agentbox
# Sollte OpenCode TUI starten

# Cleanup testen:
./agentbox --cleanup
docker volume ls | grep agentbox
```

### Wichtige Dateien

- **Plan**: `MIGRATION_PLAN.md` - Vollständige Checkliste
- **Context**: `MIGRATION_INTENTION.md` - Dieses Dokument
- **Docs**: `AGENTS.md` - Für AI-Agents (bereits existiert!)
- **Dev Notes**: `DEVELOPMENT_NOTES.md` - Technisches
- **Code Style**: `AGENTS.md` - Bash Style Guidelines

---

## 💡 Wichtige Hinweise für Implementierung

### OpenCode Besonderheiten

1. **Kein Skip-Permissions Flag**: OpenCode erlaubt standardmäßig alles
   - Entferne `--dangerously-skip-permissions` komplett
   
2. **Config-Verzeichnis**: OpenCode nutzt XDG-Standard
   - `~/.config/opencode/` statt `~/.claude/`
   
3. **Auth separat**: Authentication ist in eigenem Verzeichnis
   - `~/.local/share/opencode/auth.json`
   - Aktuell: Nur `~/.config/opencode` mounten (auth erfolgt im Container)
   
4. **MCP Native**: OpenCode hat bessere MCP-Integration
   - Config in `opencode.json` mit `"mcp"` key
   - Keine Extra-Tools nötig

### Potenzielle Stolpersteine

⚠️ **OpenCode könnte `~/.local/share/opencode` benötigen**
- Lösung: Falls nötig, zweiten Volume-Mount hinzufügen
- Test: Nach Phase 3 prüfen, ob Auth funktioniert

⚠️ **Config-Format könnte anders sein**
- Lösung: `opencode.json.example` in Phase 5 testen
- Test: Im Container OpenCode starten und config laden

⚠️ **Volume-Migration für alte User**
- Bewusste Entscheidung: Clean Break
- Alte `agentbox-claude-*` Volumes werden NICHT automatisch migriert
- User müssen manuell cleanup machen

---

## 📖 Referenzen

- **OpenCode Docs**: https://opencode.ai/docs
- **OpenCode GitHub**: https://github.com/opencodelabs/opencode (angenommen)
- **AgentBox Origin**: ClaudeBox (https://github.com/RchGrav/claudebox)
- **Current Branch**: `use-opencode-instead-of-claude-code`

---

## 🎬 Nächster konkreter Schritt

**Wenn du in einer neuen Session weitermachst:**

1. Öffne `MIGRATION_PLAN.md`
2. Suche nach "⏳ TODO" für nächste Aufgabe
3. Starte mit **Phase 1: Docker Image** (nur 2 Zeilen!)
4. Teste mit `./agentbox --rebuild`
5. Markiere erledigte Items als "✅ DONE" in `MIGRATION_PLAN.md`

**Erster konkreter Code-Edit**:
```bash
# Datei: Dockerfile, Zeile 211
# Ändere:
npm install -g @anthropic-ai/claude-code
# Zu:
npm install -g opencode-ai
```

Viel Erfolg! 🚀
