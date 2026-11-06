# Delta spec: slack-api (nueva capability)

## ADDED Requirements

### Requirement: El cliente Slack respeta el rate limiting en todos los métodos

El sistema SHALL aplicar un gate de rate limiting por método de API a todas las llamadas HTTP salientes (`emoji.list`, `users.profile.set`, `auth.test`, etc.), y ante una respuesta 429 MUST esperar los segundos indicados por el header `Retry-After` antes de reintentar el mismo método.

#### Scenario: setStatus recibe 429 con Retry-After

- **WHEN** `users.profile.set` responde HTTP 429 con header `Retry-After: 30`
- **THEN** el cliente bloquea `users.profile.set` por 30 segundos y reintenta automáticamente una vez al vencer el bloqueo
- **AND** el resultado del reintento se propaga al caller (éxito o error tipado), nunca un fallo silencioso

#### Scenario: emoji.list conserva su comportamiento actual

- **WHEN** `emoji.list` responde 429 con header `Retry-After`
- **THEN** el catálogo de emojis se salta el refresh hasta el deadline (comportamiento equivalente al actual `emojiRefreshBlockedUntil`, ahora implementado por el cliente)

### Requirement: El transporte HTTP es async y testeable

El núcleo del transporte SHALL ser `async throws` sobre una sesión inyectable (`URLSession`/`URLProtocol`), y cada fallo MUST categorizarse en un tipo de error tipado (rateLimited, authInvalid, network, decoding, unknown) con el `OSStatus`/underlying error preservado para logging.

#### Scenario: Test de rate limit con URLProtocol mock

- **WHEN** el mock responde 429 + `Retry-After: 2` y luego éxito
- **THEN** un test unitario verifica que hubo exactamente 2 requests y que el segundo fue exitoso

#### Scenario: Test de token inválido

- **WHEN** el mock responde `{"ok": false, "error": "invalid_auth"}`
- **THEN** el error categorizado es `.authInvalid` y el servicio marca la conexión como inválida

### Requirement: La fachada SlackService conserva su API pública

`SlackService` SHALL seguir exponiendo `setStatus`, `clearStatus`, `testConnection`, `validateToken`, `isEnabled` y la conformancia `PresenceSlackServicing`, sin cambios en firmas ni en semántica observable, después de la extracción de capas.

#### Scenario: Consumers existentes sin modificación

- **WHEN** se compila el repo completo tras el refactor
- **THEN** `PresenceCoordinator.swift`, `FocusIntegrationService.swift` y las 8 vistas que usan `SlackService` compilan sin cambios de firma

### Requirement: Keychain usa update-or-add con errores visibles

`KeychainHelper` SHALL intentar `SecItemUpdate` sobre un ítem existente antes de hacer `SecItemAdd`, SHALL devolver el `OSStatus` de la operación (o lanzar), y MUST loguear los fallos con `os.log` en lugar de `print`.

#### Scenario: Guardado repetido del token

- **WHEN** se guarda el token Slack dos veces seguidas
- **THEN** la segunda operación ejecuta `SecItemUpdate` (no delete+add) y preserva la identidad del ítem

#### Scenario: Fallo de keychain es diagnosticable

- **WHEN** `SecItemUpdate`/`SecItemAdd` devuelve error (p. ej. `errSecInteractionNotAllowed`)
- **THEN** el error aparece en unified logging con el código OSStatus y el método que lo originó
