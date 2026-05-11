# SPEC: Alternativas de Ícono de Menu Bar (Focally)

## Contexto
- **Ícono actual**: `"timer"` (reloj de arena estándar de SF Symbols)
- **Ubicación**: Menú bar de macOS (`NSStatusBar.system.statusItem`)
- **Uso**:
  - Estado idle: muestra el ícono base
  - Sesión activa: muestra `"pause.fill"` o `"play.fill"` + emoji + tiempo
- **Feedback**: El usuario no está satisfecho con el ícono actual "timer"

## Objetivo
Explorar alternativas de SF Symbols para el ícono del menú bar que reflejen mejor la identidad de Focally como app de focus/productividad.

## Alternativas por Categoría

### Categoría: Enfoque/Concentración

| Ícono | Nombre | Variante | Notas |
|-------|--------|----------|-------|
| 🌙 | `moon` | `moon.fill` | Claro y universal para "modo focus" |
| ⚡ | `bolt` | `bolt.fill` | Energía, acción, "power mode" |
| 🎯 | `target` | `target.waves` | Meta, objetivo de concentración |
| 🏹 | `figure.archery` | - | Precision, focus en objetivo |
| 🧠 | `brain` | `brain.head.profile` | Concentración mental |

**Recomendación**: `moon.fill` o `bolt.fill` son los más reconocibles y encajan con la identidad de Focally.

---

### Categoría: Productividad/Acción

| Ícono | Nombre | Variante | Notas |
|-------|--------|----------|-------|
| ▶️ | `play.circle` | `play.circle.fill` | Iniciar sesión |
| ⏸️ | `pause.circle` | `pause.circle.fill` | Pausar sesión |
| ⏹️ | `stop.circle` | `stop.circle.fill` | Terminar sesión |
| ▶️ | `play.fill` | - | Simple y directo |
| ⏸️ | `pause.fill` | - | Ya se usa para pausa activa |
| ⏹️ | `stop.fill` | - | Ya se usa para terminar |
| 🔁 | `arrow.clockwise` | `arrow.counterclockwise` | Ciclos, pomodoro |
| ⏱️ | `stopwatch` | - | Más elegante que `timer` |

**Recomendación**: `play.circle.fill` si se quiere mantener la lógica actual de íconos distintos para estados.

---

### Categoría: Minimalista/Abstracto

| Ícono | Nombre | Variante | Notas |
|-------|--------|----------|-------|
| ⭕ | `circle` | `circle.fill` | Minimalista, limpio |
| 📍 | `location.circle` | `location.circle.fill` | Marcador de tiempo |
| 🚩 | `flag` | `flag.fill` / `flag.circle` | Completar tareas |
| ⚪ | `dot.circle` | `dot.circle.fill` | Estado activo |
| 💠 | `diamond` | `diamond.fill` | Focus, precisión |
| 🔸 | `app.badge` | - | Badge de app |

**Recomendación**: `circle.fill` es minimalista y no distrae, pero puede ser muy genérico.

---

### Categoría: Documentos/Tareas

| Ícono | Nombre | Variante | Notas |
|-------|--------|----------|-------|
| 📝 | `doc` | `doc.fill` | Trabajo |
| 📝 | `doc.circle` | `doc.circle.fill` | Trabajo con badge |
| ✅ | `checkmark.circle` | `checkmark.circle.fill` | Completado |
| ✅ | `checkmark.seal` | `checkmark.seal.fill` | Sellado, importante |
| 📋 | `list.clipboard` | `list.clipboard.fill` | Tareas pendientes |
| ✏️ | `pencil.circle` | `pencil.circle.fill` | Edición, trabajo |

**Recomendación**: `checkmark.circle.fill` si se quiere enfatizar la meta de completar sesiones.

---

### Categoría: Tiempo/Reloj (Alternativas a "timer")

| Ícono | Nombre | Variante | Notas |
|-------|--------|----------|-------|
| ⏱️ | `stopwatch` | - | Más moderno que `timer` |
| ⌚ | `clock` | `clock.fill` | Reloj simple |
| ⌚ | `alarm` | `alarm.fill` | Alarma, recordatorio |
| 🕐 | `clock.badge.exclamationmark` | - | Urgencia |
| ⏲️ | `timer.circle` | `timer.circle.fill` | `timer` con badge |

**Recomendación**: `stopwatch` es más moderno y evita la connotación de "espera" que tiene `timer`.

---

## Implementación Sugerida

### Cambio Simple (Solo ícono idle)

Cambiar solo el ícono base cuando no hay sesión activa:

```swift
// En OnItFocusApp.swift, método updateStatusBar()

// Actual (línea ~215):
button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")

// Opciones:
button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Focally")
// o
button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Focally")
// o
button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Focally")
```

**Impacto**: Solo cambia el ícono visible cuando no hay sesión activa. Los íconos de sesión activa (`pause.fill`/`play.fill`) se mantienen igual.

---

### Cambio Completo (Sistema de íconos consistente)

Crear un sistema de íconos consistente para todos los estados:

```swift
// En OnItFocusApp.swift

enum StatusBarIcon {
    case idle
    case running
    case paused

    var systemName: String {
        switch self {
        case .idle: return "moon.fill"  // ⬅️ Cambiar esto
        case .running: return "pause.circle.fill"
        case .paused: return "play.circle.fill"
        }
    }
}

// En updateStatusBar():
if timerService.hasSession {
    let iconState: StatusBarIcon = timerService.isPaused ? .paused : .running
    button.image = NSImage(systemSymbolName: iconState.systemName, accessibilityDescription: "Focally")
    // ...
} else {
    button.image = NSImage(systemSymbolName: StatusBarIcon.idle.systemName, accessibilityDescription: "Focally")
}
```

**Impacto**: Sistema consistente con íconos de círculo para estados activos y un ícono distinto para idle.

---

### Sistema de Íconos Complejo (Meta de marca)

Crear un sistema de íconos que cambie según el estado del timer:

```swift
enum TimerStateIcon {
    case idle          // ⬅️ Estado inicial
    case running       // Sesión en progreso
    case paused        // Sesión pausada
    case warning       // < 5 minutos restantes
    case critical      // < 1 minuto restante

    var systemName: String {
        switch self {
        case .idle: return "moon.fill"           // 🌙
        case .running: return "pause.circle.fill" // ⏸️
        case .paused: return "play.circle.fill"   // ▶️
        case .warning: return "exclamationmark.triangle.fill" // ⚠️
        case .critical: return "exclamationmark.octagon.fill"  // 🛑
        }
    }
}

// En updateStatusBar():
if timerService.hasSession {
    let stateIcon: TimerStateIcon

    if timerService.isPaused {
        stateIcon = .paused
    } else if timerService.remainingSeconds <= 60 {
        stateIcon = .critical
    } else if timerService.remainingSeconds <= 300 {
        stateIcon = .warning
    } else {
        stateIcon = .running
    }

    button.image = NSImage(systemSymbolName: stateIcon.systemName, accessibilityDescription: stateIcon.description)
    // ...
}
```

**Impacto**: Feedback visual más rico sobre el estado del timer, pero puede distraer si hay muchos cambios de ícono.

---

## Recomendación Final

### Opción 1: Cambio Simple (Rápido)
- **Ícono idle**: `stopwatch` (más moderno que `timer`)
- **Íconos de sesión**: Mantener `pause.fill`/`play.fill`
- **Pros**: Cambio mínimo, familiaridad preservada
- **Contras**: Todavía es un reloj

### Opción 2: Cambio Medio (Balanceado) ⭐ Recomendado
- **Ícono idle**: `moon.fill` (focus, claro)
- **Íconos de sesión**: `pause.circle.fill`/`play.circle.fill` (círculos)
- **Pros**: Identidad de "focus" clara, sistema visual consistente
- **Contras**: Requiere cambiar más código

### Opción 3: Cambio Radical (Brand-focused)
- **Ícono idle**: `bolt.fill` (energía, acción)
- **Sistema completo**: Íconos de círculo para todos los estados
- **Pros**: Identidad única, más energía visual
- **Contras**: Puede no comunicar "calma" o "focus"

---

## Archivos a Modificar

### Cambio Simple
- `Focally/OnItFocusApp.swift`
  - Método `updateStatusBar()`
  - Línea: `button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")`

### Cambio Completo
- `Focally/OnItFocusApp.swift`
  - Agregar `enum StatusBarIcon` (o `TimerStateIcon`)
  - Modificar `updateStatusBar()` para usar el enum
  - Opcional: Modificar método de menú contextual para usar íconos consistentes

---

## Testing

### Manual Testing Checklist
- [ ] Abrir Focally → ícono idle visible
- [ ] Iniciar sesión → ícono cambia a estado activo
- [ ] Pausar sesión → ícono cambia a estado pausado
- [ ] Terminar sesión → ícono vuelve a idle
- [ ] Verificar que el ícono sea legible en modo claro y oscuro
- [ ] Verificar que el ícono sea legible en menú bar de diferentes tamaños

### Accesibilidad
- [ ] Verificar que `accessibilityDescription` sea apropiado
- [ ] Probar con Voice Over en macOS
- [ ] Verificar contraste en modos claro y oscuro

---

## Referencias

- [SF Symbols Documentation](https://developer.apple.com/sf-symbols/)
- [SF Symbols App](https://apps.apple.com/us/app/sf-symbols/id1462497870) (search: "timer", "moon", "bolt", "target", "focus")
- [Apple Human Interface Guidelines - Menu Bar Icons](https://developer.apple.com/design/human-interface-guidelines/menus/menus-and-menu-items)

---

**Eliab**: ¿Cuál categoría o opción te llama más la atención? Puedo implementar cualquiera de estas.
