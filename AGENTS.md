# AGENTS.md — Focally

AGENTS.md es el manual para agentes de codificación de Focally. Este archivo complementa el README y DOCS.md, proporcionando contexto específico para que cualquier agente de codificación (Codex, Cursor, Aider, Zed, etc.) pueda trabajar en el proyecto eficientemente.

---

## Setup

### Environment

```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally

# Required tools
brew install swiftlint swiftformat

# Verify setup
swift --version  # Debe ser 5.9 o superior
xcodebuild -version  # Debe soportar macOS 14.0+
```

### Build Commands

```bash
# Debug build (rápido, para development)
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build

# Release build (para testing de release builds)
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build

# Build con logging detallado
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build | tee build.log

# Build específica target
xcodebuild -project Focally.xcodeproj -scheme Focally -target Focally -configuration Debug build
```

### Run Focally

```bash
# Abrir app desde Xcode
open Focally.xcodeproj

# O usar build directa (requires codesign correcto)
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Debug/Focally.app
```

---

## Code Style

### Swift Version

- **Target**: Swift 5.9 (SWIFT_VERSION: "5.9" en project.yml)
- **Strict Mode**: Habilitado en CI
- **Type Safety**: Preferir type hints explícitos para closures y parámetros

### Naming Conventions

#### Structs/Classes/Enums/Protocols
- **Uso**: Componentes de UI, ViewModels, Services
- **Format**: PascalCase
- **Ejemplos**:
  - `MenuBarDropdownView`
  - `GoogleCalendarService`
  - `FocusTimerService`
  - `CalendarStatusCard`

#### Variables/Properties/Functions
- **Uso**: Instancias de objetos, state, funciones
- **Format**: camelCase
- **Ejemplos**:
  - `currentMeeting: CalendarEvent?`
  - `taskInput: String`
  - `selectedDuration: Int`
  - `startSession()`

#### Private Variables
- **Format**: `private var` SIN prefijo (ej: `private var taskInput = ""`)
- **Mantener**: No agregar `private` con guión bajo (`_taskInput`), usar solo `private`

#### Public Members
- **Format**: Siempre explícito
- **Ejemplos**:
  - `public static let shared: GoogleCalendarService`
  - `var isEnabled: Bool`

#### Constants
- **Format**: PascalCase
- **Ejemplos**:
  - `let enabledDefaultsKey = "google_calendar_enabled"`
  - `let calendarReadonlyScope = "https://www.googleapis.com/auth/calendar.readonly"`

### Closures

#### Capture Self Correctly
```swift
// ✅ Correcto: [weak self] para evitar retain cycles
.self.taskInput = ""
.combine Publishers... .sink { [weak self] result in
    guard let self = self else { return }
    // ...
}

// ❌ Incorrecto: strong self (retain cycle)
.combine Publishers... .sink { result in
    self.taskInput = ""  // Error!
}
```

#### Type Annotations for Closures
```swift
// ✅ Correcto: type hint explícito (recomendado en CI)
.sink { [weak self] (_: Result<Void, Error>) in

// ✅ Opcional: simplificado si no es complejo
.sink { [weak self] _ in

// ❌ Incorrecto: inferencia puede fallar en CI
.sink { result in
```

### SwiftUI Best Practices

#### View Structs
```swift
struct CalendarStatusCard: View {
    // ✅ State properties
    @State private var pulseOuterRing = false

    // ✅ Environment objects (si son compartidos globalmente)
    @EnvironmentObject private var calendarService: GoogleCalendarService

    // ✅ Environment values (para temas, accesibilidad)
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack {
            // ...
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("...")
    }
}
```

#### EnvironmentObject vs ObservedObject
- **@EnvironmentObject**: Solo usar si el servicio es registrado globalmente (singleton)
  - Ej: `GoogleCalendarService`, `FocusTimerService`, `SlackService`
- **@ObservedObject**: Usar en ViewModels locales (cuando hay múltiples instancias)
  - Ej: `QuickSessionsSectionViewModel`

#### StateObject vs State
- **@StateObject**: Cuando el view tiene un solo source of truth que debe persistir
  - Ej: `@StateObject private var viewModel = ViewModel()`
- **@State**: Para variables temporales del view
  - Ej: `@State private var taskInput = ""`

### Comments and Documentation

```swift
// MARK: - Sections (usar para organizar el código)

// MARK: - Body
var body: some View { }

// MARK: - Helper Properties
private var statusTitle: String { }

// MARK: - Actions
private func startSession() { }

// MARK: - Date Extensions (si se usan frecuentemente)

extension Date {
    func formatTime() -> String {
        // ...
    }
}
```

---

## Design System

### Design Tokens

**NO hardcodear colores ni fonts**. Usar tokens de Focally:

#### Colors
```swift
// ✅ Correcto: usar tokens existentes
.foregroundStyle(Color.focallyOnSurface)
.background(Color.focallySurfaceContainerLow)
.border(Color.focallyCardBorder)

// ❌ Incorrecto: hardcodear colores
.foregroundStyle(.white)
.background(Color(red: 0.1, green: 0.1, blue: 0.1))
```

#### Fonts
```swift
// ✅ Correcto: usar tokens
.font(.focallyBodyBold)
.font(.focallyCaption)
.font(.focallyTitleLarge)

// ❌ Incorrecto: hardcodear
.font(.system(size: 14, weight: .semibold))
.font(.body)
```

### Slack-Inspired Status Colors

Si estás implementando estado de calendario estilo Slack:

```swift
// Green (free)
Color(red: 0.13, green: 0.77, blue: 0.37)  // #22C55E

// Red (in meeting)
Color(red: 0.94, green: 0.27, blue: 0.27)  // #EF4444

// Yellow (up next)
Color(red: 0.92, green: 0.76, blue: 0.03)  // #EAB308
```

**NO usar hex strings**. Usar RGB range (0-1) para mantener tokens consistentes.

---

## Architecture Patterns

### Project Structure

```
Focally/
├── Focally/
│   ├── Assets.xcassets/
│   ├── Services/
│   │   ├── GoogleCalendarService.swift        // ObservableObject (singleton)
│   │   ├── FocusTimerService.swift            // ObservableObject (singleton)
│   │   ├── SlackService.swift                 // ObservableObject (singleton)
│   │   ├── DNDService.swift                   // Singleton
│   │   ├── KeychainHelper.swift               // Helper
│   │   ├── AnalyticsService.swift             // Singleton
│   │   └── HistoryService.swift               // Singleton
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarDropdownView.swift      // Main menubar dropdown
│   │   ├── Schedule/
│   │   │   ├── SchedulePage.swift             // View principal de schedule
│   │   │   ├── FocusBlockView.swift           // Card de sesión
│   │   │   └── WeekCalendarView.swift         // Calendar view
│   │   ├── Timer/
│   │   │   └── TimerControlsView.swift        // Controles de timer
│   │   ├── Analytics/
│   │   ├── Tasks/
│   │   ├── Settings/
│   │   └── Shared/
│   │       └── FocusSessionComponents.swift   // Componentes reutilizables
│   ├── Models/
│   │   ├── CalendarEvent.swift                // Model de Google Calendar
│   │   ├── FocusTimerState.swift              // Enum para timer
│   │   └── PredefinedTask.swift               // Model de task predefinido
│   └── Resources/
├── FocallyTests/        // Unit tests
├── FocallyUITests/      // UI tests
├── project.yml          // XcodeGen config
├── README.md            // Para humanos
├── DOCS.md              // Documentación técnica
└── AGENTS.md            // Para agentes (este archivo)
```

### Service Pattern

**Todos los services son ObservableObject singletons:**

```swift
final class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    @Published var isEnabled = false
    @Published var events: [CalendarEvent] = []

    var currentMeeting: CalendarEvent? {
        // Computed property sin state, solo lectura
    }
}
```

**Para usar en views:**
```swift
struct CalendarStatusCard: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService

    var body: some View {
        if calendarService.isEnabled {
            // ...
        }
    }
}
```

**Para inicializar en App:**
```swift
@main
struct OnItFocusApp: App {
    @StateObject private var calendarService = GoogleCalendarService.shared
    @StateObject private var timerService = FocusTimerService.shared
    @StateObject private var slackService = SlackService.shared

    var body: some Scene {
        // ...
    }
}
```

### View Organization

#### Views Principales
- **MenuBarDropdownView**: El dropdown del menubar
- **SchedulePage**: La pantalla principal de schedule
- **TimerControlsView**: Controles de timer activo

#### Views por Area
- **MenuBar/**: Componentes del menubar
- **Schedule/**: Componentes del schedule
- **Timer/**: Componentes del timer
- **Analytics/**: Analytics y charts
- **Tasks/**: Gestión de tasks
- **Settings/**: Configuración

#### Componentes Reutilizables
- **Views/Shared/**: Componentes que se usan en múltiples views
- **FocusSessionComponents.swift**: Selector de emoji, controls de duración, etc.

### Dependency Injection

**Por convención**:
- Services: Inyectados como `@EnvironmentObject` en App y Views que los necesitan
- Helpers: Inyectados como `@Inject` si se usan en múltiples views (si implementas un DI system)
- Configuración: UserDefaults + PreferenceKeys

---

## Testing

### Test Types

#### Unit Tests
- Ubicación: `FocallyTests/`
- Target: FocallyTests (ejecuta en CI)
- Tests existen para:
  - Services lógicos (FocusTimerService)
  - Formateadores
  - Helpers

#### UI Tests
- Ubicación: `FocallyUITests/`
- Target: FocallyUITests
- Tests existen para:
  - Flujos principales (crear sesión, iniciar timer)

### Running Tests

```bash
# Todos los tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'

# Solo unit tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests

# Solo UI tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyUITests

# Tests con output detallado
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -enableCodeCoverage YES
```

### Testing Guidelines

- **Tests deben pasar antes de merge**
- **NO mockear APIs externas** (Slack, Google Calendar)
- **Tests de UI deben ser fast** (no reiniciar app completa si es posible)
- **Tests de Services deben cubrir**: happy paths + edge cases (falta de eventos, eventos en el pasado, etc.)

---

## Release Workflow

### Version Bump

**Version format**: `0.X.Y`

| Tipo de cambio | Example | Increment |
|---------------|---------|-----------|
| Major (breaking change) | v0.8.0 | X+1, Y=0, Z=0 |
| Minor (new feature) | v0.7.16 | X, Y+1, Z=0 |
| Patch (bug fix) | v0.7.15.1 | X, Y, Z+1 |

**Ejemplos**:
- v0.7.15 → v0.7.16 (nueva feature)
- v0.7.15 → v0.7.16.1 (bug fix crítico)

### Steps

```bash
# 1. Code Preparation
cd /Users/openjaime/.openclaw/workspace/projects/focally
git status --short  # Verificar archivos modificados

# 2. Commit todos los cambios
git add -A
git commit -m "feat: descripción del cambio"

# 3. Bump version
vim project.yml
# MARKETING_VERSION: "0.7.15" → "0.7.16"
# CURRENT_PROJECT_VERSION: "30" → "31"

# 4. Commit version bump
git add project.yml
git commit -m "chore: bump version to 0.7.16, build 31"

# 5. Local build verification
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build

# 6. Push a main
git push origin main

# 7. Create tag
git tag v0.7.16 HEAD
git show v0.7.16 --stat  # Verificar que tag apunta al commit correcto
git push origin v0.7.16

# 8. GitHub Actions crea release automáticamente
# Monitorizar en: https://github.com/EliabLemus/focally/actions
# Esperar ~3-5 minutos
```

### Verify Release

**NO declarar el release "done" hasta verificar esto:**

```bash
# 1. Confirmar que GitHub Actions tuvo éxito
gh run list --repo EliabLemus/focally --limit 1
# Debe decir: conclusion: success

# 2. Verificar que la release existe y no es draft
gh release list --repo EliabLemus/focally --limit 1

# 3. Verificar que DMG fue subido
gh release view v0.7.16 --repo EliabLemus/focally --json assets
# Debe haber un asset: Focally-0.7.16-arm64.dmg

# 4. Verificar Homebrew tap actualizado
gh api repos/EliabLemus/homebrew-focally/contents/Casks/focally.rb --jq '.content' | base64 -d | grep -E "(version|sha256)"
# Debe coincidir con la versión del release
```

**Casos de error comunes:**

1. **Build falla en CI pero pasa localmente**:
   - Verificar que agregaste type annotations explícitas en closures
   - Verificar que NO estás hardcodeando colores/fonts

2. **CI usa código antiguo**:
   - Verificar que TODOS los archivos modificados están en el commit
   - Revisar `git show v0.7.16 --stat` para asegurar que tag apunta al commit correcto

3. **Deploy key sin permisos**:
   - Usar `gh` CLI con GitHub PAT en lugar de deploy key

---

## Common Gotchas

### App Groups

- **NO están implementados** en Focally actualmente
- Si necesitas compartir data entre app y extension:
  - Crear `Focally.app` y `Focally Extension.appex` (si aplica)
  - Configurar `app-group-id.focally`
  - Usar `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "...")`

### Code Signing

**Dev (Sign to Run Locally)**:
```bash
# Apple Development cert + automatic code signing
```

**Release**:
- GitHub Actions usa certificados automáticos o certificados app-specific
- **NO hardcodear certificados** en el repo
- No usar certs personalizados en CI (pueden expirar)

### Keychain

**Services**:
- `KeychainHelper.swift` usa `Security.SecItem` (no `KeychainAccess` lib)
- Para guardar tokens sensibles (OAuth tokens, API keys):
  - Usar `KeychainHelper.save(value: token, key: "google_calendar_token")`
  - `KeychainHelper.get(key: "google_calendar_token")`

**Categorías**:
```swift
// KeychainHelper.swift ya define categorías:
private let kKeychainCategoryCalendar = "focally.calendar"
private let kKeychainCategorySlack = "focally.slack"
```

### CloudKit / iCloud

- **NO está implementado** en Focally
- TODO si necesitas sincronización multi-dispositivo

### Slack API

**App-specific tokens**:
- Guardados en Keychain con categoría `focally.slack`
- Token debe tener scope: `chat:write, groups:write, im:write, users:read, users.profile:read`
- Rate limits aplican (150 mensajes por minuto por usuario)

**Verification**:
- Si SlackService falla, revisar logs del app: `Console.app` → Buscar "SlackService"

### Google Calendar API

**OAuth tokens**:
- Guardados en Keychain con categoría `focally.calendar`
- OAuth scopes: `https://www.googleapis.com/auth/calendar.readonly`
- Token refresh automático implementado

**Rate limits**:
- 10,000 queries por día por usuario (OAuth)
- No es un problema para uso personal local

### UserDefaults Keys

**Naming**: `focally.[service].[key]`

```swift
// Ejemplos en GoogleCalendarService:
private let enabledDefaultsKey = "google_calendar_enabled"
private let tokenDefaultsKey = "google_calendar_token"
```

### macOS Version Compatibility

- **Mínimo**: macOS 14.0 (Ventura)
- **Target**: macOS 15.0+ (actual)
- Si usas APIs nuevas (Swift 6, API changes):
  - Agregar `osVersionCheck()` helper para verificar versión
  - Fallbacks para versiones anteriores

### Swift 6 / Concurrency

- **NO está activado aún** en el repo
- En el futuro, habilitar gradualmente:
  - Primero: `Strict concurrency checking`
  - Segundo: `Nonisolated(unsafe)` en casos necesarios
  - Tercero: `Sendable` con `@unchecked` donde sea posible

**Cómo testear**: Crear feature branch con Swift 6 enabled, correr tests, reportar errores.

---

## Dependencies

### Native Frameworks

**Frameworks usados**:
- **SwiftUI**: Native, sin dependencias externas
- **Foundation**: Para Date, Formatter, UserDefaults
- **AppKit**: Solo si necesitas integración con GUI (Desktop en macOS)
- **Combine**: Para RxSwift alternativo
- **CoreData**: NO usado actualmente
- **CoreSpotlight**: NO usado actualmente

### External Libraries

**NO hay dependencias externas** en Focally (package.swift no existe).

**Librerías usadas**:
- **Alamofire**: NO usado en Focally (usado en otros proyectos)
- **KeychainAccess**: NO usado en Focally (usando Security.SecItem directamente)
- **SwiftyJSON**: NO usado
- **YYCache**: NO usado

**Why no dependencies?**
- Apple frameworks son suficientes
- Evita complexities de CocoaPods/Swift Package Manager
- Simplifica builds en CI
- Verifies que Focally sea truly "portable"

### Assets

**No hay assets externos**:
- App Icon: Generado con icon tool
- Sounds: .aiff files local
- Fonts: Inter (system font alternative)

---

## When to Ask for Help

Si el agente se atasca, en este orden:

1. **Revisar este archivo** (AGENTS.md)
   - Verificar que seguiste las convenciones correctas
   - Verificar que estás usando los comandos correctos

2. **Revisar DOCS.md**
   - Documentación técnica del proyecto
   - Arquitectura más profunda

3. **Revisar PROJECT_CONTEXT.md** (si existe)
   - Contexto específico del repo
   - Decisiones de arquitectura

4. **Leer archivos específicos**
   - Services/ → Para entender lógica de negocio
   - Views/ → Para entender patrones de UI
   - Models/ → Para entender estructura de datos

5. **Usar `rg` para buscar patrones existentes**
   - `rg "GoogleCalendarService"` → Ver cómo se usa en views
   - `rg "@EnvironmentObject"` → Ver patrones de inyección
   - `rg "MARK: -"` → Ver organización de código

6. **Usar `git log --oneline`**
   - Ver commits recientes para entender patrón de commits
   - Verificar si hay convenciones específicas

---

## Agent Compatibility

Este archivo sigue la especificación de [AGENTS.md](https://agents.md/). Es compatible con:

- **OpenAI Codex**: Sí
- **Cursor**: Sí
- **Aider**: Configurar en `.aider.conf.yml`: `read: AGENTS.md`
- **Zed**: Sí (project-scoped rules)
- **Warp**: Sí (knowledge/rules)
- **Devin**: Sí
- **GitHub Copilot**: Sí
- **Gemini CLI**: Configurar en `.gemini/settings.json`: `{ "context": { "fileName": "AGENTS.md" } }`

---

## Credits

Este AGENTS.md fue creado siguiendo la especificación de [AGENTS.md](https://agents.md/) (stewarded por Agentic AI Foundation under Linux Foundation).

El formato y convenciones están optimizados para agentes de codificación que usan Swift, SwiftUI, y macOS development.
