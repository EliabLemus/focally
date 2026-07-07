---
id: TASK-038
created: 2026-05-05T22:45:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-038: Replace manual shortcut bridge with honest Focus architecture + App Intents base

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6, SwiftUI, AppKit, macOS 14+
- Runtime check: `swift --version`
- Tests: `xcodebuild -scheme Focally -configuration Debug build`

## Archivos relevantes
- `SPEC_FOCUS_INTEGRATION_FINAL_DECISION.md` — conclusión técnica final que corrige la dirección de producto/arquitectura
- `SPEC_NATIVE_FOCUS_INTEGRATION.md` — spec previa; usarla como contexto, no como verdad final
- `Focally/Services/FocusIntegrationService.swift` — implementación actual basada en `shortcuts run <name>`
- `Focally/Services/DNDService.swift` — fallback legacy actual
- `Focally/Services/FocusTimerService.swift` — orquesta inicio/fin de sesiones
- `Focally/Views/Settings/IntegrationsSettingsView.swift` — UI actual de integración
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — estado visible del flujo real del usuario
- `Focally/Views/Timer/ActiveFocusView.swift` — estado visible en la vista principal
- `Focally/OnItFocusApp.swift` — composición principal / environment objects
- `project.yml` / `Focally.xcodeproj/project.pbxproj` — para registrar archivos nuevos si hace falta

## Objetivo
Corregir la arquitectura actual de Focus Integration para que Focally deje de depender conceptualmente de un shortcut manual como si fuera la solución final.

Esta tarea **NO** pretende prometer que ya existe una API pública para activar Apple Focus del sistema sin setup manual. Sí pretende dejar el producto y el código listos para:
- exponer acciones propias de Focally sin setup manual mediante `AppIntents + AppShortcutsProvider`
- encapsular honestamente los caminos posibles de integración con el Focus del sistema
- mantener el fallback legacy operativo
- alinear el copy/UI con la realidad técnica actual y con el objetivo de producto

## Resultado esperado
Al terminar esta tarea, Focally debe quedar en un estado donde:
1. sus acciones propias aparezcan como **App Shortcuts** sin que el usuario tenga que crear nada manualmente
2. el código no trate `shortcuts run "Focally Start Focus"` como solución nativa principal
3. la UI comunique con honestidad qué está automatizado realmente y qué no
4. el objetivo de encender/apagar Apple DND/Focus siga modelado como capability futura, no como ficción ya resuelta

## Criterios de aceptación
- [ ] Existe al menos un archivo nuevo de `AppIntents` con intents reales de Focally, por ejemplo:
  - `StartFocusSessionIntent`
  - `EndFocusSessionIntent`
  - `ToggleFocusSessionIntent` o equivalente
- [ ] Existe un `AppShortcutsProvider` que expone esas acciones de Focally automáticamente (`no user setup required`)
- [ ] El proyecto compila con App Intents integrado en macOS 14+
- [ ] `FocusIntegrationService` deja de presentar el modo `Apple Focus / Shortcuts` como si fuera una solución nativa completa ya resuelta
- [ ] La arquitectura distingue explícitamente los modos/capabilities posibles, por ejemplo:
  - `appShortcutsOnly`
  - `manualShortcutBridge`
  - `legacyDND`
  - o una variante equivalente, siempre que sea clara y honesta
- [ ] Si se conserva el puente manual por nombre de shortcut, debe quedar etiquetado claramente como **manual / advanced / custom bridge**, no como recomendado por default
- [ ] El comportamiento default no depende de que el usuario cree shortcuts manuales para que Focally funcione
- [ ] La UI de Settings explica que:
  - Focally puede exponer acciones propias automáticamente
  - el toggle directo del Focus del sistema mediante shortcut personalizado sigue siendo un bridge manual si el usuario decide usarlo
- [ ] El fallback legacy sigue operativo al iniciar/finalizar/resetear sesión
- [ ] Los badges/estado local visible siguen coherentes con el modo activo
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`

## Constraints (lo que NO se puede hacer)
- NO usar APIs privadas de Apple
- NO depender de UI scripting del Control Center
- NO inventar una API pública para activar Work Focus si no existe en el SDK/documentación
- NO dejar copy que implique falsamente que Apple Focus del sistema ya se activa sin setup manual
- NO eliminar el fallback legacy actual
- NO introducir dependencias nuevas de terceros
- NO hacer push ni commits; solo cambios locales

## Fuera de scope
- Resolver definitivamente el encendido/apagado del Focus del sistema sin setup manual si eso requiere APIs no probadas o hacks
- Wizard completo de onboarding
- Importación/instalación automática de `.shortcut` vía rutas no soportadas
- Automatización e2e del sistema

## Recomendación de implementación

### 1. App Intents reales de Focally
Crear intents nativos de la app para acciones como:
- iniciar sesión de foco con duración por default o parámetro
- terminar sesión actual
- opcional: iniciar preset específico

Estos intents deben ejecutar lógica de Focally, no intentar forzar directamente Apple Focus del sistema.

### 2. AppShortcutsProvider
Crear un provider que exponga las acciones anteriores al sistema.

El objetivo es que al instalar Focally, el usuario tenga acciones de Focally disponibles automáticamente en:
- Shortcuts
- Spotlight
- Siri

### 3. Capability model honesto
Refactorizar `FocusIntegrationService` para modelar explícitamente capacidades reales. Ejemplo conceptual:
- `nativeAppShortcuts`
- `manualAppleFocusBridge`
- `legacyDND`

No tienes que usar exactamente estos nombres, pero el modelo debe dejar claro qué hace cada modo.

### 4. UI / copy honesto
Cambiar copy y defaults para evitar afirmar falsamente que ya existe integración nativa completa con Apple Focus.

Ejemplos de dirección correcta:
- `Focally Actions (Automatic)`
- `Apple Focus Bridge (Manual Shortcut)`
- `Legacy DND Fallback`

### 5. Defaults seguros
El default debe seguir siendo operativo y entendible sin obligar al usuario a crear shortcuts manuales.

## Contexto de producto importante
El objetivo final no cambia:
- al iniciar sesión, idealmente se activa Apple DND/Focus
- al terminar, se desactiva

Pero esta tarea existe para dejar de fingir que ese objetivo ya está resuelto con una vía pública sólida cuando no está demostrado.

La intención es preparar una base correcta para futuras iteraciones, en vez de seguir ampliando una arquitectura conceptualmente equivocada.

## Si encuentras una sorpresa positiva
Si durante la implementación encuentras evidencia **real y pública** en el SDK o en documentación oficial de Apple de una ruta soportada para activar/desactivar el Focus del sistema sin setup manual adicional, puedes adaptar el diseño para aprovecharla.

Pero si no la encuentras, **no improvises hacks** ni maquilles el copy. Documenta la limitación con claridad en `Result`.

---
## Result ← Codex llena esta sección al terminar

- Status:
- Resumen:
- Archivos modificados:
- Tests:
- Notas:
- Bloqueado por:
