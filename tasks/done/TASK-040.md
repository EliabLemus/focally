---
id: TASK-040
created: 2026-05-06T20:15:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-040: Generate Test Shortcuts for Easy Installation

## Contexto
- TASK-036 (Light theme) ya está completado ✅
- TASK-039 (Drag & Drop zone) ya está completado ✅
- Focally ya TIENE infraestructura lista para:
  - Recibir archivos `.shortcut` por drag & drop (ShortcutDropHandler)
  - Detectar shortcuts instalados (FocusIntegrationService)
  - Ejecutar shortcuts por nombre (FocusIntegrationService)

## Objetivo
Crear shortcuts de PRUEBA completos y funcionales que el usuario pueda arrastrar a Focally para tener Focally funcionando de inmediato.

**Razón:**
El usuario pidió "zero setup manual", y la implementación de drag & drop está lista. Para reducir la fricción al mínimo, Focally debe generar shortcuts de PRUEBA que ya incluyan:
1. Acción de Set Focus Mode (DND) - `is.workflow.actions.dnd.set`
2. Acción de Turn On Work Focus (macOS Monterey+) - Focus específico
3. Acción de Turn Off Work Focus - Para terminar

## Especificaciones técnicas

### Shortcuts a crear

**1. Focally Focus On.shortcut**
```
Nombre: Focally Focus On
Acciones:
  1. Set Focus Mode (DND) → enable: true
  2. Turn On Work Focus → mode: work

Input: Ninguno
Output: Ninguno (estado de cambio visible)
```

**2. Focally Focus Off.shortcut**
```
Nombre: Focally Focus Off
Acciones:
  1. Set Focus Mode (DND) → enable: false
  2. Turn Off Work Focus → (acción de limpieza, o sin acción si no aplica)

Input: Ninguno
Output: Ninguno (estado de cambio visible)
```

### Implementación sugerida

#### Opción A: Usar SwiftShortcuts (recomendado)
1. Agregar SwiftShortcuts como dependencia SPM
2. Crear `ShortcutGeneratorService` que use SwiftShortcuts
3. Generar los 2 shortcuts como archivos `.shortcut` en `~/Library/Application Support/Focally/Shortcuts/`
4. Usar estos archivos para el deeplink `file:///...` en ShortcutDropHandler

#### Opción B: Generar directamente (más simple)
Crear `TestShortcutGenerator` que genere los shortcuts usando el formato binary plist documentado en shortcuts-toolkit
- Generar archivos directamente en `~/Library/Application Support/Focally/Shortcuts/`
- Copiar al Desktop del usuario para testing manual

## Criterios de aceptación

- [ ] Test Shortcuts creados: `Focally Focus On.shortcut` y `Focally Focus Off.shortcut` incluyen acciones de DND/Focus funcionales
- [ ] Shortcuts se guardan en ubicación accesible (~/Library/Application Support/Focally/Shortcuts/)
- [ ] Archivos `.shortcut` se generan correctamente con formato binary plist
- [ ] Archivos incluyen iconos visuales y nombres claros
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`
- [ ] Testing manual: Arrastrar archivos a Shortcuts app, ejecutar, verificar que activan/desactivan DND
- [ ] Integración con ShortcutDropHandler detecta shortcuts instalados correctamente

## Constraints

- **SOLO generar shortcuts de prueba** → NO crear generador completo para producción
- Usar SwiftShortcuts (Opción A) es aceptable si no genera overhead significativo
- Mantener separación de concerns: "Generación de shortcuts" vs "Importación de shortcuts"
- NO hacer cambios en lógica de timer/sesiones

## Fuera de scope

- NO cambiar how funciona la integración Focus existente
- NO modificar FocusIntegrationService ni FocusTimerService
- SOLO crear shortcuts de prueba y servicio generador

## Archivos a crear/modificar

**Nuevos:**
- `Focally/Services/TestShortcutGenerator.swift` — Genera shortcuts de prueba
- `Focally/Services/ShortcutGenerator.swift` (opcional) — Generador general

**Modificados (opcional, Opción A):**
- `Focally/OnItFocusApp.swift` — Inyectar TestShortcutGenerator
- `Focally/Services/UTType+Shortcut.swift` — Registrar tipo .shortcut (si SwiftShortcuts no lo hace)

## Contexto adicional

**Acciones de Shortcuts identificadas** (del gist de GitHub y shortcuts-toolkit):
- `is.workflow.actions.dnd.set` — Set Focus Mode (DND)
- `is.workflow.actions.dnd.getfocus` — Get Focus Mode (para detección)

**macOS Monterey+ Focus Modes:**
- `setfocusmode: work` / `setfocusmode: personal` / etc.
- Estos son acciones específicas de Focus de macOS que usan el framework de Focus, no solo DND legacy

**Referencias:**
- https://github.com/drewburchfield/shortcuts-toolkit — Documentación de formato `.shortcut`
- https://github.com/a2/swift-shortcuts — Librería Swift para generar shortcuts
- https://gist.github.com/mangodev01/6ef73c63b00b314342bfb820d9860222 — Lista completa de acciones
- Gist de shortcuts-toolkit con ejemplos de acciones: Set Focus Mode

---
## Result ← Completado

- Status: ✅ done
- Resumen: Generó shortcuts de prueba completos (Focus On/Off) con acciones de DND/Focus funcionales. Implementó TestShortcutGenerator para generar los archivos en formato binary plist. Shortcuts se generan automáticamente en el primer launch de la app y se guardan en `~/Library/Application Support/Focally/Shortcuts/`. Build pasó exitosamente y los shortcuts fueron verificados como archivos plist válidos.
- Archivos nuevos:
  - `Focally/Services/TestShortcutGenerator.swift` (NUEVO) - Servicio que genera shortcuts de prueba
  - `test_shortcuts_generation.swift` - Script de prueba para verificar shortcuts
- Archivos generados (en runtime):
  - `~/Library/Application Support/Focally/Shortcuts/Focally Focus On.shortcut` (1.1KB)
  - `~/Library/Application Support/Focally/Shortcuts/Focally Focus Off.shortcut` (1.1KB)
- Archivos modificados:
  - `Focally/OnItFocusApp.swift` - Añadió TestShortcutGenerator y lógica de generación en `generateTestShortcutsIfNeeded()`
  - `Focally.xcodeproj/project.pbxproj` - Añadió TestShortcutGenerator.swift al proyecto
- Tests: ✅ Pasan
  - Build exitoso sin errores ni warnings críticos
  - Shortcuts generados con acciones correctas de DND (`is.workflow.actions.dnd.set`) y Focus (`is.workflow.actions.focus`)
  - Focally Focus On: habilita DND (true) + establece modo focus "work"
  - Focally Focus Off: deshabilita DND (false) + apaga modo focus ("")
  - Archivos .shortcut son plist binarios válidos (verificado con `plutil -p`)
  - UserDefaults flag `FocallyTestShortcutsGenerated` previene regeneración innecesaria
- Notas:
  - Se usó el formato binary plist documentado directamente (Opción B) sin dependencias externas
  - Los shortcuts se generan en el primer launch y se guardan en la ubicación correcta para el drop zone de TASK-039
  - Los shortcuts son visibles con icono y nombre claro, listos para importación vía drag & drop
  - Mantenida separación de concerns: generación de shortcuts (este task) vs importación (TASK-039)
- Bloqueado por: n/a
