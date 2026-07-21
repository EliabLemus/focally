# Fix 2: Autocomplete de emojis de Slack al escribir ":"

## Problema
Al escribir ":" en el campo de emoji del `FocusModeEditSheet`, no aparece ningún autocomplete/sugerencias de los emojis disponibles. El usuario necesita conocer los shortcodes de memoria.

## Solución
Implementar un dropdown de sugerencias que:
1. Se active cuando el usuario escribe ":" o ":" seguido de texto (e.g. ":br")
2. Filtre los `workspaceEmojiCodes` + los shortcodes estándar conocidos por coincidencia de texto
3. Muestre un máximo de ~8 resultados con preview visual (emoji unicode o imagen custom cached)
4. Al seleccionar uno, reemplace el texto del TextField con el shortcode completo
5. Se cierre al hacer click fuera, seleccionar, o presionar Escape

## Detalles técnicos
- Fuente de datos: `slackService.workspaceEmojiCodes` (custom) + mapa estático de `EmojiValidator` (estándar)
- Para custom: mostrar la imagen cached via `EmojiCacheService`
- Para estándar: mostrar el unicode via `convertShortcodeToUnicode`
- Posicionar el dropdown debajo del TextField
- Performance: filtrado en memoria (el catálogo es ~100-1000 items máximo)

## Archivos
- `Focally/Views/Timer/FocusModeEditSheet.swift` — agregar dropdown de autocomplete
- Posible nuevo componente: `Focally/Views/Shared/EmojiAutocompleteView.swift`

## Acceptance Criteria
- Escribir ":" → muestra lista de emojis disponibles (custom + estándar)
- Escribir ":br" → filtra a `:brain:`, `:bread:`, etc.
- Click en un resultado → reemplaza texto del TextField
- Escape o click fuera → cierra dropdown
- Performance: sin lag al escribir
