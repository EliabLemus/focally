# AGENTS.md — Focally

Índice para agentes de codificación. Este archivo es un mapa, no un manual. Para conocimiento profundo, ve a [docs/KNOWLEDGE_BASE.md](docs/KNOWLEDGE_BASE.md).

---

## ⚠️ NOTA IMPORTANTE: Estrategia de Trabajo

**ESTRATEGIA ACTIVADA**: 2026-05-16
**Basada en**: "Engineering Systems: Codex in an Agent-Centered World" — OpenAI

### Flujo de Trabajo

**TÚ (Eliab)**:
- Decides qué hacer y cuándo
- Pides cambios y funcionalidades
- Validas que funcionen bien
- Mergeas cuando todo esté ok

**YO (OpenJaime)**:
- Creo especificaciones en `docs/product-specs/`
- Creo planes en `docs/exec-plans/active/`
- Delego a Codex para implementación
- Ejecuto auto-review local: `./scripts/pr-auto-review.sh review --fix`
- Ejecuto auto-review remoto: `./scripts/pr-remote-review.sh review <PR>`
- Itero hasta satisfacción (Ralph Wiggum Loop)
- Limpio worktrees y migrar planes completados
- Te informo cuando algo está listo para validar

### Regla de Oro
```
TÚ → Decisiones y validaciones → ❌ NO LO HAGO YO
YO → Coordinación, implementación, seguimiento → ✅ SÍ LO HAGO
```

### Referencias Clave
- **[docs/STRATEGY.md](docs/STRATEGY.md)**: Estrategia completa del proyecto
- **[docs/KNOWLEDGE_BASE.md](docs/KNOWLEDGE_BASE.md)**: Mapa del knowledge base
- **[docs/RESUMEN_FINAL_COMPLETO.md](docs/RESUMEN_FINAL_COMPLETO.md)**: Resumen de implementación

---

## Setup

```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally

# Required tools
brew install swiftlint swiftformat

# Verify
swift --version  # ≥ 5.9
xcodebuild -version  # ≥ macOS 14.0
```

### Build Commands

```bash
# Debug build
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build

# Release build
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build

# Run
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Debug/Focally.app
```

---

## Quick Reference

### Swift Version
- Target: Swift 5.9
- Type hints explícitos en closures (CI strict mode)

### Naming
- Structs/Classes/Enums: PascalCase (`MenuBarDropdownView`)
- Vars/funcs: camelCase (`taskInput`, `startSession()`)
- Private: `private var` (sin `_` prefix)

### Closures
```swift
// ✅ Correcto: [weak self] + type hint
.sink { [weak self] (_: Result<Void, Error>) in
    guard let self = self else { return }
}
```

### SwiftUI Best Practices
```swift
struct CalendarStatusCard: View {
    @State private var pulseOuterRing = false  // Temporal
    @EnvironmentObject private var calendarService: GoogleCalendarService  // Singleton
    @Environment(\.colorScheme) private var colorScheme  // System

    var body: some View {
        VStack { }
            .accessibilityElement(children: .combine)
    }
}
```

### Design Tokens
```swift
// ✅ Correcto: usar tokens
.foregroundStyle(Color.focallyOnSurface)
.font(.focallyBodyBold)

// ❌ Incorrecto: hardcodear
.foregroundStyle(.white)
.font(.system(size: 14, weight: .semibold))
```

### MARK Comments
```swift
// MARK: - Body
// MARK: - Helper Properties
// MARK: - Actions
```

---

## Architecture

**Regla de oro**: Dependencias solo hacia adelante.

```
Models → Services → ViewModels → Views
                     ↓
                  Providers
```

### Service Pattern
Todos los services son ObservableObject singletons:
```swift
final class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    @Published var isEnabled = false
}
```

### Project Structure
```
Focally/
├── Services/      # ObservableObject singletons
├── Views/         # SwiftUI views por dominio
├── Models/        # Structs puros
└── Resources/     # Assets, fonts
```

**Para detalles**: [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)

---

## Testing

```bash
# Todos los tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'

# Solo unit tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests
```

**Guidelines**:
- Tests deben pasar antes de merge
- NO mockear APIs externas (Slack, Google Calendar)
- Tests de UI deben ser fast

**Para detalles**: [docs/implementation/TESTING_GUIDE.md](docs/implementation/TESTING_GUIDE.md)

---

## Release Workflow

**Version format**: `0.X.Y`

```bash
# 1. Commit cambios
git add -A && git commit -m "feat: descripción"

# 2. Bump version en project.yml
# MARKETING_VERSION: "0.7.15" → "0.7.16"
# CURRENT_PROJECT_VERSION: "30" → "31"

# 3. Commit version bump
git add project.yml && git commit -m "chore: bump version"

# 4. Push + tag
git push origin main
git tag v0.7.16 HEAD && git push origin v0.7.16

# 5. Verificar (esperar 3-5 min)
gh run list --repo EliabLemus/focally --limit 1
gh release view v0.7.16 --repo EliabLemus/focally --json assets
```

**Para detalles**: [docs/guides/RELEASE_GUIDE.md](docs/guides/RELEASE_GUIDE.md)

---

## Common Gotchas

### App Groups
**NO implementados**. Si necesitas sync multi-dispositivo: ver [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)

### Keychain
Usar `KeychainHelper` (Security.SecItem, no lib externa).

### UserDefaults Keys
Naming: `focally.[service].[key]`

### macOS Version
Mínimo: macOS 14.0 (Ventura), Target: macOS 15.0+

### Swift 6
**NO activado aún**. Ver [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) para roadmap.

**Para detalles**: [docs/implementation/DEBUGGING_GUIDE.md](docs/implementation/DEBUGGING_GUIDE.md)

---

## When to Ask for Help

1. **Leer docs/KNOWLEDGE_BASE.md** → Mapa del knowledge base
2. **Leer dominio específico** → docs/architecture/, docs/design/, etc.
3. **Usar `rg`** → Buscar patrones existentes
4. **Leer commits recientes** → `git log --oneline`

---

## Knowledge Base

Para conocimiento profundo:

| Dominio | Índice |
|---------|--------|
| Architecture | [docs/architecture/INDEX.md](docs/architecture/INDEX.md) |
| Design System | [docs/design/INDEX.md](docs/design/INDEX.md) |
| Implementation | [docs/implementation/INDEX.md](docs/implementation/INDEX.md) |
| Execution Plans | [docs/exec-plans/INDEX.md](docs/exec-plans/INDEX.md) |
| Product Specs | [docs/product-specs/INDEX.md](docs/product-specs/INDEX.md) |
| References | [docs/references/INDEX.md](docs/references/INDEX.md) |
| Guides | [docs/guides/INDEX.md](docs/guides/INDEX.md) |

---

## Credits

Basado en la especificación de [AGENTS.md](https://agents.md/) (stewarded por Agentic AI Foundation).

Optimizado para agentes de codificación en Swift + SwiftUI + macOS.