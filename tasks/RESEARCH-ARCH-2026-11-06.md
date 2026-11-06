# Research arquitectura Focally — 2026-11-06 (sesión v0.11.1)
Transcript completo: ~/.hermes/cache/delegation/live/deleg_7550eabe/task-0.log

## P0
1. SlackService dios-objeto 3,371 líneas -> extraer SlackEmojiCatalog / SlackAPIClient / SlackStatusService
2. Rate limiting solo en emoji.list; setStatus NO respeta 429/Retry-After (riesgo de bloqueo de token) -> gate por metodo en cliente
3. KeychainHelper delete+add traga errores con print -> find->update->else add, OSStatus/throwing, os.log
4. DND Layer 1 CFPreferences legacy ignorado en macOS 12+ y auto-verificacion -> Shortcuts primario en 14+, INFocusStatusCenter/Assertions.json para verificar

## P1
5. Ticker UI sin tolerance ni anclaje a segundo (deriva + wakeups) -> tolerance 0.1, derivar de Date
6. 49 try? silenciosos (persistence, FocusMode, shortcuts) -> loguear en cada catch
7. Slack API completion-based -> async/await con continuaciones
8. Calendar: debounce EKEventStoreChanged (~2s), re-sync tras recuperar permiso
9. UserDefaults: 74 usos dispersos -> enum DefaultsKey type-safe

## P2
10. usleep(20ms) en @MainActor del detector -> async/actor de fondo
11. Doble ticker 1Hz -> uno compartido, update solo si cambia string
12. Sin tests de red Slack -> URLProtocolMock (429, token invalido, timeout)
13. SlackService.shared singleton -> inyeccion desde composition root

## Top 3
1. SlackAPIClient con rate limiting global (Retry-After en todos los metodos)
2. DND: Shortcuts primario macOS 14+
3. Ticker unico con tolerance + reconciliacion por reloj
