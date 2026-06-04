# Spec: Completar mapeo de shortcodes de Slack a Unicode en Focally

## Contexto
El bug reportado muestra que en Quick Sessions, cuando se selecciona un emoji con shortcode (ej. `:deep_work:`), el preview muestra el shortcode literal en lugar del emoji visual.

## Análisis del Problema

### Ubicación
- Archivo: `Focally/Services/SlackService.swift`
- Función: `EmojiValidator.convertShortcodeToUnicode(_ shortcode: String, workspaceEmojis: [String]) -> String?`
- Líneas: ~708-750

### Causa Raíz
El mapa de shortcodes (`shortcodeMap`) está incompleto. Faltan los shortcodes que se usan en `FocusStatusOption.common`:

**Shortcodes faltantes en el mapa:**
- `:deep_work:` → `🧠`
- `:coding:` → `💻`
- `:writing:` → `📝`
- `:reading:` → `📚`
- `:priority:` → `🎯`
- `:sprint:` → `⚡️`
- `:quiet:` → `🔕`
- `:coffee:` → `☕️`

**Shortcodes faltantes (extras):**
- `:pomodoro:` → `🍅`
- `:tomato:` → `🍅` (ya existe, redundante)

### Flujo del Bug
1. Usuario selecciona emoji con shortcode en Quick Sessions
2. `selectedEmoji` = `:deep_work:`
3. `slackStatusPreview` llama a `emojiDisplayString(for: selectedEmoji)`
4. `emojiDisplayString` detecta shortcode y llama a `EmojiValidator.convertShortcodeToUnicode`
5. `convertShortcodeToUnicode` busca en `shortcodeMap` y NO encuentra `:deep_work:`
6. Retorna `nil`
7. `emojiDisplayString` usa fallback: `?? shortcode` → devuelve `:deep_work:`
8. Preview muestra `"Slack status: :deep_work:"` ❌

---

## Solución Propuesta

### Cambio 1: Completar el mapa de shortcodes

**Archivo:** `Focally/Services/SlackService.swift`
**Líneas:** ~708-750 (dentro de `convertShortcodeToUnicode`)

**Código ANTES:**
```swift
let shortcodeMap: [String: String] = [
    ":brain:": "🧠",
    ":computer:": "💻",
    ":memo:": "📝",
    ":books:": "📚",
    ":dart:": "🎯",
    ":zap:": "⚡",
    ":coffee:": "☕",
    ":tomato:": "🍅",
    ":hourglass_flowing_sand:": "⏳",
    ":star:": "⭐",
    ":fire:": "🔥",
    ":rocket:": "🚀",
    ":check:": "✅",
    ":white_check_mark:": "✅",
    ":heavy_check_mark:": "✅",
    ":x:": "❌",
    ":heavy_multiplication_x:": "❌"
]
```

**Código DESPUÉS:**
```swift
let shortcodeMap: [String: String] = [
    // Common Slack emojis (standard names)
    ":brain:": "🧠",
    ":computer:": "💻",
    ":memo:": "📝",
    ":books:": "📚",
    ":dart:": "🎯",
    ":zap:": "⚡",
    ":coffee:": "☕",
    ":tomato:": "🍅",
    ":hourglass_flowing_sand:": "⏳",
    ":star:": "⭐",
    ":fire:": "🔥",
    ":rocket:": "🚀",
    ":check:": "✅",
    ":white_check_mark:": "✅",
    ":heavy_check_mark:": "✅",
    ":x:": "❌",
    ":heavy_multiplication_x:": "❌",

    // Focally custom shortcodes (from FocusStatusOption.common)
    ":deep_work:": "🧠",
    ":coding:": "💻",
    ":writing:": "📝",
    ":reading:": "📚",
    ":priority:": "🎯",
    ":sprint:": "⚡️",
    ":quiet:": "🔕",
    ":coffee:": "☕️",
    ":pomodoro:": "🍅"
]
```

**Notas:**
- Mantener el formato de agrupación con comentarios para mantenibilidad
- `:coffee:` está duplicado (ya existe con `☕`), pero añadir `☕️` con variante
- Ordenar por lógica: standard primero, custom después

---

### Cambio 2: Mejorar fallback de conversión (opcional pero recomendado)

**Ubicación:** Misma función `EmojiValidator.convertShortcodeToUnicode`

**Mejora:** Si el shortcode no está en el mapa, intentar inferir del nombre antes de retornar `nil`.

**Código a añadir (antes de `return nil`):**
```swift
// Intentar inferir emoji del nombre (heurística simple)
let name = shortcode.dropFirst().dropLast().lowercased()
let commonEmojiNames: [String: String] = [
    "deep_work": "🧠",
    "coding": "💻",
    "writing": "📝",
    "reading": "📚",
    "priority": "🎯",
    "sprint": "⚡️",
    "quiet": "🔕",
    "pomodoro": "🍅"
]

if let inferred = commonEmojiNames[name] {
    return inferred
}
```

**Nota:** Este cambio es redundante si el mapa está completo, pero adds robustness si se añaden más shortcodes en el futuro.

---

## Criterios de Aceptación

1. [ ] El mapa de shortcodes incluye todos los shortcodes de `FocusStatusOption.common`
2. [ ] Build compila sin errores
3. [ ] Tests pasan (`xcodebuild test`)
4. [ ] Preview en Quick Sessions muestra emoji visual (`⏳`) en lugar de shortcode (`:hourglass_flowing_sand:`)
5. [ ] Selector de emojis en popover muestra visualmente los emojis
6. [ ] No hay duplicados en el mapa (verificar que no hay entries repetidas con misma key)

---

## Testing Manual

1. Abrir Focally
2. Ir a Quick Sessions
3. Seleccionar diferentes emojis del selector
4. Verificar que el preview `"Slack status: X"` muestra siempre el emoji visual
5. Probar cada shortcode de `FocusStatusOption.common`:
   - `:deep_work:` → 🧠
   - `:coding:` → 💻
   - `:writing:` → 📝
   - `:reading:` → 📚
   - `:priority:` → 🎯
   - `:sprint:` → ⚡️
   - `:quiet:` → 🔕
   - `:coffee:` → ☕️
   - `:pomodoro:` → 🍅

---

## Notas de Implementación

- No cambiar la signature de la función
- No modificar el comportamiento de validación (`isValidForSlack`)
- Mantener comentarios existentes
- Agregar comentarios claros para la nueva sección de custom shortcodes

---

## Referencias

- Archivo afectado: `Focally/Services/SlackService.swift` (líneas ~708-750)
- Uso del mapa: `FocusSessionComponents.swift` (líneas 97, 246), `QuickSessionsSection.swift` (línea 85)
- Definición de shortcodes: `FocusSessionComponents.swift` (líneas 10-20)