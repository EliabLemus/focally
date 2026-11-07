# TASK-062 STATUS — surface-swallowed-errors

## Clasificación (~22 sitios en 9 archivos, comentarios `TASK-062 (a/b/c)`)

| Archivo | Sitios | Clase | Tratamiento |
|---|---|---|---|
| SessionPersistenceService.swift | load/save/clear | (b) log+recuperar / (a) log+continuar / (c) justificado | load: log + cuarentena `.corrupt-<timestamp>` + regeneración en próximo save; save: log I/O best-effort; clear: silencio solo si archivo no existe |
| FocusMode.swift | 5 | (c) | comentarios justificativos |
| FocusMetricsService.swift | 3 | (c) | comentarios |
| CalendarMetricsTracker.swift | 2 | (c) | comentarios |
| FocusTypesService.swift | 2 | (c) | comentarios |
| CallDetectionSettings.swift | 2 | (c) | comentarios |
| SlackService.swift | 4 | (c) | regex/encode/recent emojis: comentarios |
| EmojiCacheService.swift | 3 | (c) | comentarios |
| ManagedFocusShortcutsService.swift | 2 | (c) | comentarios |

## Notas
- Logging vía `Logger.app` (wrapper existente, init privado).
- Sin cambios de firmas ni de flujos; DND/Ticker/CalendarChangeMonitor sin tocar (otros agentes).
- Test nuevo: `testCorruptJSONIsQuarantinedAndSessionRegenerates`.
- Suite: 95/95 en este worktree (base a11207a).
