---
id: TASK-036
created: 2026-05-05T18:32:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-036: Fix DND badge visibility and Custom Session UI regression

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6, SwiftUI, AppKit, macOS 14+
- Runtime check: `swift --version`
- Tests: `xcodebuild -scheme Focally -configuration Debug build`

## Archivos relevantes
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — aquí vive la UI de Custom Session y también el flujo real del menú bar donde Eliab probó la app
- `Focally/Views/Timer/ActiveFocusView.swift` — el badge DND hoy solo existe aquí
- `Focally/Views/Timer/TimerPage.swift` — referencia del flujo en ventana principal
- `Focally/Services/FocusTimerService.swift` — activa/desactiva DND al iniciar/finalizar sesión
- `Focally/Services/DNDService.swift` — estado `isDNDActive`

## Objetivo
Corregir dos regresiones detectadas en prueba manual:
1. El estado de DND no se ve en el flujo real del menú bar al iniciar una focus session.
2. La nueva UI para `Custom Session` quedó fea e ilegible; hay que reemplazarla por una versión compacta, limpia y fácil de leer sin perder edición directa.

## Criterios de aceptación
- [ ] El menú bar dropdown muestra un indicador visible de DND activo mientras hay una sesión en foco y `dndService.isDNDActive == true`
- [ ] El indicador DND aparece en el flujo que Eliab realmente usa (dropdown / active session card), no solo en `ActiveFocusView`
- [ ] La UI de `Custom Session` deja de usar el editor actual pequeño/ilegible
- [ ] La nueva UI de duración personalizada se ve limpia y compacta dentro del dropdown
- [ ] El número de minutos se lee claramente a simple vista
- [ ] La edición sigue siendo directa por teclado (no solo stepper)
- [ ] El botón/acción de `Custom Session` sigue usando la duración elegida por el usuario
- [ ] La duración sigue validada/clamped en `1...120`
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`

## Constraints (lo que NO se puede hacer)
- NO tocar la lógica central de inicio/fin de sesión salvo que sea estrictamente necesario para refrescar el badge
- NO dejar la UI como formulario tosco o recargado
- NO volver a un `Stepper` como única solución
- NO introducir dependencias nuevas
- NO hacer push ni commits; solo cambios locales
- Mantener consistencia con el diseño actual de Focally

## Fuera de scope
- Rehacer toda la arquitectura del menú bar
- Cambios en sonidos, release pipeline o theme
- Cambios en el layout de la ventana principal no relacionados con el badge

## Contexto adicional
Feedback manual explícito de Eliab:
- "No aparece el badge de do not disturb activo."
- "No me gusta esa cosa que le pusiste a las custom sessions está horrible y los mins no se lee."

Hallazgo principal:
- El badge DND hoy solo está en `ActiveFocusView`, que pertenece al flujo de ventana principal.
- Eliab estaba probando el flujo real del menú bar (`MenuBarDropdownView`), así que ahí falta el indicador.

**Preferencia de diseño para Custom Session:**
- una sola fila compacta
- minutos legibles
- edición directa de número
- que se sienta integrada al card/botón, no como un formulario metido a la fuerza

Si necesitas simplificar, prioriza legibilidad y limpieza visual sobre “más controles”.

---
## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Se movió el indicador de DND al flujo real del menú bar agregándolo dentro del active session card del dropdown, visible cuando hay sesión de foco y `dndService.isDNDActive` está activo. También se reemplazó la UI previa de `Custom Session` por una sola fila compacta con minutos grandes, edición directa por teclado, botones `+/-` y acción de inicio integrada.
- Archivos modificados:
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift` — agregó `dndService` al dropdown, añadió badge `DND Active` al active session card y rehizo la fila de `Custom Session` con editor más legible e integrado
- Tests: pasaron — `swift --version` mostró `Apple Swift version 6.3.1`; `xcodebuild -scheme Focally -configuration Debug build` terminó en `** BUILD SUCCEEDED **`
- Notas: El build dentro del sandbox siguió fallando por permisos de caché/DerivedData, así que la validación final se re-ejecutó fuera del sandbox. No fue necesario tocar la lógica central del timer ni los servicios de DND para refrescar el badge.
- Bloqueado por: n/a
