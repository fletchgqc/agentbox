# Current Work: Hook-based Architecture Implementation

**Status**: Ready for Implementation  
**Updated**: 2025-12-29

---

## Quick Start (Neue Session)

1. **Lies den Implementierungsplan**: [`HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`](HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md)
2. **Beachte die Stolpersteine** (Sektion im Plan!)
3. **Starte mit Phase 1** (Phase 0 ist abgeschlossen)
4. **Teste nach jeder Phase**

---

## Phasen-Status

| Phase | Beschreibung | Status |
|-------|--------------|--------|
| 0 | Dokumentation überarbeiten | ✅ Done |
| 1 | Verzeichnisstruktur & Templates | ⏳ Next |
| 2 | OpenCode Agent Implementation | ⏳ Pending |
| 3 | Dockerfile Änderungen | ⏳ Pending |
| 4 | agentbox Script Änderungen | ⏳ Pending |
| 5 | entrypoint.sh Änderungen | ⏳ Pending |
| 6 | Testing & Validation | ⏳ Pending |

---

## ⚠️ Bekannte Stolpersteine

Der Implementierungsplan enthält eine Sektion "Bekannte Stolpersteine" mit kritischen Hinweisen:

1. **Shell-Modus** muss separat behandelt werden (nicht an start.sh weiterreichen)
2. **Pfade** müssen `${SCRIPT_DIR}/agents.d/` verwenden (nicht relativ)
3. **HOST_CONFIG_DIR** muss auf Existenz geprüft werden (auch wenn leer)
4. **Ein Image = Ein Agent** (Wechsel erfordert --rebuild)

---

## Wichtige Dateien

- **Architektur**: [`HOOK_ARCHITECTURE.md`](HOOK_ARCHITECTURE.md)
- **Implementierungsplan**: [`HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`](HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md)
