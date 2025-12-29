# Current Work: Hook-based Architecture Implementation

**Status**: Phase 1 Complete - Ready for Phase 2  
**Updated**: 2025-12-29

---

## Quick Start (Neue Session)

1. **Phase 1 ist abgeschlossen** - Dokumentation & Templates erstellt
2. **Starte mit Phase 2** - Dockerfile & agentbox Script Änderungen
3. **Lies den Implementierungsplan**: [`HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md`](HOOK_ARCHITECTURE_IMPLEMENTATION_PLAN.md)
4. **Beachte die Stolpersteine** (Sektion im Plan!)
5. **Teste nach jeder Phase**

---

## Phasen-Status

| Phase | Beschreibung | Status |
|-------|--------------|--------|
| 0 | Dokumentation überarbeiten | ✅ Done |
| 1 | Verzeichnisstruktur & Templates | ✅ Done |
| 2 | Dockerfile & agentbox Script | ⏳ Next |
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
- **Agents Directory**: [`agents.d/README.md`](agents.d/README.md)
