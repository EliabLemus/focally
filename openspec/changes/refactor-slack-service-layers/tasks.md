# Tasks: refactor-slack-service-layers

Orden de ejecución: cada tarea deja la suite verde (`xcodebuild test -scheme Focally -destination 'platform=macOS'`, baseline 82 tests).

- [ ] 1. Crear `SlackEmojiCatalog.swift` moviendo tablas estáticas (~L991-3310), `EmojiValidator` y fuzzy search desde `SlackService.swift`, sin tocar red. Verificación: suite verde + `grep -c "" SlackService.swift` baja ~2,500 líneas; cero cambios en llamadores.
- [ ] 2. Crear `SlackError` tipado (rateLimited(retryAfter:), authInvalid, network(underlying:), decoding, unknown) con tests unitarios de categorización puros. Verificación: tests nuevos verdes.
- [ ] 3. Crear `SlackAPIClient.swift` con `performRequest` async inyectando `URLSession`; mover `performSlackRequest` (SlackService.swift:782) y generalizar el gate de `emojiRefreshBlockedUntil` (:450-500) a bloqueo por método con `Retry-After`. Verificación: `SlackAPIClientTests` con URLProtocol mock cubre 429+Retry-After→reintento único, invalid_auth, timeout.
- [ ] 4. Migrar `setStatus` (:227), `clearStatus` (:322), `testConnection` (:372), `validateToken` (:638) a través de `SlackAPIClient` con puentes `withCheckedContinuation` para conservar firmas callback. Verificación: suite verde; consumers (PresenceCoordinator:92, FocusIntegrationService) sin cambios.
- [ ] 5. Crear `SlackStatusService.swift` con estado de conexión y exponer `SlackService` como fachada observable. Verificación: suite verde + smoke manual: cambio de estado de Slack visible en Settings → Integrations.
- [ ] 6. `KeychainHelper` find→update→else add, devolver `OSStatus`, log con `os.log`. Verificación: test que guarda dos veces y verifica update (mock o ítem real de test); fallo simulado visible en unified logging.
- [ ] 7. Verificación e2e única reutilizable: con token real de pruebas, cambiar el estado en Focally y confirmar en Slack; luego simular rate limit (si es posible) o verificar logs de gate. Verificación: script ad-hoc `hermes-verify` + confirmación del usuario en Slack.
