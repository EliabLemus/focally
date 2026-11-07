# Proposal: switch-dnd-shortcuts-primary

## Intent

La Layer 1 actual (`DNDService`) escribe `doNotDisturb`/`doNotDisturbDate` en CFPreferences de `com.apple.notificationcenterui` — un path legacy pre-Monterey que macOS 12+ ignora (el estado real vive en `~/Library/DoNotDisturb/DB/Assertions.json` + `donotdisturbd`). Además la verificación lee la misma pref que el propio servicio escribió (auto-validación, falso positivo). La única vía que funciona en macOS moderno es Layer 3 (shortcut firmado "Set Focus by Name"). Este change reordena las capas: Shortcuts primario en macOS 14+, CFPreferences degradado a fallback legacy.

## What Changes

- `DNDReliabilityService`: en macOS 14+, Layer 1 = shortcut (Layer 3 actual, ya firmado por máquina); CFPreferences SOLO para macOS ≤ 13 como fallback degradado.
- Verificación (Layer 2) deja de leer la pref escrita: se verifica con la lectura del Control Center ya existente (`NSStatusItem Visible FocusModes`) + heurística de assertions si disponible; la escritura CFPreferences deja de contar como "activado".
- La escalación (retry/timeout ya existentes) se aplica desde la primera capa en macOS 14+.

**BREAKING: ninguno** — API de activación/desactivación sin cambios.

## Capabilities

- **Modificada:** `dnd-control` (reorden de capas) — si no existe spec previo de esta capability, se crea con este delta como ADDED sobre la nueva capability `dnd-control-shortcuts-first`.

## Impact

- `Sources/Focally/Services/DNDReliabilityService.swift` (reorden de layers + verificación honesta)
- `Sources/Focally/Services/DNDService.swift` (queda como implementación legacy-tier, no como primaria)
- Tests de `DNDReliabilityTests.swift` (escenarios de escalación por tier de OS)
