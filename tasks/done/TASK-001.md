# TASK-001: Google Calendar Read (Iteración 3 — v0.3.0)

## Objetivo
Agregar integración de Google Calendar a Focally para leer eventos del día y detectar conflictos con sesiones de focus.

## Alcance
- Google OAuth flow (Sign in with Google) usando `ASWebAuthenticationSession`
- Token de acceso + refresh token almacenados en Keychain
- Fetch de eventos del día desde Google Calendar API
- Detección de conflictos: warn si hay un meeting durante una sesión de focus
- UI en Settings: toggle Google Calendar, botón Sign In/Sign Out, estado de conexión
- UI en popover del menu bar: indicador visual de próximos eventos/conflictos

## Stack existente (NO cambiar)
- Swift 5.9, macOS 14+, SwiftUI
- XcodeGen (`project.yml`) para generación del proyecto
- KeychainHelper ya existe en `Focally/Services/KeychainHelper.swift`
- AppDelegate en `Focally/OnItFocusApp.swift` — agregar CalendarService como propiedad
- SettingsView en `Focally/Views/SettingsView.swift` — agregar tab/section de Google Calendar
- Entitlements en `Focally/Focally.entitlements`

## Archivos a crear/modificar

### Nuevos
1. **`Focally/Services/GoogleCalendarService.swift`**
   - `ObservableObject` (igual patrón que `SlackService`)
   - Propiedades: `@Published var isEnabled`, `@Published var isSignedIn`, `@Published var events: [CalendarEvent]`, `@Published var connectionError: String?`
   - OAuth flow:
     - Client ID y Client Secret en Keychain (igual patrón que Slack token)
     - `ASWebAuthenticationSession` para auth
     - Intercambiar auth code por tokens (access + refresh) via POST a `https://oauth2.googleapis.com/token`
     - Refresh token cuando expire el access token
   - Calendar API:
     - `fetchTodayEvents()` → GET `https://www.googleapis.com/calendar/v3/calendars/primary/events`
       - `timeMin` = inicio del día (00:00 local)
       - `timeMax` = fin del día (23:59 local)
       - `singleEvents=true`, `orderBy=startTime`
     - Modelo `CalendarEvent`: `id`, `title`, `startTime`, `endTime`, `isAllDay`, `meetLink`
   - `checkConflict(during session: DateInterval) -> CalendarEvent?` — retorna primer evento que overlap con la sesión
   - Auto-refresh tokens: intentar refresh si API devuelve 401, si falla → `isSignedIn = false`

2. **`Focally/Models/CalendarEvent.swift`**
   - Struct `CalendarEvent`: `id: String`, `title: String`, `startTime: Date`, `endTime: Date`, `isAllDay: Bool`, `meetLink: String?`
   - `Identifiable`, `Codable`, `Equatable`
   - Computed: `duration: TimeInterval`, `timeRange: String` (ej: "10:00 – 11:00")

3. **`Focally/Views/CalendarEventsView.swift`**
   - Vista SwiftUI que muestra eventos del día
   - Lista de eventos con hora, título, badge si es conflicto potencial
   - Empty state: "No events today"
   - Pull-to-refresh (o botón) para re-fetch

### Modificar
4. **`Focally/OnItFocusApp.swift`**
   - Agregar `let calendarService = GoogleCalendarService()` en `AppDelegate`
   - Pasar `calendarService` como `EnvironmentObject` a views que lo necesiten
   - En `onSessionStarted()`: llamar `calendarService.checkConflict(...)` y mostrar alerta si hay conflicto
   - En `applicationDidFinishLaunching`: si `calendarService.isEnabled`, auto-fetch eventos del día

5. **`Focally/Views/SettingsView.swift`**
   - Agregar `@EnvironmentObject var calendarService: GoogleCalendarService`
   - En tab "Connections": reemplazar el placeholder "Coming soon" de Google Calendar con:
     - Toggle para habilitar/deshabilitar
     - Botón "Sign in with Google" (abre OAuth) o "Sign Out"
     - Estado: connected/not connected con icono
   - En tab "Secrets": agregar sección Google Calendar con:
     - TextField para Client ID
     - SecureField para Client Secret
     - Link a Google Cloud Console para crear OAuth credentials

6. **`Focally/Focally.entitlements`**
   - Agregar `com.apple.security.network.client = true` (para llamadas HTTP a Google APIs)

7. **`Focally/Views/FocusMenuView.swift`** (si aplica)
   - Agregar indicador de próximos eventos si hay conflictos con sesión activa

8. **`project.yml`**
   - Actualizar `MARKETING_VERSION` a `"0.3.0"`
   - Actualizar `CURRENT_PROJECT_VERSION` a `"3"`

## Google OAuth Configuration
- Scopes: `https://www.googleapis.com/auth/calendar.readonly`
- Redirect URI: `http://localhost` (custom scheme loopback — `ASWebAuthenticationSession` lo maneja)
- Token endpoint: `https://oauth2.googleapis.com/token`
- Auth endpoint: `https://accounts.google.com/o/oauth2/v2/auth`
- Nota: el usuario debe crear un proyecto en Google Cloud Console y obtener Client ID/Secret

## Comportamiento esperado
1. Usuario va a Settings → Secrets → ingresa Google Client ID y Client Secret → Save
2. Settings → Connections → Google Calendar → toggle ON → "Sign in with Google"
3. `ASWebAuthenticationSession` abre navegador de Google → usuario autoriza
4. Token se guarda en Keychain → `isSignedIn = true`
5. App fetchea eventos del día automáticamente
6. Al iniciar una sesión de focus, se verifica si hay conflicto con algún evento
7. Si hay conflicto → alerta/banner: "⚠️ You have a meeting at 10:00 during this focus session"
8. Si token expira → auto-refresh. Si refresh falla → pedir re-auth

## Patrones a seguir
- `SlackService`: patrón ObservableObject, token en Keychain, toggle enable/disable
- `KeychainHelper`: usar `save(key:value:)`, `load(key:)`, `delete(key:)`
- `DNDService`: patrón de servicio simple con métodos públicos
- `SettingsView`: tabs existentes, draft pattern con save button

## Restricciones
- **Read-only**: NO escribir en el calendario (eso es Iteración 4)
- **No dependencias externas**: solo frameworks del sistema (Foundation, SwiftUI, Security)
- **No cambiar** la arquitectura existente (AppDelegate, menu bar, popover)
- **No romper** funcionalidad existente (timer, DND, Slack)
- Error handling: silencioso + estado publicado (no alerts/blocking UI excepto conflicto)

## Testing manual
1. Build limpio: `xcodegen generate && xcodebuild build -scheme Focally -destination 'platform=macOS'`
2. Verificar que no hay errores de compilación
3. Verificar que Settings muestra las nuevas secciones
4. (Sin Google credentials no se puede probar OAuth, pero el build debe pasar)

## Version
- v0.3.0 (Google Calendar Read)

## Result
- Status: done
- Summary: Implemented Google Calendar read integration with OAuth via `ASWebAuthenticationSession`, Keychain-backed client credentials and tokens, daily event fetch, conflict detection on focus session start, Settings UI for connection/secrets, and popover event visibility.
- Modified files:
  - `Focally/Models/CalendarEvent.swift`
  - `Focally/Services/GoogleCalendarService.swift`
  - `Focally/Views/CalendarEventsView.swift`
  - `Focally/OnItFocusApp.swift`
  - `Focally/Views/SettingsView.swift`
  - `Focally/Views/FocusMenuView.swift`
  - `Focally/Focally.entitlements`
  - `project.yml`
  - `Focally.xcodeproj/project.pbxproj`
  - `tasks/TASK-001.md`
- Notes:
  - `xcodegen generate` completed successfully.
  - Build passed with `xcodebuild build -project Focally.xcodeproj -scheme Focally -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/FocallyDerivedData CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`.
  - The spec did not include a pre-existing `Result` section, so it was added at the end of the file.
  - `openclaw system event --text 'Done: Focally v0.3.0 Google Calendar Read implementation' --mode now` was attempted twice and failed due the local OpenClaw gateway closing the loopback WebSocket (`1006 abnormal closure`).
