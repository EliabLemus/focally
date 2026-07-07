# 📋 Reporte de Auditoría de Tasks — Focally

> **Fecha**: 2026-07-07
> **Repo HEAD**: `15a33ec` (main)
> **Último release**: v0.7.34
> **Método**: Verificación directa en código fuente + git log + specs

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Tasks auditadas | 13 |
| ✅ DONE en código | 8 |
| ⚠️ PARCIAL | 2 |
| 🔴 PENDIENTE REAL | 2 |
| 🗑️ Basura / Obsoleta | 4 (especs duplicadas/huérfanas) |

**Backlog real mínimo**: solo 2 items requieren trabajo (TASK-016 y TASK-021, que son tech debt fundacional). El resto está implementado o es documentación obsoleta.

---

## Análisis por Task

### TASK-016: Migración a @Observable
**VERDICTO: 🔴 PENDIENTE REAL**

**Evidencia en código**:
- `rg "@Observable"` en `Focally/` → **0 resultados**
- `rg "ObservableObject"` → **14 clases** siguen con `ObservableObject`:
  - `FocusTimerService`, `DNDService`, `SlackService`, `GoogleCalendarService`, `HistoryService`, `SoundPlayerService`, `AnalyticsService`, `ScheduleService`, `ShortcutDropHandler`, `FocusIntegrationService`, `ManagedFocusShortcutsService`, `PredefinedTaskStore`, `ShortcutOnboardingViewModel`, `EmojiUsageTracker`

**Diff vs spec**: Ningún cambio aplicado. La spec sigue siendo 100% vigente.

**Prioridad real**: P2 (tech debt fundacional, no bloquea features). La spec dice "v0.6.0" pero ya estamos en v0.7.34.

---

### TASK-021: SettingsStore centralizado
**VERDICTO: 🔴 PENDIENTE REAL**

**Evidencia en código**:
- `rg "SettingsStore"` en `Focally/` → **0 resultados** (no existe el archivo)
- Solo 2 `@AppStorage` permanecen: `appTheme` en `MainWindow.swift` y `AppearanceSettingsView.swift`
- Las settings siguen dispersas entre `@AppStorage`, `UserDefaults` directo en services, y properties individuales

**Diff vs spec**: Ningún cambio aplicado. Depende de TASK-016.

**Prioridad real**: P2 (bloqueado por TASK-016). Reduce deuda técnica pero no es urgente.

---

### TASK-030: Fix Light theme application
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `TASK-030.md` tiene sección `Result` con `Status: done`
- `MainWindow.swift` usa `.preferredColorScheme(selectedTheme.preferredColorScheme)`
- `OnItFocusApp.swift` aplica `NSAppearance` vía observación de `UserDefaults.didChangeNotification`
- Build pasó según reporte de Codex

**Diff vs spec**: Ninguno. Criterios de aceptación cumplidos.

**Acción**: Mover a `tasks/done/`

---

### TASK-036: Fix DND badge visibility + Custom Session UI
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `TASK-036.md` tiene sección `Result` con `Status: done`
- `MenuBarDropdownView.swift` contiene badge DND y custom session UI rediseñada
- Build pasó (`** BUILD SUCCEEDED **`)

**Diff vs spec**: Ninguno. Criterios de aceptación cumplidos.

**Acción**: Mover a `tasks/done/`

---

### TASK-038 (task file): Replace manual shortcut bridge with App Intents
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `FocusIntegrationService.swift` línea 1: `import AppIntents`
- Líneas 320-358: `StartFocusAppIntent`, `EndFocusAppIntent`, y `FocallyAppShortcutsProvider: AppShortcutsProvider` implementados
- `FocusIntegrationMode` enum (líneas 7-21) modela capabilities honestamente: `directDND` y `appShortcuts`
- El modo `directDND` es el recomendado (`isRecommended`), no depende de shortcuts manuales
- `performFromAppIntent()` (línea 149) ejecuta lógica de Focally, no fuerza Apple Focus

**Diff vs spec**: Menor. La spec pedía 3 modes (`appShortcutsOnly`, `manualShortcutBridge`, `legacyDND`); el código usa 2 (`directDND`, `appShortcuts`) que es conceptualmente equivalente y más limpio.

**Acción**: Marcar como done.

---

### TASK-038-SPEC: Meeting Category con time selection
**VERDICTO: ✅ DONE EN CÓDIGO**

> ⚠️ **NOTA IMPORTANTE**: Hay DOS archivos TASK-038 con specs completamente diferentes:
> - `tasks/TASK-038.md` → Shortcut bridge / App Intents
> - `tasks/TASK-038-SPEC.md` → Meeting Category con time selection
> 
> El ID `TASK-038` está duplicado. **Ambos están implementados**, pero esto es confuso.

**Evidencia de Meeting Category**:
- `PredefinedTask.swift` línea 4: `enum TaskType` con `.pomodoro`, `.deepWork`, `.meeting`
- Líneas 63-67: `defaultTasks` incluye Meeting con `availableDurations: [15, 30, 45, 60, 90, 120]`
- Líneas 221-232: `migrateTasksIfNeeded()` añade meeting si falta
- `MeetingDurationPicker.swift` existe en `Views/Shared/`
- `FocusIntegrationService.swift` línea 271-275: usa emoji `:google-meet:` para meetings
- `TaskRowView.swift` y `PredefinedTasksList.swift` renderizan el picker para tipo meeting

**Diff vs spec**: DND para meetings está implementado (`FocusIntegrationService` líneas 203-218 activa/preserva DND para meetings).

**Acción**: Marcar como done. Resolver la colisión de IDs.

---

### TASK-039 (task file): Drag & Drop Zone for Shortcut Installation
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `TASK-039.md` tiene sección `Result` con `Status: done`
- `ShortcutDropHandler.swift` existe en `Focally/Services/`
- `IntegrationsSettingsView.swift` incluye zona de drop

**Diff vs spec**: Ninguno.

**Acción**: Mover a `tasks/done/`

---

### TASK-039-SPEC: Fix Meeting display, version in About, Slack DND
**VERDICTO: ⚠️ PARCIAL (mayormente done)**

**Evidencia por sub-issue**:
1. **Meeting display** ✅ DONE — `PredefinedTask.swift` incluye meeting con migración robusta (líneas 100-117 manejan decode legacy)
2. **Version in About** ✅ DONE — `AboutSettingsView.swift` muestra `Version \(appVersion)` y `Build \(buildNumber)` usando `Bundle.main.infoDictionary`
3. **Slack DND for meetings** ✅ DONE (con fixes posteriores) — `SlackService.swift` línea 29: `dnd.setSnooze` endpoint correcto, `setSlackDNDSnooze(minutes:)` en línea 404

**Diff vs spec**: El issue de Slack DND requirió múltiples iteraciones (TASK-040 → TASK-042 → TASK-043 → TASK-044) pero está resuelto en el código actual.

**Acción**: Marcar como done. Es funcionalmente equivalente a TASK-039-SPEC.

---

### TASK-040 (task file): Generate Test Shortcuts
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `TASK-040.md` tiene sección `Result` con `Status: ✅ done`
- `TestShortcutGenerator.swift` existe en `Focally/Services/`
- Shortcuts se generan en `~/Library/Application Support/Focally/Shortcuts/`

**Diff vs spec**: Ninguno.

**Acción**: Mover a `tasks/done/`

---

### TASK-040-SPEC / TASK-040-URGENT: Fix DND + Slack
**VERDICTO: 🗑️ BASURA (absorbida por releases posteriores)**

> Hay TRES archivos TASK-040 con specs diferentes. Todos resueltos.

**Evidencia**:
- `tasks/TASK-040.md` → Generate Test Shortcuts (done)
- `tasks/TASK-040-SPEC.md` → Fix DND/Slack (done via TASK-042/043/044)
- `tasks/TASK-040-URGENT-fix-release-build.md` → Version 0.7.29 in pbxproj (resuelto en v0.7.30+)

El version display funciona (v0.7.34 actual con `project.yml` correcto). El build inyecta versiones correctamente.

**Acción**: Archivar los 3 TASK-040 en `tasks/done/` o eliminar los duplicados.

---

### TASK-041 (task file): Apple Shortcuts Onboarding Wizard
**VERDICTO: ✅ DONE EN CÓDODO**

**Evidencia**:
- `ShortcutOnboardingView.swift` existe en `Focally/Views/`
- `ShortcutOnboardingViewModel.swift` existe en `Focally/Views/`
- `OnItFocusApp.swift`:
  - Línea 48: `showOnboardingIfNeeded()`
  - Línea 117: observer para `.focusOpenShortcutOnboarding`
  - Línea 369: `showOnboardingIfNeeded()` chequea `ShortcutOnboardingViewModel.isOnboardingCompleted()`
  - Línea 383: `showOnboardingWindow()` presenta onboarding
- ViewModel (líneas 50-186) tiene: `generateShortcuts()`, `verifyShortcuts()`, `completeOnboarding()`, `skipOnboarding()`, `resetOnboarding()`
- `SettingsPage.swift` línea 141: postea `.focusOpenShortcutOnboarding` (botón de reset)

**Diff vs spec**: Mínimo. El VM usa `ObservableObject` (pendiente de TASK-016) pero funcionalmente completo.

**Acción**: Marcar como done.

---

### TASK-041-SPEC: Fix DND and Slack (URGENT)
**VERDICTO: 🗑️ BASURA (duplicado de TASK-042)**

> `tasks/TASK-041-SPEC.md` describe EXACTAMENTE el mismo problema que `tasks/TASK-040-SPEC.md` y `tasks/TASK-042-SPEC.md`. Tres specs para el mismo bug.

**Acción**: Eliminar o archivar. Ya resuelto.

---

### TASK-042-SPEC: Fix DND/Slack with better error handling
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- Commit `c0dbfbc` en main: `fix: improve DND and Slack error handling (TASK-042)`
- `DNDService.swift` y `SlackService.swift` tienen logging extendido
- `FocusIntegrationService.swift` maneja errores de Slack DND

**Acción**: Marcar como done.

---

### TASK-043-SPEC: Fix keychain entitlements for Slack
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- `Focally/Focally.entitlements` líneas 7-10:
  ```xml
  <key>keychain-access-groups</key>
  <array>
      <string>$(AppIdentifierPrefix)app.focally.Focally</string>
  </array>
  ```
- Commit `123fa96` en main: `fix: add keychain-access-groups entitlement for Slack token`
- Release v0.7.33+ incluye este fix

**Acción**: Marcar como done.

---

### TASK-044 (referenciado en commits)
**VERDICTO: ✅ DONE EN CÓDIGO**

**Evidencia**:
- Commits `8ca152c` y `15a33ec` (HEAD): `fix(TASK-044): Slack DND - corregir endpoint y añadir manejo de errores visibles`
- `SlackService.swift` línea 28: `dnd.endSnooze` (corregido desde el deprecado `dnd.endDnd`)
- `FocusIntegrationService.swift`: chequeo de errores tras llamadas DND

> Nota: No existe archivo `TASK-044-SPEC.md`. El fix está documentado solo en commits.

**Acción**: Nada. Ya en main y releaseado.

---

## Compliance Stitch (Glass Modifiers)

**Estado**: ⚠️ PARCIAL

- `FocallyGlassModifier.swift` existe con 3 modificadores: `focallyGlassCard`, `focallyGlassPopover`, `focallyGlassDropdown`
- **Uso real en vistas**: `rg ".focallyGlass" → 0 usos`
- En su lugar, las vistas usan `focallyCard()` (de `CardModifier.swift`) — encontrado en 13 archivos

**Conclusión**: Los modificadores glass están definidos pero **NO aplicados** en ninguna vista. La app usa el modifier `focallyCard()` anterior. Si Stitch (Liquid Glass / macOS 26) es un requerimiento, falta migrar las vistas de `.focallyCard()` → `.focallyGlassCard()`.

---

## Fase 2 de Refactorización

**Estado**: 🗑️ STALE BRANCH (no mergeada, probablemente obsoleta)

- `origin/feature/fase2-refactorizacion` existe
- **21 commits ahead** de main, **29 commits behind**
- Los commits son exclusivamente refactor de líneas largas (SwiftLint fixes): "break long lines", "break long function calls", etc.
- `PLAN-008_SWIFTLINT_FIX.md` (que parece ser esta fase) sigue marcado `in_progress` pero referencia v0.7.18 (ya superado por 16 releases)

**Conclusión**: La branch es un worktree de refactor SwiftLint que quedó estancada. Los fixes de líneas largas probablemente ya no son relevantes o fueron resueltos de otras formas. **Recomendación: archivar o eliminar la branch.**

---

## Backlog Real (lo que FALTA de verdad)

Solo **2 items** requieren trabajo real:

### 1. TASK-016: Migración a @Observable
- **Effort**: 2-3 días
- **Impacto**: Tech debt fundacional, mejora performance y moderniza código
- **Bloquea**: TASK-021 (SettingsStore)
- **Prioridad**: P2

### 2. TASK-021: SettingsStore centralizado
- **Effort**: 1-2 días (después de TASK-016)
- **Impacto**: Elimina 3 fuentes de verdad para settings, reduce bugs
- **Depende de**: TASK-016
- **Prioridad**: P2

---

## 🗑️ Basura (tasks/specs obsoletas o absorbidas)

### Archivos a mover a `tasks/done/`:
- `tasks/TASK-030.md` — done (theme fix)
- `tasks/TASK-036.md` — done (DND badge)
- `tasks/TASK-038.md` — done (App Intents)
- `tasks/TASK-038-SPEC.md` — done (Meeting category)
- `tasks/TASK-039.md` — done (Drag & Drop)
- `tasks/TASK-039-SPEC.md` — done (Meeting/About/Slack fixes)
- `tasks/TASK-040.md` — done (Test Shortcuts)
- `tasks/TASK-040-SPEC.md` — done (DND/Slack, duplicado de 042)
- `tasks/TASK-040-URGENT-fix-release-build.md` — done (version pbxproj)
- `tasks/TASK-041.md` — done (Onboarding wizard)
- `tasks/TASK-041-SPEC.md` — done (DND/Slack, duplicado de 040/042)
- `tasks/TASK-042-SPEC.md` — done (error handling)
- `tasks/TASK-043-SPEC.md` — done (keychain entitlements)

### Colisión de IDs a resolver:
- **TASK-038**: 2 specs diferentes (App Intents vs Meeting Category)
- **TASK-039**: 2 specs diferentes (Drag&Drop vs Meeting/About/Slack fix)
- **TASK-040**: 3 specs diferentes (Test Shortcuts / DND-Slack / Version fix)
- **TASK-041**: 2 specs diferentes (Onboarding vs DND-Slack fix)

> Los IDs TASK-038 a TASK-041 se reutilizaron para specs completamente diferentes. Esto genera confusión grave.

### Branches stale:
- `origin/feature/fase2-refactorizacion` — 21 commits de SwiftLint fixes, 29 atrás. **Eliminar.**
- `origin/feature/tests-flaky-fix` — PLAN-007 marcado completed pero PR nunca se mergeó. **Revisar si aún es necesario.**

### Planes activos a actualizar:
- `docs/exec-plans/active/PLAN-008_SWIFTLINT_FIX.md` — `in_progress`, referencia v0.7.18. **Mover a completed o cerrar.**
- `docs/exec-plans/active/PLAN-003_ARCHITECTURAL_INVARIANTS.md` — `in_progress`, sin avance. **Re-evaluar.**
- `docs/exec-plans/active/fix-emoji-shortcode-mapping.md` — ya hecho (commit `1a40c9e`). **Mover a completed.**
- `docs/exec-plans/active/PLAN-007_TESTS_FLAKY_FIX.md` — marcado completed pero sigue en active/. **Mover a completed/.**

---

## Recomendación de Priorización

### Inmediato (Limpieza)
1. **Mover 13 task files a `tasks/done/`** — El estado actual da la impresión falsa de mucho trabajo pendiente
2. **Resolver colisión de IDs TASK-038→041** — Renumerar o archivar duplicados
3. **Mover PLAN-007 y fix-emoji-shortcode-mapping a completed/**
4. **Eliminar branch `feature/fase2-refactorizacion`** — Stale, divergente
5. **Cerrar PLAN-008** o re-scoping (v0.7.18 hace 16 releases que se superó)

### Corto plazo (Tech debt)
6. **TASK-016: @Observable migration** — Base para todo el futuro desarrollo. 14 clases a migrar.
7. **TASK-021: SettingsStore** — Después de 016. Elimina dispersión de settings.

### Evaluar
8. **Compliance Stitch/Liquid Glass** — Los modifiers existen pero no se usan. Si macOS 26 (Tahoe) es target, hay que migrar `.focallyCard()` → `.focallyGlassCard()` en ~13 vistas.
9. **PLAN-003: Invariantes arquitectónicos** — Sigue siendo valioso pero sin avance. Decidir si se prioriza o se pausa formalmente.
10. **Tests flaky (feature/tests-flaky-fix)** — Branch existe pero PR nunca mergeado. Validar si los fixes siguen siendo relevantes tras 29 commits de divergencia.

---

*Reporte generado por auditoría de código — 2026-07-07*
