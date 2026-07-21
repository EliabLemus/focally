# BUG-041: Emoji miniatura en barra de menú muestra texto `:shortcode:` en vez del emoji

## Problema
Durante una sesión activa, la barra de menú muestra `:brain: 20 — Focus Time` en vez de `🧠 20 — Focus Time`. El `updateStatusBar()` ya llama `EmojiValidator.convertShortcodeToUnicode()` pero algo falla — posiblemente el emoji unicode resultante no se renderiza como miniatura en el NSStatusBarButton.title.

## Análisis
- `OnItFocusApp.swift` línea ~246: `button.title = " \(emojiDisplay) \(timerService.remainingMinutesString) — \(timerService.currentActivity)"`
- `emojiDisplay` viene de `convertShortcodeToUnicode(currentEmoji, ...) ?? currentEmoji`
- Para custom workspace emojis cae al `?? currentEmoji` y muestra el shortcode textual
- Para standard emojis, `convertShortcodeToUnicode` debería retornar el unicode, pero NSStatusBarButton puede tener limitaciones con ciertos emojis o el title + image combo puede estar causando conflicto

## Causas probables
1. **Custom emoji fallback**: Si `currentEmoji` es un custom emoji del workspace, `convertShortcodeToUnicode` retorna nil → muestra `:custom_emoji:` como texto
2. **NSStatusBarButton title rendering**: macOS puede no renderizar correctamente emojis en `button.title` cuando también hay `button.image` seteado. Solución: renderizar el emoji como NSImage via CoreText y usar `button.image` en vez de `button.title` para el emoji, o usar un solo atributo

## Solución propuesta
Renderizar el emoji como una NSImage pequeña (16x16) via CoreText y reemplazar el enfoque title+image con image-only en la barra:
1. Crear un helper `renderEmojiAsImage(_ emoji: String, size: CGFloat) -> NSImage?` que usa CoreText NSAttributedString para renderizar el emoji en un bitmap
2. En `updateStatusBar()`: cuando hay sesión, generar una imagen compuesta (emoji + texto de tiempo) o usar el emoji como image y el tiempo como title
3. Para custom emojis: intentar cargar la imagen del cache (`EmojiCacheService`), si no hay, usar un placeholder (circle con primera letra)

## Archivos
- `Focally/OnItFocusApp.swift` — `updateStatusBar()`
- Posible nuevo helper en `Focally/Services/` o extension en `EmojiValidator`

## Criterios de aceptación
- Barra muestra `🧠 20 — Focus Time` (emoji renderizado, no texto de shortcode)
- Custom emojis del workspace muestran la imagen real (descargada) o fallback razonable
- No muestra `:shortcode:` como texto jamás
- Build + tests pasan