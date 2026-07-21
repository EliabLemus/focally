# Fix 1: Emojis de Slack muestran texto en vez de imagen

## Problema
Cuando un usuario pone un emoji estándar de Slack como `:taco:` que NO está en el mapa estático de `EmojiValidator.convertShortcodeToUnicode`, retorna `nil` y el `fallbackText` muestra el texto raw `:taco:` en vez del emoji unicode.

## Solución
Expandir el mapa `convertShortcodeToUnicode` dinámicamente con los emojis usados recientemente por el usuario:

1. **`EmojiUsageTracker.recentEmojis`** ya registra los shortcodes usados (max 12). Pero necesitamos la URL de imagen de esos emojis para poder renderizarlos.

2. **Flow**:
   - El usuario usa `:taco:` en una sesión → `EmojiUsageTracker.recordUsage(":taco:")` se llama (ya existe)
   - `SlackService.refreshEmojiCatalogIfPossible()` trae `workspaceEmojiCodes` + `workspaceEmojiImageURLs` — pero estos SOLO contienen custom emojis, no estándar
   - **Los emojis estándar de Slack SÍ tienen URLs predecibles**: los aliases en `emoji.list` apuntan a URLs como `alias:taco` que se resuelven en `emoji_map[taco]` → pero NO, los estándar NO vienen en `emoji.list`

3. **Mejor approach**:
   - Los emojis estándar de Slack son todos Unicode — solo necesitamos el mapa shortcode→unicode amplio
   - Agregar al mapa los shortcodes de los `recentEmojis` que faltan, buscando su unicode correspondiente
   - **NO viable**: no hay API de Slack para resolver shortcode estándar→unicode automáticamente

4. **Approach realista**: ampliar el mapa estático significativamente (200+ shortcodes comunes) Y cuando un shortcode no esté en el mapa, mostrar el `fallbackText` como un badge estilizado (no texto raw):
   - Texto del shortcode en una cápsula con fondo: `:taco:` con rounded rect y color secondary
   - No texto plain feo

## Cambios concretos
- `Focally/Services/SlackService.swift` → `convertShortcodeToUnicode()`: expandir mapa con ~100 shortcodes más (comida, animales, gestos, objetos comunes en Slack)
- `Focally/Views/Shared/EmojiView.swift` → `fallbackText`: cuando `fallbackEmoji == emoji` (no se pudo convertir), mostrar en badge estilizado en vez de texto plain

## Archivos
- `Focally/Services/SlackService.swift` — expandir mapa en `convertShortcodeToUnicode`
- `Focally/Views/Shared/EmojiView.swift` — mejorar fallback visual
