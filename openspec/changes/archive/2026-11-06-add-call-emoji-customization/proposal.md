# Proposal: add-call-emoji-customization

## Intent

La detección de llamadas ya funciona (v0.11.1 confirmada en macOS 15.7), pero el emoji que Focally publica en Slack está hardcodeado en `CallClientCatalog` (`Sources/Focally/Models/CallClient.swift`, el propio comentario dice "User-extendable settings UI is a follow-up"). El owner quiere `:google-meet:` para sus llamadas y poder personalizar el emoji por cliente. Los overrides de emoji POR CLIENTE no existen hoy — solo el emoji base del mensaje de foco es configurable.

Nota: `:google-meet:` YA es el default para `com.google.chrome` (CallClient.swift:23). La llamada de prueba del owner fue en **Arc** (`company.thebrowser.Browser`), que no está en el catálogo → resolvió a Unknown Client → `:phone:`. Este change (a) agrega Arc al catálogo default con `:google-meet:`, y (b) añade personalización de emoji por cliente + override del Unknown Client.

## What Changes

- `CallClientCatalog.defaultClients` gana `CallClient(bundlePrefix: "company.thebrowser", displayName: "Arc", emoji: ":google-meet:")` — Arc captura desde procesos `company.thebrowser.*`.
- `CallDetectionSettings` gana `callClientEmojiOverrides: [String: String]` (bundlePrefix → shortcode, persistido en UserDefaults con la misma infraestructura del store) + `unknownCallClientEmoji` (override del Unknown Client).
- Validación al guardar (decisión del owner, punto 3 de la crítica): si `workspaceEmojiCodes` está cargado y el shortcode escrito no está en la lista, la UI muestra advertencia inline pero PERMITE guardar (el workspace puede tener emojis no listados si el token tiene scope parcial).
- `CallClientCatalog.client(for:)` recibe los overrides: el override REEMPLAZA solo el `emoji`, nunca el `bundlePrefix` ni el `displayName`; los prefijos nuevos que el usuario agregue NO entran en este change (matching sigue siendo code-defined).
- `CallDetectionSettingsView` gana una sección "Emoji por app": fila por cliente conocido + fila para Unknown Client, cada una con el picker de búsqueda de shortcodes del workspace (reusa `slackService.workspaceEmojiCodes` y el patrón de búsqueda de `FocusModeEditSheet.swift:13-26`).
- Al aplicar el estado en Slack (`PresenceCoordinator` → `setStatus`), se usa el emoji resuelto con overrides. Cuando el workspace no tiene el shortcode, se registra warning y se cae a `:phone:` (comportamiento igual al fallback actual de Slack para shortcodes desconocidos).

**BREAKING: ninguno** — defaults iguales a la tabla actual; sin overrides el comportamiento es idéntico a v0.11.1.

## Capabilities

- **Nueva:** `call-emoji-customization`
- **Modificada:** ninguna

## Impact

- `Sources/Focally/Models/CallDetectionSettings.swift` (+2 campos + persistencia)
- `Sources/Focally/Models/CallClient.swift` (resolución con overrides, pure)
- `Sources/Focally/Views/Settings/CallDetectionSettingsView.swift` (sección picker)
- `Sources/Focally/Services/PresenceCoordinator.swift` (solo si el emoji se resuelve ahí y no en el atributor — a definir en implementación)
- Tests: `CallClientOverrideTests.swift` (resolución pura) + 1 test de persistencia en el store
