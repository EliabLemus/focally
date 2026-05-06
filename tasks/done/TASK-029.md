---
id: TASK-029
created: 2026-05-05T18:05:00-06:00
status: done
agent: codex
priority: high
---

# TASK-029: Custom Session duration editable

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6, SwiftUI, macOS 14+
- Runtime check: `swift --version`
- Tests: `xcodebuild -scheme Focally -configuration Debug build`

## Archivos relevantes
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — aquí vive el input de tarea y el botón de `Custom Session` hoy hardcodeado a `45m`
- `Focally/Services/FocusTimerService.swift` — API que recibe `durationMinutes` al iniciar una sesión
- `Focally/Views/Timer/ActiveFocusView.swift` — referencia visual del estado activo; no debería requerir cambios funcionales, pero sirve para validar consistencia
- `SPEC_V0.6.6_BUG_FIXES.md` — contexto del bug #2 y constraints del release

## Objetivo
Hacer que `Custom Session` permita editar la duración antes de iniciar la sesión, usando edición directa del número (teclado) sin perder el estilo visual premium/compacto del dropdown. La sesión personalizada debe arrancar con el valor elegido en vez de `45` hardcodeado.

**Enfoque preferido:**
- Agregar estado local para la duración personalizada con default `45`
- Exponer un control compacto inline en el dropdown que permita editar el número directamente (no depender solo de stepper)
- Validar/clamp del valor en rango `1...120`
- El botón `Custom Session` debe reflejar el valor actual y usarlo al llamar `startWorkSession(...)`

## Criterios de aceptación
- [ ] Existe un estado local para la duración personalizada con valor inicial `45`
- [ ] El usuario puede editar el número directamente con teclado desde la UI del dropdown
- [ ] La UI mantiene un look compacto y consistente con el diseño actual (no degradar a controles toscos)
- [ ] La duración se limita a `1...120` minutos
- [ ] El botón `Custom Session` muestra el valor actualizado (por ejemplo `60m`)
- [ ] `Custom Session` usa el valor editado al llamar `timerService.startWorkSession(...)`
- [ ] Si el campo queda vacío o inválido temporalmente, la UI no crashea y recupera un valor válido al confirmar/perder foco
- [ ] `Start Pomodoro` sigue usando `timerService.workDurationMinutes` y no cambia de comportamiento
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`

## Constraints (lo que NO se puede hacer)
- NO modificar el flujo de Pomodoro estándar
- NO agregar dependencias nuevas
- NO romper el layout del dropdown de menú
- NO reemplazar el diseño con un `Stepper` gigante como único mecanismo de edición
- NO hacer push ni commits; solo cambios locales
- Mantener el estilo del sistema de diseño existente (`.focally*`, rounded cards, spacing actual)

## Fuera de scope
- Persistir la duración personalizada en `UserDefaults` / `@AppStorage`
- Cambios en la ventana principal o Settings
- Nuevas analytics/event tracking
- Rehacer el layout completo del dropdown

## Contexto adicional
Eliab pidió explícitamente que la edición de números grandes sea directa y no incómoda. Un stepper puro no cumple bien eso. Si necesitas combinar edición directa + controles pequeños auxiliares, está bien, pero la experiencia principal debe ser poder escribir `60`, `90`, etc. sin pelear con la UI.

Conviene agregar identifiers de accesibilidad si ayudan a pruebas/UI automation, por ejemplo para el campo de duración.

---
## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Se agregó estado local para la duración personalizada en el dropdown con valor inicial `45`, edición directa por teclado y validación/clamp en rango `1...120`. El botón `Custom Session` ahora refleja el valor actual y usa el número visible al iniciar la sesión, incluso si el usuario hace click sin salir primero del campo.
- Archivos modificados:
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift` — editor inline compacto para duración personalizada, parsing seguro de input, botones auxiliares +/- y conexión del botón `Custom Session` al valor editado
- Tests: `swift --version` → `Apple Swift version 6.3.1`; `xcodebuild -scheme Focally -configuration Debug build` → `BUILD SUCCEEDED`
- Notas: El flujo de `Start Pomodoro` quedó intacto y sigue usando `timerService.workDurationMinutes`. Si el campo de duración queda vacío o contiene caracteres no numéricos temporalmente, la UI filtra/recupera un valor válido al confirmar o perder foco.
- Bloqueado por: N/A
