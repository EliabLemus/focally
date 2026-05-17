# CONTEXTO DEL PROYECTO — Implementación del Enfoque de OpenAI

> **Fecha**: 2026-05-16
> **Basado en**: "Engineering Systems: Codex en an Agent-Centered World" — OpenAI

---

## Qué Queremos Lograr

Implementar el enfoque de OpenAI en Focally:
- **0% código escrito por humanos**
- **Los humanos guían, los agentes ejecutan**
- **El repositorio es el sistema de conocimiento**
- **Legibilidad del agente = objetivo #1**

---

## Pasos del Plan

| Paso | Descripción | Estado | Fecha | Notas |
|------|-------------|--------|-------|-------|
| 1 | Reestructurar knowledge base de Focally (docs/ con jerarquía clara) | ✅ Completado | 2026-05-16 | Estructura creada, archivos migrados |
| 2 | AGENTS.md瘦身 (convertir a índice de ~100 líneas) | ✅ Completado | 2026-05-16 | AGENTS.md reducido a ~120 líneas |
| 3 | Agregar invariantes arquitectónicos (lints para capas y dependencias) | 🔄 En progreso | 2026-05-16 | PLAN-003 activo |
| 3 | Agregar invariantes arquitectónicos (lints para capas y dependencias) | ⏳ Pendiente | - | LAYER_RULES.md creado, falta implementar lints |
| 4 | Exponer observabilidad (logs estructurados + métricas query-ables) | ⏳ Pendiente | - | |
| 5 | Worktree workflow (script para worktrees por PR) | ⏳ Pendiente | - | |
| 6 | PR automation (auto-review + Ralph Wiggum Loop) | ⏳ Pendiente | - | |

---

## Lo que Ya Se Hizo (Paso 1)

### Estructura de Knowledge Base Creada

```
docs/
├── KNOWLEDGE_BASE.md           # Índice principal del knowledge base
├── architecture/               # Dominio de arquitectura
│   ├── INDEX.md
│   ├── ARCHITECTURE.md         # Mapa de dominios y capas
│   └── LAYER_RULES.md          # Reglas de dependencia (invariantes)
├── design/                     # Dominio de diseño
│   ├── INDEX.md
│   └── DESIGN_SYSTEM.md        # Migrado desde raíz
├── implementation/             # Dominio de implementación
│   └── INDEX.md
├── exec-plans/                 # Planes de ejecución
│   ├── INDEX.md
│   ├── active/
│   │   ├── PLAN-001_KNOWLEDGE_BASE_RESTRUCTURE.md  # ✅ Completado
│   │   └── PLAN-002_AGENTS_MD_REDUCE.md            # 🔄 En progreso
│   └── TECH_DEBT_TRACKER.md    # Tracker de deuda técnica
├── product-specs/              # Especificaciones de producto
│   └── INDEX.md
├── references/                 # Referencias externas
│   └── INDEX.md
└── guides/                     # Guías operativas
    ├── INDEX.md
    ├── RELEASE_GUIDE.md        # Migrado desde docs/
    ├── FOCUS_INTEGRATION_USER_GUIDE.md
    ├── RESEARCH_MACOS_UI_TESTING_ALTERNATIVES.md
    └── PROCEDIMIENTO_RELEASE.md
```

### Archivos Migrados

- `DESIGN.md` → `docs/design/DESIGN_SYSTEM.md`
- `docs/RELEASE_GUIDE.md` → `docs/guides/RELEASE_GUIDE.md`
- `docs/FOCUS_INTEGRATION_USER_GUIDE.md` → `docs/guides/FOCUS_INTEGRATION_USER_GUIDE.md`
- `docs/RESEARCH_MACOS_UI_TESTING_ALTERNATIVES.md` → `docs/guides/RESEARCH_MACOS_UI_TESTING_ALTERNATIVES.md`
- `PROCEDIMIENTO_RELEASE.md` → `docs/guides/PROCEDIMIENTO_RELEASE.md`

### Archivos Nuevos Creados

**Paso 1 (Knowledge Base)**:
- `docs/KNOWLEDGE_BASE.md` — Índice principal del knowledge base
- `docs/architecture/INDEX.md` — Índice de arquitectura
- `docs/architecture/ARCHITECTURE.md` — Mapa de dominios, capas, patrones
- `docs/architecture/LAYER_RULES.md` — Invariantes de dependencia
- `docs/design/INDEX.md` — Índice de diseño
- `docs/implementation/INDEX.md` — Índice de implementación
- `docs/exec-plans/INDEX.md` — Índice de planes de ejecución
- `docs/exec-plans/TECH_DEBT_TRACKER.md` — Tracker de deuda técnica
- `docs/product-specs/INDEX.md` — Índice de specs de producto
- `docs/references/INDEX.md` — Índice de referencias
- `docs/guides/INDEX.md` — Índice de guías operativas

**Paso 2 (AGENTS.md瘦身)**:
- `AGENTS.md` — Reducido a ~120 líneas (índice)
- `docs/architecture/SERVICE_PATTERN.md` — Patrón de servicios
- `docs/architecture/STATE_MANAGEMENT.md` — State management
- `docs/implementation/DEBUGGING_GUIDE.md` — Cómo debuggear
- `docs/implementation/TESTING_GUIDE.md` — Guía de testing
- `docs/references/SWIFT_UI_REFERENCE.md` — Referencia SwiftUI
- `docs/references/APPKIT_REFERENCE.md` — Referencia AppKit
- `docs/references/FOCUS_API_REFERENCE.md` — Referencia Focus API
- `docs/references/SHORTCUTS_REFERENCE.md` — Referencia Shortcuts
- `docs/guides/WORKFLOW_GUIDE.md` — Flujo de trabajo diario
- `docs/exec-plans/completed/PLAN-001_KNOWLEDGE_BASE_RESTRUCTURE.md` — Plan completado
- `docs/exec-plans/completed/PLAN-002_AGENTS_MD_REDUCE.md` — Plan completado

**Paso 3 (Invariantes Arquitectónicos)**:
- `.swiftlint.yml` — Config custom de SwiftLint
- `FocallyTests/LayerTests.swift` — Tests estructurales
- `.github/workflows/ci.yml` — Workflow de CI con SwiftLint
- `docs/exec-plans/active/PLAN-003_ARCHITECTURAL_INVARIANTS.md` — Plan en progreso

### Claves de la Nueva Estructura

1. **Índice principal** (`docs/KNOWLEDGE_BASE.md`) → Mapa del knowledge base
2. **Dominios claros** → architecture, design, implementation, exec-plans, product-specs, references, guides
3. **Archivos existentes migrados** → DESIGN.md, RELEASE_GUIDE.md, etc.
4. **Planes de ejecución** → PLAN-001 completado, PLAN-002 en progreso
5. **Tracker de deuda técnica** → TD-001 a TD-005 identificados

---

## Lo que Falta (Paso 2: AGENTS.md瘦身)

### Objetivo
Reducir AGENTS.md de ~500 líneas a ~100 líneas, convirtiéndolo en un índice.

### Qué Hay que Hacer
1. Leer AGENTS.md actual y mantener solo:
   - Setup (build commands, tools)
   - Quick reference para codificación (code style, naming conventions)
   - Enlaces a docs/ para conocimiento profundo
2. Mover contenido detallado a docs/:
   - Architecture → `docs/architecture/`
   - Design system → `docs/design/DESIGN_SYSTEM.md`
   - Release workflow → `docs/guides/RELEASE_GUIDE.md`
   - Testing → `docs/implementation/TESTING_GUIDE.md`
   - Common gotchas → `docs/implementation/DEBUGGING_GUIDE.md`
3. Verificar que Codex puede trabajar con el nuevo formato

### Plan de Acción
- `PLAN-002_AGENTS_MD_REDUCE.md` ya está creado en `docs/exec-plans/active/`
- Proceder con la reducción de AGENTS.md

---

## Próximos Pasos (Pasos 3-6)

### Paso 3: Invariantes Arquitectónicos
- Ya existe `docs/architecture/LAYER_RULES.md` con invariantes teóricos
- Falta implementar lints mecánicos:
  - SwiftLint config custom
  - Tests estructurales en `FocallyTests/LayerTests.swift`

### Paso 4: Observabilidad
- Implementar structured logging con `os.log`
- Exponer logs/métricas queries-ables por agente
- Integrar con DevTools Protocol para snapshots

### Paso 5: Worktree Workflow
- Script para crear worktrees por PR
- Cada worktree aísla el build y los logs
- Clean-up automático después de merge/close

### Paso 6: PR Automation
- Script para auto-review local
- Ralph Wiggum Loop (iterar hasta que reviewers estén satisfechos)
- Integración con GitHub Actions para remote review

---

## Referencias

- [Artículo de OpenAI](https://openai.com/es-419/index/harness-engineering/)
- [PLAN-001](docs/exec-plans/active/PLAN-001_KNOWLEDGE_BASE_RESTRUCTURE.md)
- [PLAN-002](docs/exec-plans/active/PLAN-002_AGENTS_MD_REDUCE.md)
- [TECH_DEBT_TRACKER](docs/exec-plans/TECH_DEBT_TRACKER.md)