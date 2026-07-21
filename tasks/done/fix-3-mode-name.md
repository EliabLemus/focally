# Fix 3: Título "." al agregar nuevo Focus Mode

## Problema
Al crear un nuevo Focus Mode, el campo `name` se inicializa como `""`. Como no hay campo Name en el sheet, queda vacío y se muestra como "." en la UI.

## Solución
No agregar campo Name. En su lugar, usar `statusText` como título automáticamente:

1. En `FocusMode.sanitized()`: si `name` está vacío, usar `statusText` como name
2. Si ambos están vacíos, usar "Untitled"
3. `displayEmoji` y card muestran `mode.name` — así que con `statusText` como fallback se mostrará el mensaje de Slack como título

## Cambios concretos
- `Focally/Models/FocusMode.swift` → `sanitized()`: `name = name.isEmpty ? statusText : name` (antes de sanitizar statusText)

## Archivo único
- `Focally/Models/FocusMode.swift`
