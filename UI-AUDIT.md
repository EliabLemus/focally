# Focally UI/UX Audit Report

**Date:** 2026-05-26
**Model:** Analysis using Krug's frameworks + technical Focally audit
**Skills used:** `focally-ui-audit` + `ui-no-pensar`

---

## Executive Summary

**Total Issues:** 12
- **Critical:** 3
- **High:** 4
- **Medium:** 3
- **Low:** 2

**Key Findings:**
- Texto innecesario en múltiples áreas viola la Tercera Norma de Krug
- Confusión entre estados de pausa y notificaciones
- Falta de auto-evidencia en sections del menubar
- Buen uso de jerarquía visual en timer principal

---

## Issues Found

### 1. ✅ Texto innecesario en empty state - "Create presets from Task Configuration."
**Severity:** High
**Framework:** Omisión de palabras (Tercera Norma)
**Location:** `MenuBarDropdownView.swift:75`
**Status:** ✅ RESOLVED (Batch 2 - 2026-05-26)
**Resolution:** Simplified to "Create presets"
**Commit:** (pending commit)

**Description:**
```swift
Text("Create presets from Task Configuration.")
```
Este texto es "bla-bla-bla" según el Test de Bla-Bla de Krug. Los usuarios no leen instrucciones de bienvenida - van directo al contenido.

**Root Cause:**
Conversación en lugar de direct action. Incluye un nombre de feature interno ("Task Configuration") que el usuario no necesita saber.

**Krug Framework Violation:**
> **Tercera Norma:** Elimina la mitad de las palabras, luego la mitad de lo que queda.
> Test de bla-bla: Lee en voz alta; si escuchas "bla-bla-bla", es discurso innecesario.

**Proposed Fix:**
```swift
// ❌ Actual
Text("Create presets from Task Configuration.")

// ✅ Fix directo
Text("Create presets")

// ✅ Fix más contextual (opcional)
HStack(spacing: 4) {
    Image(systemName: "plus.circle.fill")
    Text("Add presets")
}
```

---

### 2. ✅ Estado de pausa confuso - "Paused · Notifications are back"
**Severity:** Critical
**Framework:** Auto-evidencia (Primera Norma) + Omisión de palabras
**Location:** `MenuBarDropdownView.swift:99`
**Status:** ✅ RESOLVED (Batch 1 - 2026-05-26)
**Resolution:** Simplified to "Paused" / "Deep Focus" / "Break"
**Commit:** (pending commit)

**Description:**
```swift
Text(timerService.isPaused ? "Paused · Notifications are back" : "Deep Focus Mode")
```
El estado "Paused · Notifications are back" es confuso porque mezcla dos conceptos: el estado del timer y el estado de notificaciones. El usuario debe procesar esto mentalmente para entender qué está pasando.

**Root Cause:**
Descripción técnica de estado en lugar de UX-simple. "are back" es conversacional, no auto-evidente.

**Krug Framework Violation:**
> **Primera Norma:** Las páginas deben ser auto-evidentes, obvias, claras. Usuario debe entender qué es y cómo usarla sin pensar.
> **Omisión de palabras:** Elimina la mitad, luego la mitad de lo que queda.

**Proposed Fix:**
```swift
// ❌ Actual
Text(timerService.isPaused ? "Paused · Notifications are back" : "Deep Focus Mode")

// ✅ Fix #1: Más directo
Text(timerService.isPaused ? "Paused" : "Deep Focus")

// ✅ Fix #2: Con estado de notificaciones separado (opcional)
if timerService.isPaused {
    Text("Paused")
} else if dndService.isDNDActive {
    Text("Deep Focus")
} else {
    Text("Focus")
}
```

---

### 3. ✅ Header de menubar poco claro - "Start fast, stay quiet."
**Severity:** Medium
**Framework:** Auto-evidencia + Convenciones
**Location:** `MenuBarDropdownView.swift:46`
**Status:** ✅ RESOLVED (Batch 3 - 2026-05-26)
**Resolution:** Removed subtitle entirely, keeping only "Focus"
**Commit:** (pending commit)

**Description:**
```swift
Text("Start fast, stay quiet.")
```
Este subtitle no es auto-evidente. ¿Qué significa? ¿Es un slogan? ¿Instrucción? ¿Descripción de funcionalidad? Rompe convenciones de headers de menubar que usualmente son más funcionales.

**Root Cause:**
Copywriting clever en lugar de funcional. No usa convenciones de headers de menubar que suelen ser descriptivos del estado o acción disponible.

**Krug Framework Violation:**
> **Auto-evidencia:** Usuario debe entender qué es y cómo usarla sin pensar.
> **Convenciones:** Usa patrones establecidos que los usuarios ya conocen.

**Proposed Fix:**
```swift
// ❌ Actual
Text("Start fast, stay quiet.")

// ✅ Fix #1: Más descriptivo
Text("Timer · Stats · DND")

// ✅ Fix #2: Solo nombre (convención de menubar)
Text("Focus")

// ✅ Fix #3: Estado actual (si hay sesión activa)
Text(timerService.hasSession ? "Session Active" : "Start Timer")
```

---

### 4. ✅ Redundancia de estado de notificaciones en footer
**Severity:** Medium
**Framework:** Omisión de palabras + Minimizar ruido
**Location:** `MenuBarDropdownView.swift:203`
**Status:** ✅ RESOLVED (Batch 2 - 2026-05-26)
**Resolution:** Simplified to show only DND state ("DND Active" / "DND Off")
**Commit:** (pending commit)

**Description:**
```swift
Text(timerService.isPaused ? "Paused · notifications live" : (dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready"))
```
El estado de notificaciones se repite entre el activeSessionCard y el footerStats. Cuando está pausado, aparece "Paused · Notifications are back" en el card Y "Paused · notifications live" en el footer. Es ruido.

**Root Cause:**
Información duplicada en lugar de única y clara. Footer se usa para agregados ("Today: X"), no para estado repetido.

**Krug Framework Violation:**
> **Omisión de palabras:** Elimina la mitad, luego la mitad de lo que queda.
> **Minimizar ruido:** Elimina todo que no es esencial.

**Proposed Fix:**
```swift
// ❌ Actual
Text(timerService.isPaused ? "Paused · notifications live" : (dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready"))

// ✅ Fix: Footer solo muestra modo de silencio, no estado de pausa
Text(dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready")

// O mejor aún, simplificar a solo el estado de DND:
Text(dndService.isDNDActive ? "DND Active" : "DND Off")
```

---

### 5. ✅ Timer principal bien diseñado para escaneo
**Severity:** N/A (Good practice)
**Framework:** Jerarquía visual + Diseño para escaneo
**Location:** `MenuBarDropdownView.swift:147-150`

**Description:**
```swift
Text(timerService.remainingTimeString)
    .font(.system(size: 28, weight: .medium, design: .monospaced))
    .foregroundStyle(Color.focallyOnSurface)
    .monospacedDigit()
```

**Why it works (Krug frameworks):**
- **Jerarquía visual clara:** Lo más importante (tiempo) es lo más prominente (28pt, monospaced)
- **Diseño para escaneo:** Fuente monospaced hace que los números sean fáciles de ojear a 100 km/h
- **Auto-evidente:** El usuario entiende inmediatamente qué es (tiempo restante)

**Keep as-is** — This is Krug-compliant design.

---

### 6. ✅ Botones de predefined task no obviamente clickeables
**Severity:** High
**Framework:** Clickeabilidad + Convenciones
**Location:** `FocusSessionComponents.swift:345-377`
**Status:** ✅ RESOLVED (Batch 1 - 2026-05-26)
**Resolution:** Added hover state with smooth animation (0.15s), border, and chevron icon
**Commit:** (pending commit)

**Description:**
```swift
public struct PredefinedTaskQuickButton: View {
    let task: PredefinedTask
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: task.iconBgColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.focallyBodyBold)
                    Text("\(task.durationMinutes)m")
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLowest.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

Los predefined tasks son botones pero no tienen hover state, cursor pointer, o indicación visual de que son clickeables. El usuario debe adivinar.

**Root Cause:**
Usa `.buttonStyle(.plain)` sin indicación visual de interactividad. No hay cursor pointer en hover, background change, o border highlight.

**Krug Framework Violation:**
> **Clickeabilidad:** Haz clickeabilidad obvia (cursor pointer, hover states, link colors)
> **Convenciones:** Botones parecen botones

**Proposed Fix:**
```swift
// ❌ Actual
Button(action: action) { /* content */ }
    .buttonStyle(.plain)

// ✅ Fix #1: Hover state
Button(action: action) { /* content */ }
    .buttonStyle(.plain)
    .onHover { isHovering in
        withAnimation(.easeInOut(duration: 0.2)) {
            // Add visual feedback
        }
    }
    .background(Color.focallySurfaceContainerLowest.opacity(isHovering ? 0.9 : 0.72))

// ✅ Fix #2: Cursor pointer
Button(action: action) { /* content */ }
    .buttonStyle(.plain)
    .background(Color.focallySurfaceContainerLowest.opacity(0.72))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.focallyPrimary.opacity(0.3), lineWidth: isHovering ? 2 : 0)
    }

// ✅ Fix #3: Add chevron icon (convención de menubar)
Spacer()

if isHovering {
    Image(systemName: "chevron.right")
        .font(.system(size: 10))
        .foregroundStyle(Color.focallyOnSurfaceVariant)
}
```

---

### 7. ✅ Section headers poco claros - "Predefined tasks" vs "Quick Start"
**Severity:** Medium
**Framework:** Auto-evidencia + Convenciones
**Location:** `MenuBarDropdownView.swift:18-22`
**Status:** ✅ RESOLVED (Batch 3 - 2026-05-26)
**Resolution:** Renamed "Predefined tasks" → "Your Presets"
**Commit:** (pending commit)

**Description:**
```swift
VStack(spacing: 14) {
    if timerService.hasSession {
        activeSessionCard
    } else {
        quickStartSection
        presetsSection
    }
}
```

Hay dos sections cuando no hay sesión activa:
1. "Quick Start" (quickStartSection)
2. "Predefined tasks" (presetsSection)

¿Cuál usar? ¿Son mutuamente excluyentes? No es auto-evidente qué hace cada uno sin leer el contenido.

**Root Cause:**
Nombres de sections no son descriptivos de acción o estado. "Quick Start" podría significar "start quickly" o "quick sessions". "Predefined tasks" es técnico.

**Krug Framework Violation:**
> **Auto-evidencia:** Usuario debe entender qué hace cada elemento sin pensar.
> **Convenciones:** Usa nombres convencionales y descriptivos.

**Proposed Fix:**

**Opción A - Renombrar para claridad:**
```swift
// "Quick Start" → "Start Session"
// "Predefined tasks" → "Your Presets"
```

**Opción B - Unificar sections:**
```swift
// Combina en una sola section "Start Focus" con both options
VStack(spacing: 14) {
    QuickSessionsSection()  // Cambia nombre a SessionStartSection
    presetsSection
}
```

**Opción C - Mejor etiqueta:**
```swift
// "Quick Start" → "Quick Sessions" (ya existe, pero el header dice "Quick Start")
// "Predefined tasks" → "Saved Presets" o "Quick Presets"
```

---

### 8. ✅ "Notifications live" - redundante
**Severity:** Low
**Framework:** Omisión de palabras
**Location:** `MenuBarDropdownView.swift:108`
**Status:** ✅ RESOLVED (Batch 4 - 2026-05-26)
**Resolution:** Removed "Notifications live" text, keeping only the colored indicator circle
**Commit:** (pending commit)

**Description:**
```swift
Text("Notifications live")
```

**Root Cause:**
"live" es innecesario - si no están muted, están live. User infiere.

**Proposed Fix:**
```swift
// ❌ Actual
Text("Notifications live")

// ✅ Fix
Text("Notifications On")

// O mejor aún, símbolo solo:
if timerService.isPaused {
    Circle()
        .fill(Color.focallySecondary)
        .frame(width: 6, height: 6)
}
// No necesitas texto - el color/status indica estado
```

---

### 9. ✅ Progreso visual del timer - bien diseñado
**Severity:** N/A (Good practice)
**Framework:** Jerarquía visual + Zonas definidas
**Location:** `MenuBarDropdownView.swift:152-162`

**Description:**
```swift
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.focallySurfaceContainerHighest)

        RoundedRectangle(cornerRadius: 3)
            .fill(Color.focallyPrimary)
            .frame(width: geometry.size.width * CGFloat(timerService.progress))
    }
}
.frame(height: 6)
```

**Why it works (Krug frameworks):**
- **Jerarquía visual:** El progreso es visual, fácil de ojear
- **Zonas claramente definidas:** Progreso está en su propia área
- **Auto-evidente:** Usuario entiende inmediatamente qué es (barra de progreso)

**Keep as-is** — Krug-compliant.

---

### 10. ✅ Footer stats "Today:" - ¿qué es today?
**Severity:** Low
**Framework:** Auto-evidencia
**Location:** `MenuBarDropdownView.swift:191`
**Status:** ✅ RESOLVED (Batch 5 - 2026-05-26)
**Resolution:** Changed "Today:" → "Focus today:"
**Commit:** (pending commit)

**Description:**
```swift
Text("Today: \(formatFocusTime())")
```

"Today:" es ambiguo - ¿today focally today system? User infiere pero no auto-evidente.

**Proposed Fix:**
```swift
// ❌ Actual
Text("Today: \(formatFocusTime())")

// ✅ Fix #1: Más específico
Text("Focus today: \(formatFocusTime())")

// ✅ Fix #2: Solo el tiempo (convención de menubar)
Text(formatFocusTime())
```

---

### 11. ✅ "Quiet mode on" vs "Quiet mode ready" - confuso
**Severity:** Medium
**Framework:** Auto-evidencia + Omisión de palabras
**Location:** `MenuBarDropdownView.swift:203`
**Status:** ✅ RESOLVED (Batch 2 - 2026-05-26)
**Resolution:** Simplified to "DND Active" / "DND Off"
**Commit:** (pending commit)

**Description:**
```swift
Text(dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready")
```

**Root Cause:**
"Quiet mode ready" es estado de preparación, no acción. "on" es activo. Los dos estados mezclados en un solo elemento con icono moon confunden.

**Proposed Fix:**
```swift
// ❌ Actual
Text(dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready")

// ✅ Fix #1: Solo estados activos
Text(dndService.isDNDActive ? "Quiet Mode" : "")

// ✅ Fix #2: Estados más directos
Text(dndService.isDNDActive ? "DND" : "DND Off")

// ✅ Fix #3: Solo icono + color
Image(systemName: dndService.isDNDActive ? "moon.fill" : "moon")
    .foregroundStyle(dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)
// No necesitas texto si el estado está claro visualmente
```

---

### 12. ✅ Botones play/pause/stop - bien diseñados
**Severity:** N/A (Good practice)
**Framework:** Clickeabilidad + Convenciones
**Location:** `MenuBarDropdownView.swift:132-144`

**Description:**
```swift
Button(action: { timerService.togglePause() }) {
    Image(systemName: timerService.isPaused ? "play.circle.fill" : "pause.circle.fill")
        .font(.system(size: 32))
        .foregroundStyle(.white)
}

Button(action: { timerService.resetToIdle() }) {
    Image(systemName: "stop.circle.fill")
        .font(.system(size: 32))
        .foregroundStyle(Color.focallyError)
}
```

**Why it works (Krug frameworks):**
- **Clickeabilidad:** Botones grandes (32pt) = obvios
- **Convenciones:** Iconos estándar de SF Symbols (play, pause, stop)
- **Auto-evidente:** Usuario entiende qué hace cada botón sin pensar
- **Jerarquía visual:** Tamaño grande indica importancia

**Keep as-is** — Krug-compliant.

---

## Known Technical Issues (from focally-ui-audit)

These are from the existing Focally UI audit, included for completeness:

- **Emoji dropdown shows shortcodes instead of Unicode previews** (Critical)
- **Emoji mismatch** 🧠→🎯 in FocusIntegrationService.swift
- **Slack scope issues** - `emoji:read` scope missing
- **GoogleCalendarService regression** - protocol conformance issues

*See `focally-ui-audit` skill for full details.*

---

## Krug Framework Assessment

### ✅ Compliant Areas
- Timer display (28pt, monospaced) - excelente jerarquía visual
- Play/pause/stop buttons - convenciones + clickeabilidad obvia
- Progress bar - zonas definidas + visual auto-evidente
- Spacing y layout general - buen uso de whitespace

### ❌ Non-Compliant Areas
- **Omisión de palabras:** Multiple locations con texto innecesario
- **Auto-evidencia:** Sections y estados poco claros
- **Clickeabilidad:** Predefined tasks sin hover state
- **Convenciones:** Header rompe patrones de menubar

---

## Priority Fixes

**Immediate (Critical):**
1. [ ] Simplificar "Paused · Notifications are back" → "Paused"
2. [ ] Agregar hover state a PredefinedTaskQuickButton

**High Priority:**
3. [ ] Eliminar "Create presets from Task Configuration." → "Create presets" o icono
4. [ ] Simplificar footer stats - eliminar redundancia de estado de notificaciones
5. [ ] Clarificar "Quiet mode on" vs "Quiet mode ready"

**Medium Priority:**
6. [ ] Mejorar header "Start fast, stay quiet." → más descriptivo
7. [ ] Clarificar section headers ("Quick Start" vs "Predefined tasks")

---

## References

- **Krug's Frameworks:** `ui-no-pensar` skill
- **Focally Technical Audit:** `focally-ui-audit` skill
- **Book:** "Don't Make Me Think" — Steve Krug (2000, 2nd ed 2005)
- **Web:** www.sensible.com (Steve Krug's site)