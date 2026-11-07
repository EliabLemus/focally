# Delta spec: dnd-control-shortcuts-first

## ADDED Requirements

### Requirement: En macOS 14+ el shortcut es la vía primaria de activación de Focus

En macOS 14 o superior, el sistema SHALL activar/desactivar el modo Focus mediante el shortcut firmado "Set Focus by Name" (Layer 3 existente) como primera capa, y SHALL NOT reportar éxito basándose en la escritura CFPreferences legacy.

#### Scenario: Activación en macOS 15

- **WHEN** Focally activa DND en macOS 14+ y el shortcut `runFocusByName` termina sin error
- **THEN** la activación se marca como exitosa sin escribir CFPreferences

#### Scenario: Falla del shortcut escala

- **WHEN** el shortcut falla o excede el timeout en macOS 14+
- **THEN** se ejecuta la escalación existente (retry, luego alerta de pérdida de permiso) — sin degradar silenciosamente a CFPreferences

### Requirement: CFPreferences es fallback solo para macOS ≤ 13

La escritura CFPreferences (`DNDService`) SHALL ejecutarse únicamente como fallback en macOS 13 o anterior, y su resultado MUST NOT contar como verificación de estado.

#### Scenario: Verificación independiente de la escritura

- **WHEN** cualquier capa reporta activación
- **THEN** la verificación de estado real usa la lectura del Control Center (`NSStatusItem Visible FocusModes`) o la heurística de assertions — nunca el valor que la propia capa escribió

#### Scenario: macOS legacy conserva la vía actual

- **WHEN** el sistema corre macOS ≤ 13
- **THEN** CFPreferences sigue siendo la capa primaria con su verificación actual
