# Proposal: surface-swallowed-errors

## Intent

Hay 38 usos de `try?` en `Sources/Focally/` que silencian fallos: persistencia de sesión (`SessionPersistenceService`), encode/decode (`FocusMode`, `PersistedCalendarMetricsDraft`), shortcuts (`ManagedFocusShortcutsService`), etc. Un disco lleno o JSON corrupto hoy pierde una sesión activa sin ninguna traza. Este change NO cambia comportamientos: hace visibles los fallos.

## What Changes

- Auditoría de los 38 `try?`: cada uno se clasifica en (a) fallo debe loguearse + continuar (persistencia best-effort), (b) fallo debe loguearse + recuperarse (borrar dato corrupto y regenerar), o (c) el silencio es correcto y se documenta con comentario.
- Todos los catch de (a)/(b) loguean con el wrapper `Logger` (categoría del servicio correspondiente), incluyendo el error subyacente.
- Para persistencia: corrupción detectada → mover el archivo a `.corrupt-<timestamp>` y regenerar; fallo transitorio → reintentar una vez antes de loguear y continuar.

**BREAKING: ninguno.**

## Capabilities

- **Nueva:** `error-visibility`

## Impact

- Múltiples archivos de `Sources/Focally/` (solo líneas de catch/log; sin cambios de firma ni de flujo)
- Tests: 1 test de corrupción→regeneración en `SessionPersistenceService`
