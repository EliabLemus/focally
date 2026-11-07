# TASK-059 STATUS — refactor-slack-service-layers

- `SlackService.swift` de 3,371 → 804 líneas (fachada con API pública intacta).
- Nuevos: `SlackEmojiCatalog` (tablas + EmojiValidator + EmojiUsageTracker), `SlackError` (tipado), `SlackAPIClient` (transporte async + rate limiting POR MÉTODO con 429/Retry-After en todas las rutas), `SlackStatusService` (setStatus/clearStatus/validateToken/testConnection).
- `KeychainHelper`: SecItemUpdate→else SecItemAdd (antes delete+add), devuelve OSStatus, log con `Logger.slack`; decisión pura `KeychainSaveStrategy` testeable.
- Suite: 105/105 verde (92 baseline + 13 nuevos en 3 suites).

## Desviaciones
- El auto-retry post-deadline existe SOLO en `performAsync` (path async); el gateway callback registra/respeta el gate por método pero NO auto-reintenta — preserva los contratos de completion existentes (SlackOperationStateTests).
- En el test de reintento, el sleeper fake AVANZA el reloj fake: si no, el gate sigue activo tras el sleep instantáneo y el reintento sale por el short-circuit del gateway sin request real (lección: sleeper y `now` fake deben ser consistentes).
- El wrapper propio `Logger` (init privado) obliga a usar estáticos existentes: KeychainHelper usa `Logger.slack`; logs de método del client usan interpolación simple (OSLog privacy no compila con este toolchain).
- La respuesta de Slack no distingue shortcodes inexistentes (users.profile.set los ignora silenciosamente) — sin cambio aquí; ya documentado en TASK-058.
