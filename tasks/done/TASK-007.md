# TASK-007: Apple Skills Toolkit para Focally

## Status
**DONE** (setup completado)

## Date
2026-04-30

## Source
[claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills) — 149 skills para desarrollo Apple, adaptadas para OpenClaw/GLM.

## What was done

Se clonó el repo y se seleccionaron **41 skills** más relevantes para desarrollo de apps macOS/iOS, especialmente Focally. Se limpiaron los frontmatter (removido `allowed-tools` específico de Claude Code) y se copiaron al workspace de OpenClaw.

## Skills instaladas

### Generators (15) — Code gen para features comunes
| Skill | Para qué |
|-------|----------|
| `generators/logging-setup` | Apple Logger infrastructure |
| `generators/settings-screen` | Pantalla de preferencias completa |
| `generators/onboarding-generator` | Flujo de bienvenida multi-step |
| `generators/review-prompt` | Request de review en App Store inteligente |
| `generators/tipkit-generator` | Tips inline/popover con TipKit |
| `generators/feedback-form` | Formulario de feedback in-app |
| `generators/debug-menu` | Menú de debug oculto |
| `generators/feature-flags` | Feature flags locales/remotas |
| `generators/state-restoration` | Restaurar estado de la app |
| `generators/whats-new` | Pantalla "What's New" post-update |
| `generators/usage-insights` | Stats para el usuario |
| `generators/streak-tracker` | Racha diaria con freezes |
| `generators/milestone-celebration` | Confetti/badges/achievements |
| `generators/error-monitoring` | Crash reporting (Sentry/Crashlytics) |
| `generators/ci-cd-setup` | GitHub Actions / Xcode Cloud |

### Product (12) — Spec-driven development
| Skill | Para qué |
|-------|----------|
| `product/implementation-spec` | Orquestador master de specs |
| `product/ux-spec` | Especificaciones UI/UX |
| `product/architecture-spec` | Arquitectura técnica |
| `product/prd-generator` | Product Requirements Document |
| `product/test-spec` | QA y testing strategy |
| `product/release-spec` | Preparación App Store |
| `product/idea-generator` | Brainstorm de ideas de apps |
| `product/product-agent` | Validación de ideas |
| `product/market-research` | Análisis de mercado |
| `product/competitive-analysis` | Análisis competitivo |
| `product/beta-testing` | Estrategia TestFlight |
| `product/localization-strategy` | Estrategia de localización |

### Performance (2)
| Skill | Para qué |
|-------|----------|
| `performance/profiling` | Instruments, hangs, memory, energy |
| `performance/swiftui-debugging` | Debugging específico de SwiftUI |

### App Store (5)
| Skill | Para qué |
|-------|----------|
| `app-store/keyword-optimizer` | ASO keywords |
| `app-store/rejection-handler` | Manejar rechazos de Apple |
| `app-store/review-response-writer` | Responder reviews |
| `app-store/screenshot-planner` | Plan de screenshots |
| `app-store/marketing-strategy` | Estrategia de marketing |

### Otros (7)
| Skill | Para qué |
|-------|----------|
| `security/privacy-manifests` | Privacy manifests y compliance |
| `growth/analytics-interpretation` | Interpretar analytics |
| `growth/indie-business` | Business indie |
| `monetization` | Pricing, tiers, free trials |
| `design/animation-patterns` | Patrones de animación |
| `ios/coding-best-practices` | Best practices (útil para macOS también) |
| `ios/ui-review` | Review de UI contra HIG |

## Skills que ya teníamos (NO duplicadas)
- `liquid-glass` ✅ (ya existía, actualizada con el repo)
- `swift-lang` ✅
- `swiftdata` ✅
- `swiftui-core` ✅
- `swiftui-webkit` ✅
- `charts-3d` ✅
- `testing-swift` ✅
- `macos-menubar` ✅
- `macos-app-structure` ✅
- `macos-distribution` ✅
- `macos-permissions` ✅
- `appkit-bridge` ✅
- `mapkit-geo` ✅
- `foundation-models` ✅
- `app-intents` ✅
- `accessibility` ✅

## Cómo usar con Focally

### Para mejoras de UX/UI
```
"Usa la skill product/ux-spec para diseñar la nueva vista de..."
"Usa design/animation-patterns para mejorar las transiciones"
"Usa ios/ui-review para revisar el menú principal"
```

### Para nuevas features
```
"Usa generators/onboarding-generator para crear un onboarding"
"Usa generators/usage-insights para agregar stats al menú"
"Usa generators/streak-tracker para racha de focus sessions"
```

### Para App Store
```
"Usa app-store/keyword-optimizer para optimizar ASO"
"Usa product/release-spec para preparar el submission"
"Usa app-store/screenshot-planner para las screenshots"
```

### Para specs
```
"Usa product/implementation-spec para generar specs completos"
"Usa product/architecture-spec para rediseñar la arquitectura"
"Usa product/test-spec para plan de testing"
```

## Skills más relevantes para Focally (prioridad)

### Inmediato (v0.4.4+)
1. **`generators/usage-insights`** — Stats de focus sessions para el usuario
2. **`generators/streak-tracker`** — Racha de días enfocado
3. **`design/animation-patterns`** — Animaciones en el menú popup
4. **`performance/swiftui-debugging`** — Debug de UI issues

### Corto plazo (v0.5.x)
5. **`generators/onboarding-generator`** — Onboarding para nuevos usuarios
6. **`generators/tipkit-generator`** — Tips para descubrir features
7. **`generators/whats-new`** — What's new post-update
8. **`generators/feedback-form`** — Feedback in-app

### Mediano plazo
9. **`product/competitive-analysis`** — Analizar competidores de Pomodoro apps
10. **`product/market-research`** — TAM/SAM para Focally
11. **`app-store/*`** — Todo el stack de App Store para distribución

## Notas técnicas
- Las skills son archivos Markdown estáticos — OpenClaw las carga en contexto cuando el modelo detecta que son relevantes
- No requieren instalación especial, solo estar en `~/.openclaw/workspace/skills/`
- Son compatibles con cualquier modelo (GLM-4.7, Claude, GPT, etc.)
- Repo fuente: MIT License
- Algunas skills referencian Claude Code tools específicos (Read, Write, Bash) — ignorar esas referencias, OpenClaw maneja las herramientas automáticamente
