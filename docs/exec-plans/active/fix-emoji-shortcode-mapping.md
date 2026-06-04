# Plan de Ejecución: Bug Emoji Shortcode Mapping

## Tarea
Completar el mapeo de shortcodes de Slack a Unicode en Focally para mostrar emojis visuales en lugar de shortcodes literales.

## Archivo afectado
- `Focally/Services/SlackService.swift` (líneas ~708-750)

## Pasos

### 1. Localizar la función `EmojiValidator.convertShortcodeToUnicode`
- Buscar línea `public static func convertShortcodeToUnicode` en `SlackService.swift`

### 2. Expandir el mapa `shortcodeMap`
Añadir los shortcodes faltantes después de la línea `":heavy_multiplication_x:": "❌"`:

```swift
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
```

### 3. Build y test
```bash
cd /Users/openjaime/Projects/focally/Focally
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build
```

### 4. Verificar build exitoso
- Esperar "BUILD SUCCEEDED"
- No errors ni warnings

### 5. Commit
```bash
cd /Users/openjaime/Projects/focally
git add -A
git commit -m "fix: complete Slack shortcode mapping for FocusStatusOption.common emojis"
```

---

## Criterios de éxito
1. [ ] Build compila sin errores
2. [ ] El mapa incluye todos los shortcodes de `FocusStatusOption.common`
3. [ ] Preview de Quick Sessions muestra emoji visual (ej. `Slack status: ⏳`) en lugar de shortcode (`Slack status: :hourglass_flowing_sand:`)

---

## Estimación
- Tiempo: ~5 minutos
- Complejidad: Baja (simple adición de key-value pairs)
- Riesgo: Nulo (solo datos, no lógica)