# TASK-058 STATUS — add-call-emoji-customization

- Arc agregado al catálogo: `company.thebrowser` → "Arc" → `:google-meet:` (la llamada de Meet en Arc ya no cae en Unknown Client).
- Overrides de emoji por cliente + override de Unknown Client, persistidos en UserDefaults (diccionario como JSON string).
- Resolución pura: overrides reemplazan solo `.emoji`; matching/displayName code-defined intactos.
- UI: sección "Emoji por app" en Call Detection Settings con picker de búsqueda de shortcodes del workspace; advertencia inline no bloqueante si el shortcode no está en `workspaceEmojiCodes`.
- Suite: 92/92 verde (82 baseline + 10 nuevos en CallClientOverrideTests).

## Desviaciones / notas
- Slack NO distingue en la respuesta de `users.profile.set` si el shortcode existe — el warning de shortcode inexistente es best-effort contra la lista local `workspaceEmojiCodes` (documentado en el spec).
- El warning usa `Logger.callDetection` (categoría CallDetection del wrapper propio en Observability/Logger.swift, init privado) — no `os.Logger` directo ni categoría "call-emoji".
- Los overrides NO agregan prefijos nuevos de apps (matching sigue code-defined); agregar prefijos custom sería otro change.
