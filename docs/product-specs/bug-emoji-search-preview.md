# Spec: Mejorar visual de emojis en búsqueda de popover

## Contexto
El usuario reporta que cuando busca emojis en el TextField de Quick Sessions, los resultados de la sección "Slack workspace" NO muestran emojis visuales, sino shortcodes literales como `:deep_work:`.

## Análisis del Problema

### Ubicación
- Archivo: `Focally/Views/Shared/FocusSessionComponents.swift`
- Función: `EmojiSelectionPopover.emojiDisplayString(for:)` (líneas 243-249)

### Flujo actual
1. Usuario escribe en TextField `"Emoji or :shortcode:"` (línea 143)
2. `workspaceCodes` filtra `slackService.workspaceEmojiCodes` por query (línea 127)
3. Cada botón llama a `emojiButton(code)` (línea 178)
4. `emojiButton` llama a `emojiDisplayString(for: code)` (línea 229)
5. `emojiDisplayString` intenta convertir shortcode a unicode (línea 246)
6. Si `EmojiValidator.convertShortcodeToUnicode` retorna `nil`, muestra shortcode literal
7. Resultado: `":deep_work:"` en lugar de emoji visual

### Causa Raíz
El mapa de conversión estático (`shortcodeMap` en `EmojiValidator`) NO incluye todos los emojis del workspace del usuario. Custom emojis y otros emojis de Slack no están en el mapa.

Fallback actual:
```swift
return EmojiValidator.convertShortcodeToUnicode(code, workspaceEmojis: slackService.workspaceEmojiCodes) ?? code
```
Cuando falla, muestra `code` literalmente (ej. `:custom_emoji:`).

---

## Solución Propuesta

### Cambio: Mejorar fallback de conversión en `emojiDisplayString`

**Archivo:** `Focally/Views/Shared/FocusSessionComponents.swift`
**Líneas:** 242-249

**Código ANTES:**
```swift
/// Convierte un shortcode o unicode a su representación de display
private func emojiDisplayString(for code: String) -> String {
    if Self.isSlackShortcode(code) {
        // Intentar convertir shortcode a unicode
        return EmojiValidator.convertShortcodeToUnicode(code, workspaceEmojis: slackService.workspaceEmojiCodes) ?? code
    }
    return code
}
```

**Código DESPUÉS:**
```swift
/// Convierte un shortcode o unicode a su representación de display
private func emojiDisplayString(for code: String) -> String {
    if Self.isSlackShortcode(code) {
        // Intentar convertir shortcode a unicode
        if let emoji = EmojiValidator.convertShortcodeToUnicode(code, workspaceEmojis: slackService.workspaceEmojiCodes) {
            return emoji
        }

        // Fallback: mostrar nombre legible en lugar de shortcode técnico
        let name = code.dropFirst().dropLast()  // Remover los dos puntos
        let displayName = name
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        // Truncar a 15 caracteres máximo para botones pequeños
        if displayName.count > 15 {
            let index = displayName.index(displayName.startIndex, offsetBy: 15)
            return String(displayName[..<index]) + "…"
        }
        return displayName
    }
    return code
}
```

---

## Justificación según "Don't Make Me Think"

| Problema actual | Solución propuesta |
|-----------------|--------------------|
| `:deep_work:` ← usuario ve código técnico | `Deep Work` ← usuario ve nombre legible ✅ |
| No es auto-evidente, requiere decodificar mentalmente | Auto-evidente, palabras separadas ✅ |
| No se puede escanear, hay que leer cada caracter | Escaneable, formato de texto normal ✅ |
| Ruido (símbolos `:` y `_`) | Sin ruido, solo información útil ✅ |

---

## Criterios de Aceptación

1. [ ] Build compila sin errores
2. [ ] Búsqueda de emojis muestra nombres legibles en lugar de shortcodes
3. [ ] Nombres se truncan a 15 caracteres con `…` si son largos
4. [ ] Emojis que SÍ están en el mapa siguen mostrando el emoji visual
5. [ ] No hay cambios en comportamiento de emoji unicode directo

---

## Testing Manual

1. Abrir Focally
2. Ir a Quick Sessions
3. Click en el botón de emoji (popover)
4. Escribir en el TextField: `"focus"`
5. Verificar que la sección "Slack workspace" muestra:
   - `Deep Work` en lugar de `:deep_work:`
   - `Focus` en lugar de `:focus:`
6. Click en un emoji del workspace
7. Verificar que el preview muestra el shortcode (para Slack API) o emoji visual (si está en mapa)

---

## Notas de Implementación

- El cambio es solo visual en el popover de búsqueda
- El valor seleccionado sigue siendo el shortcode para Slack API
- La conversión `shortcode → unicode` en el preview principal usa el mapa existente
- Truncado a 15 caracteres evita botones desbordados

---

## Referencias

- Archivo afectado: `Focally/Views/Shared/FocusSessionComponents.swift` (líneas 242-249)
- Función relacionada: `EmojiValidator.convertShortcodeToUnicode` (líneas 703-762)
- Skill de UX: `ui-no-pensar` y `usability-audit` (Steve Krug)