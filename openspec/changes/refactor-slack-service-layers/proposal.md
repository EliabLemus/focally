# Proposal: refactor-slack-service-layers

## Intent

`SlackService.swift` es un dios-objeto de 3,371 líneas que mezcla HTTP, estado de conexión, rate limiting (solo para `emoji.list`), validación de tokens y ~2,500 líneas de catálogos de emoji. El riesgo funcional más grave: `setStatus`/`clearStatus` no respetan 429/`Retry-After` (documentación oficial de Slack: https://docs.slack.dev/apis/web-api/rate-limits/), por lo que los reintentos del ciclo de estado pueden bloquear el token del usuario. Este change separa el archivo en capas con responsabilidades únicas **sin cambiar comportamiento observable**, adoptando solo la disciplina de inyección de dependencias que ya usa el resto del repo (patrón `PresenceSlackServicing`).

## What Changes

- Extraer de `SlackService.swift` tres tipos nuevos:
  - `SlackEmojiCatalog` — tablas estáticas de shortcode↔unicode, `EmojiValidator` y fuzzy search (sin red).
  - `SlackAPIClient` — todo el transporte HTTP (`performSlackRequest`), con rate limiting **por método**: respetar 429 + `Retry-After` en TODAS las rutas (`users.profile.set` incluido), no solo `emoji.list`.
  - `SlackStatusService` — lógica de estado de conexión, `setStatus`/`clearStatus`/`testConnection`/`validateToken`, delegando transporte en `SlackAPIClient`.
- `SlackService` queda como fachada observable que conserva su API pública (nil breaking change para las 8 vistas y servicios que lo consumen).
- Migrar el núcleo HTTP a `async/await` con puentes `withCheckedContinuation` temporales para los callers callback-based existentes.
- `KeychainHelper` pasa de delete+add a find→update→else add, devuelve `OSStatus` y loguea con `os.log` (ya existe `Observability/Logger.swift`).

**BREAKING: ninguno** — API pública de `SlackService` intacta; todo interno o tipo nuevo.

## Capabilities

- **Nueva:** `slack-api` (cliente HTTP con rate limiting por método)
- **Modificada:** ninguna (el comportamiento observable de Slack status no cambia)

## Impact

- `Sources/Focally/Services/SlackService.swift` (3,371 → ~400 líneas de fachada)
- `Sources/Focally/Services/SlackEmojiCatalog.swift` (nuevo, ~2,500 líneas movidas)
- `Sources/Focally/Services/SlackAPIClient.swift` (nuevo)
- `Sources/Focally/Services/SlackStatusService.swift` (nuevo)
- `Sources/Focally/Services/KeychainHelper.swift` (delete+add → update-or-add)
- `Sources/Focally/Services/FocusIntegrationService.swift` (solo si adopta async; opcional)
- Tests nuevos: `Tests/FocallyTests/SlackAPIClientTests.swift` con `URLProtocol` mock (429/Retry-After, token inválido, timeout)
