---
id: TASK-037
created: 2026-05-05T18:58:00-06:00
status: done
agent: codex
priority: high
---

# TASK-037: Implement MVP Native macOS Focus Integration

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6, SwiftUI, AppKit, macOS 14+
- Runtime check: `swift --version`
- Tests: `xcodebuild -scheme Focally -configuration Debug build`

## Archivos relevantes
- `SPEC_NATIVE_FOCUS_INTEGRATION.md` — spec de producto/técnica recién creada con research, opciones y recomendación
- `Focally/Services/DNDService.swift` — implementación actual de DND legacy vía backend/preferences
- `Focally/Services/FocusTimerService.swift` — aquí inicia/termina sesiones y hoy activa/desactiva DND
- `Focally/Views/Settings/GeneralSettingsView.swift` — settings actuales donde debe vivir el MVP de integración
- `Focally/Views/Settings/SettingsPage.swift` — navegación/estructura de Settings
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — flujo real del menú bar, ya muestra estado local y puede necesitar copy/estado nuevo
- `Focally/OnItFocusApp.swift` — composición principal de servicios / environment objects
- `Focally/Services/NotificationService.swift` — si hace falta ajustar notificaciones según el modo de integración elegido

## Objetivo
Implementar un MVP de integración nativa con macOS Focus para que Focally deje de depender exclusivamente del hack legacy de DND como experiencia principal.

Este MVP debe permitir que el usuario configure una integración basada en Apple Shortcuts / Focus, probarla desde Settings, y usarla automáticamente al iniciar/finalizar sesiones. La UX debe dejar claro que esta es la ruta recomendada para tener confirmación visual global real en macOS.

## Criterios de aceptación
- [ ] Existe una configuración visible en Settings para habilitar/deshabilitar **Native Focus Integration**
- [ ] El usuario puede elegir el modo de integración entre:
  - `Apple Focus / Shortcuts (Recommended)`
  - `Legacy DND fallback`
- [ ] El usuario puede configurar al menos los nombres de shortcut para inicio y fin de sesión (o una forma equivalente explícita si el diseño final mejora esto sin perder claridad)
- [ ] Settings ofrece botones de prueba para activar y desactivar la integración configurada
- [ ] Al iniciar una focus session, Focally usa la integración elegida por el usuario
- [ ] Al terminar o resetear una focus session, Focally revierte la integración elegida por el usuario
- [ ] Si el modo elegido es Apple Focus / Shortcuts y la ejecución falla (shortcut faltante, error de invocación, etc.), Focally no finge éxito: expone estado o mensaje de error razonable
- [ ] La UI comunica claramente que para confirmación visual global el usuario debe usar el Focus nativo de macOS y fijar el icono de Focus en el menú bar del sistema
- [ ] La integración legacy existente no se elimina; queda disponible como fallback
- [ ] El estado local visible dentro de Focally sigue siendo coherente con la sesión activa
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`

## Constraints (lo que NO se puede hacer)
- NO usar APIs privadas de Apple
- NO depender de UI scripting del Control Center o Accessibility automation frágil
- NO eliminar la implementación legacy actual de DND
- NO introducir dependencias nuevas de terceros
- NO hacer push ni commits; solo cambios locales
- Mantener el diseño y tono actual de Focally; evitar UI recargada
- Si necesitas crear un servicio nuevo, debe integrarse limpiamente con la arquitectura actual y no dejar lógica de Focus dispersa en varias vistas

## Fuera de scope
- Wizard completo de onboarding paso a paso
- Detección perfecta/forense del estado global real de Focus en todos los casos
- Soporte para múltiples Focus por categoría o tipo de sesión
- Rehacer el sistema completo de notificaciones o sounds
- Automatización end-to-end con permisos del sistema

## Contexto adicional
Contexto de producto importante:
- Esta feature es **alta prioridad** y es considerada principal para Eliab.
- El problema no es solo silenciar notificaciones; es dar una **confirmación visual global confiable** de que macOS realmente entró en modo Focus.
- El research en `SPEC_NATIVE_FOCUS_INTEGRATION.md` concluye que competidores reales (`Session`, `Pomotto`) se apoyan en Focus nativo del sistema, no solo en badges internos.
- La estrategia recomendada es:
  1. `Apple Focus / Shortcuts` como camino principal
  2. `Legacy DND` como fallback opcional
  3. feedback en dos capas: sistema + Focally

Preferencias de implementación:
- Si hace falta, crea un servicio nuevo tipo `FocusIntegrationService.swift` o equivalente, con responsabilidades claras:
  - guardar/leer configuración
  - ejecutar activación/desactivación según modo seleccionado
  - exponer estado/errores útiles para la UI
- La invocación del camino `Apple Focus / Shortcuts` debe usar un mecanismo razonable/soportado en macOS. Si el mejor camino es invocar Shortcuts por nombre, hazlo de forma encapsulada y testeable.
- El copy de Settings debe ayudar, no estorbar. Prioriza claridad sobre exceso de texto.
- El comportamiento por default debe ser seguro y entendible. Si eliges defaults, documenta brevemente la decisión en `Result`.

Si al inspeccionar el proyecto ves que una parte del spec requiere una decisión mínima no cubierta aquí, toma la opción más simple y explícala en `Result`. Solo marca `blocked` si de verdad no puedes construir un MVP coherente sin improvisar arquitectura o usar APIs no permitidas.

---
## Result ← Codex llena esta sección al terminar

- Status: **done**
- Resumen: MVP completo de Native macOS Focus Integration. Se creó un nuevo `FocusIntegrationService` que soporta dos modos: Apple Shortcuts (recomendado) y Legacy DND fallback. El servicio se integra con `FocusTimerService` para activar/desactivar focus al iniciar/terminar sesiones. Se añadió UI completa en Settings > Integrations con toggle de enable, picker de modo, campos de shortcut names, botones de test, mensajes de error, y helper text. El menú bar dropdown y la vista ActiveFocus muestran badges diferenciados (púrpura para Shortcuts, azul para DND legacy) con manejo de errores visible.
- Archivos modificados:
  - **NUEVO**: `Focally/Services/FocusIntegrationService.swift` — Servicio central: config en UserDefaults, ejecución de shortcuts vía `/usr/bin/shortcuts run`, fallback a legacy, estado/errores publicados
  - `Focally/Services/FocusTimerService.swift` — Reemplazó llamadas directas a DNDService con `activateFocusIntegration()`/`deactivateFocusIntegration()` que respetan el modo elegido por el usuario
  - `Focally/OnItFocusApp.swift` — Instanció `FocusIntegrationService` y lo inyectó como environmentObject en popover y main window
  - `Focally/Views/Settings/IntegrationsSettingsView.swift` — Card completa de Focus Integration con: toggle enable, segmented picker (Shortcuts/Legacy), campos de shortcut names, helper text, botones Test Activate/Deactivate, error display
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift` — Badge condicional: púrpura “Focus Active” para Shortcuts, error si falla, DND legacy si corresponde
  - `Focally/Views/Timer/ActiveFocusView.swift` — Badge en top bar con mismo esquema de colores
  - `Focally/Views/Timer/TimerPage.swift` — Inyectó focusIntegrationService como environmentObject
  - `Focally.xcodeproj/project.pbxproj` — Registró nuevo archivo
- Tests: `xcodebuild -scheme Focally -configuration Debug build` → **BUILD SUCCEEDED** (0 errores, 0 warnings relevantes)
- Notas:
  - Default: integración deshabilitada, comportamiento idéntico al anterior (legacy DND)
  - Decisiones de diseño: Purple como color de acento para distinguir Focus Integration de DND legacy (azul/focallyPrimary)
  - Atajos invocados vía `/usr/bin/shortcuts run` — comando público y soportado de macOS
  - El helper text guía al usuario a crear shortcuts en la app de Shortcuts y a fijar el icono de Focus al menú bar del sistema
  - Cuando el modo es Legacy DND, DNDService sigue manejando todo directamente
- Bloqueado por: (nada)
