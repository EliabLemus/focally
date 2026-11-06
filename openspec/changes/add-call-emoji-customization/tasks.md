# Tasks: add-call-emoji-customization

Baseline: suite verde (82 tests) antes de empezar; cada tarea la mantiene verde.

- [ ] 1. `CallDetectionSettings` + store: agregar `callClientEmojiOverrides: [String: String]` y `unknownCallClientEmoji: String?` con persistencia UserDefaults (`Key.callClientEmojiOverrides`, `Key.unknownCallClientEmoji`), decodificando el diccionario como JSON string (mismo patrón del store para tipos compuestos). Verificación: test de round-trip save/load en `CallDetectionSettingsStoreTests` (o archivo nuevo `CallEmojiOverridePersistenceTests`).
- [ ] 2. Resolución pura: `CallClientCatalog.client(for:overrides:)` (y equivalente para unknown) que reemplaza solo `emoji`. Verificación: `CallClientOverrideTests` — override aplicado, matching/displayName intactos, override vacío = comportamiento v0.11.1.
- [ ] 3. Wiring: inyectar overrides desde el store al punto donde el `emoji` llega a `setStatus` (PresenceCoordinator / PresenceSlackServicing — decidir en implementación según dónde vive hoy el string final). Verificación: test del coordinator con store fake verifica que el emoji override llega al fake de Slack.
- [ ] 4. UI: sección "Emoji por app" en `CallDetectionSettingsView` — fila por cliente + Unknown Client, picker reusando `workspaceEmojiCodes` (patrón `FocusModeEditSheet`). Verificación: manual — configurar `:google-meet:` y entrar en llamada; e2e única: estado en Slack muestra el emoji configurado.
- [ ] 5. Warning de shortcode inexistente: log en unified logging cuando Slack rechace el shortcode (si es detectable desde la respuesta; si no, documento el comportamiento de fallback de Slack). Verificación: log visible en `log stream --predicate 'subsystem == "app.focally.mac"'`.
- [ ] 6. Verificación e2e única reutilizable: script ad-hoc que confirme defaults→override→persistencia y una llamada real con estado `:google-meet:` visible en Slack (confirmación del owner).
