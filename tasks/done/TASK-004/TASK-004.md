# TASK-004: Fix 3 UX regressions in Focally v0.4.1

## Status
**PENDING**

## Date
2026-04-30

## Priority
Alta — Regresiones que rompen el flujo principal de la app

## Context
Eliab probó v0.4.1 y reportó 3 bugs. Todos son regresiones de TASK-002.

## Bugs

### Bug 1: Pomodoro tab — Short Break y Long Break no visibles
**Archivo:** `Focally/Views/SettingsView.swift` → `pomodoroTab`

**Problema:** Los 3 Pickers (Work, Short Break, Long Break) están en un `HStack` con `.frame(width: 120)` cada uno = ~380px mínimo. La ventana tiene `minWidth: 420` pero el contenido con padding y labels no cabe. Los pickers de Short Break y Long Break quedan fuera de la vista visible.

**Fix:** Cambiar los pickers a layout vertical (VStack) con cada picker en su propia fila: Label + Picker. Esto garantiza que quepan sin importar el ancho de ventana.

```swift
// ANTES (roto - HStack con 3 pickers):
HStack(spacing: 12) {
    Picker("Work", selection: ...)
        .frame(width: 120)
    Picker("Short Break", selection: ...)
        .frame(width: 120)
    Picker("Long Break", selection: ...)
        .frame(width: 120)
}

// DESPUÉS (fix - VStack con filas):
VStack(spacing: 8) {
    HStack {
        Text("Work")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .leading)
        Picker("Work", selection: $draftWorkDurationMinutes) {
            ForEach(1...60, id: \.self) { min in
                Text("\(min) min").tag(min)
            }
        }
        .pickerStyle(.menu)
        Spacer()
    }
    HStack {
        Text("Short Break")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .leading)
        Picker("Short Break", selection: $draftShortBreakDurationMinutes) {
            ForEach(1...30, id: \.self) { min in
                Text("\(min) min").tag(min)
            }
        }
        .pickerStyle(.menu)
        Spacer()
    }
    HStack {
        Text("Long Break")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .leading)
        Picker("Long Break", selection: $draftLongBreakDurationMinutes) {
            ForEach(1...60, id: \.self) { min in
                Text("\(min) min").tag(min)
            }
        }
        .pickerStyle(.menu)
        Spacer()
    }
}
```

### Bug 2: No puedo iniciar tareas ni elegir entre Pomodoro o custom
**Archivo:** `Focally/Views/FocusMenuView.swift` → `idleView`
**Archivo:** `Focally/Views/ActivityInputView.swift`

**Problema:** 
- En `idleView` solo hay "Start Focus" (abre ActivityInputView) y "Reset".
- `ActivityInputView` requiere escribir un nombre de actividad manualmente.
- No hay forma de iniciar un Pomodoro rápido con la duración configurada en Settings.
- Si el usuario no tiene predefined tasks, no tiene atajos.

**Fix:** Agregar un botón "Quick Start Pomodoro" en `idleView` que inicie una sesión de trabajo directamente con la duración de Settings (`workDurationMinutes`). Esto permite al usuario iniciar sin pasar por el ActivityInputView.

```swift
// En idleView, agregar antes o junto al botón "Start Focus":
Button(action: {
    timerService.startWorkSession(
        activity: "Focus Session",
        emoji: "🍅",
        durationMinutes: timerService.workDurationMinutes
    )
    dndService.activateDND()
}) {
    Label("🍅 Quick Start", systemImage: "play.fill")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.borderedProminent)
.tint(.orange)
```

El flujo debe ser:
1. **Quick Start** → Inicia Pomodoro inmediato con settings (25min, breaks automáticos)
2. **Start Focus** → Abre ActivityInputView para nombre personalizado + duración custom
3. **Reset** → Limpia estado

### Bug 3: Perdimos funcionalidad de iniciar, pausar o detener tareas
**Archivo:** `Focally/Views/FocusMenuView.swift` → `activeView`

**Problema:** 
- `activeView` tiene Pause/Resume y Skip, pero **NO tiene Stop**.
- El usuario no puede detener una sesión activa y volver a idle.
- Solo puede pausar/skip. Si quiere detener, no hay botón.

**Fix:** Agregar botón "Stop" (o "End") en los controles del `activeView`:

```swift
// En activeView, en el HStack de controles, agregar:
Button(action: {
    timerService.resetToIdle()
    dndService.deactivateDND()
}) {
    Label("Stop", systemImage: "stop.fill")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(.red)
```

Los controles deben ser:
- **Pause/Resume** — pausa o continua el timer
- **Skip** — salta a la siguiente fase (solo durante breaks)
- **Stop** — detiene todo y vuelve a idle (SIEMPRE visible durante sesión activa)

## Files to modify
1. `Focally/Views/SettingsView.swift` — Fix pomodoroTab layout (Bug 1)
2. `Focally/Views/FocusMenuView.swift` — Agregar Quick Start en idleView, Stop en activeView (Bugs 2 & 3)

## Testing checklist
- [ ] Settings → Pomodoro tab: los 3 pickers (Work, Short Break, Long Break) son visibles sin scroll
- [ ] Settings → Pomodoro tab: cambiar valores y guardar persiste correctamente
- [ ] Idle state: botón "Quick Start" inicia Pomodoro con duración de settings
- [ ] Idle state: botón "Start Focus" abre ActivityInputView
- [ ] Active state (work): botones Pause, Stop visibles
- [ ] Active state (break): botones Pause, Skip, Stop visibles
- [ ] Stop: vuelve a idle, limpia estado, desactiva DND
- [ ] Pause/Resume: funcionan correctamente
- [ ] Skip: avanza a siguiente fase correctamente

## Acceptance criteria
- ✅ Pomodoro tab muestra todos los controles sin overflow
- ✅ Quick Start inicia sesión sin requerir input del usuario
- ✅ Start Focus abre el form completo (ActivityInputView)
- ✅ Pause, Resume, Skip, Stop todos funcionan
- ✅ Stop desactiva DND y vuelve a idle
- ✅ Build exitoso sin errores ni warnings
