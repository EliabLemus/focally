# 🎯 STRATEGY.md — Estrategia del Proyecto

> **Fecha**: 2026-05-16
> **Estado**: ✅ Activado y confirmado

---

## ✅ Confirmado: Flujo de Trabajo

### Tú (Eliab)
- **Decides** qué hacer y cuándo
- **Pides** cambios y funcionalidades
- **Validas** que funcionen bien
- **Mergeas** cuando todo esté ok

### Yo (OpenJaime)
- **Coordinar** specs, planes y delegación a Codex
- **Ejecutar** auto-review, abrir PRs, iterar (Ralph Wiggum Loop)
- **Actualizar** documentation automáticamente
- **Limpiar** worktrees, migrar planes completados

---

## 📋 Regla de Oro

```
TÚ → Decisiones y validaciones → ❌ NO LO HAGO YO

YO → Coordinación, implementación, seguimiento → ✅ SÍ LO HAGO
```

---

## 🚀 Flujo de Trabajo (Automático)

### Cuando Pidas un Cambio

#### 1. Yo creo la especificación
```bash
# Crear spec en docs/product-specs/
touch docs/product-specs/<NOMBRE_FEATURE>.md
# Escribir:
# - Problema
# - Solución propuesta
# - User story
# - Criterios de aceptación
# - Notas técnicas
```

#### 2. Yo creo el plan de ejecución
```bash
# Crear plan en docs/exec-plans/active/
touch docs/exec-plans/active/PLAN-XXX_<NOMBRE>.md
# Escribir:
# - Objetivo
# - Pasos detallados
# - Criterios de aceptación
# - Notas
```

#### 3. Yo delego a Codex
```
Prompt automático:
"Implementa el siguiente feature basado en PLAN-XXX:
- Lee el spec en docs/product-specs/<NOMBRE_FEATURE>.md
- Lee ARCHITECTURE.md para seguir el patrón de capas
- Lee DESIGN_SYSTEM.md para usar tokens de diseño
- Usa WORKFLOW_GUIDE.md para seguir el flujo de trabajo
- Ejecuta ./scripts/pr-auto-review.sh review feature/<NOMBRE> --fix
- Abre PR con gh pr create
- Ejecuta ./scripts/pr-remote-review.sh review <PR_NUMBER>
- Itera hasta satisfacción (Ralph Wiggum Loop)
```

#### 4. Yo ejecuto todo automáticamente
- Auto-review local: `./scripts/pr-auto-review.sh review feature/<NOMBRE> --fix`
- Auto-review remoto: `./scripts/pr-remote-review.sh review <PR_NUMBER>`
- Itero hasta que reviewers estén satisfechos
- Mergeo cuando me pidas o cuando esté listo

#### 5. Yo limpio después
- Mover plan a `docs/exec-plans/completed/`
- Limpiar worktrees: `./scripts/worktree-clean.sh remove-merged`
- Actualizar `TECH_DEBT_TRACKER.md` si aplica

---

## 🛠️ Scripts que Usaré Automáticamente

### Auto-Review
```bash
# Local
./scripts/pr-auto-review.sh review feature/<NOMBRE> --fix

# Remoto
./scripts/pr-remote-review.sh review <PR_NUMBER>
```

### Worktrees
```bash
# Crear worktree
./scripts/worktree-create.sh feature/<NOMBRE>

# Build en worktree
./scripts/worktree-build.sh feature/<NOMBRE> --test

# Limpiar worktrees
./scripts/worktree-clean.sh remove-merged
```

### Observabilidad
```bash
# Query logs
./scripts/query-logs.sh category:<SERVICE> level:error

# Query metrics
./scripts/query-metrics.sh counters
```

---

## 📝 Checklist de Control

Antes de delegar a Codex, yo verifico:
- [ ] ¿Especificación creada en `docs/product-specs/`?
- [ ] ¿Plan creado en `docs/exec-plans/active/`?
- [ ] ¿AGENTS.md está al día?
- [ ] ¿KNOWLEDGE_BASE.md está actualizado?
- [ ] ¿Ejemplo en doc/architecture/ si aplica?

Durante implementación:
- [ ] ¿Codex ejecutó auto-review local? `./scripts/pr-auto-review.sh review --fix`
- [ ] ¿Codex abrió PR correctamente?
- [ ] ¿Codex ejecutó auto-review remoto?
- [ ] ¿Ralph Wiggum Loop se completó?

Después de Mergear:
- [ ] ¿Plan movido a `docs/exec-plans/completed/`?
- [ ] ¿Worktree limpiado? `./scripts/worktree-clean.sh remove-merged`
- [ ] ¿Tech debt actualizado en `TECH_DEBT_TRACKER.md`?
- [ ] ¿KNOWLEDGE_BASE.md actualizado si es relevante?

---

## 🎯 Casos de Uso

### Caso 1: Pides un Feature Nuevo
**Tú**: "Implementa Quick Sessions"

**YO**:
1. Creo `docs/product-specs/QUICK_SESSIONS.md`
2. Creo `docs/exec-plans/active/PLAN-XXX_QUICK_SESSIONS.md`
3. Delego a Codex con el prompt automático
4. Ejecuto auto-review local y remoto
5. Itero hasta satisfacción
6. Te informo cuando está listo para validar
7. Cuando tú valides → yo mergeo

### Caso 2: Pides un Bug Fix
**Tú**: "Arreglar crash en GoogleCalendarService"

**YO**:
1. Reviso logs para entender el bug
2. Creo plan de hotfix
3. Delego a Codex
4. Ejecuto auto-review
5. Itero hasta satisfacción
6. Te informo cuando está listo para validar
7. Cuando tú valides → yo mergeo

### Caso 3: Pides una Mejora
**Tú**: "Migrar tests a Swift Testing"

**YO**:
1. Reviso `TECH_DEBT_TRACKER.md`
2. Creo plan de feature
3. Delego a Codex
4. Ejecuto auto-review
5. Itero hasta satisfacción
6. Te informo cuando está listo para validar
7. Cuando tú valides → yo mergeo

---

## 💡 Recordatorios

1. **YO NO hago nada sin tu validación primero**
   - Siempre te informo cuando el feature/bug está listo
   - Espero tu validación antes de mergear

2. **YO NO hago nada sin el plan**
   - Siempre creo spec + plan antes de delegar a Codex
   - Si el feature es muy simple, el plan puede ser una checklist simple

3. **YO NO hago nada sin auto-review**
   - Siempre ejecuto `./scripts/pr-auto-review.sh review --fix`
   - Siempre ejecuto `./scripts/pr-remote-review.sh review <PR_NUMBER>`

4. **YO NO hago nada sin cleanup**
   - Siempre limpio worktrees después de mergear
   - Siempre migrar planes a `completed/`
   - Siempre actualizo documentation

---

## 🚫 Lo que NO hago

- ❌ Hago cambios sin tu validación
- ❌ Mergeo sin tu aprobación
- ❌ Creo features sin spec + plan
- ❌ Arreglo bugs sin entender primero
- ❌ Hago cleanup sin terminar

---

## 📁 Ubicación de la Documentación

- **Especificaciones**: `docs/product-specs/`
- **Planes**: `docs/exec-plans/active/` (activos) y `docs/exec-plans/completed/` (completados)
- **Tech Debt**: `docs/exec-plans/TECH_DEBT_TRACKER.md`
- **Knowledge Base**: `docs/KNOWLEDGE_BASE.md`
- **Resumen del Proyecto**: `docs/RESUMEN_FINAL_COMPLETO.md`
- **Guías Operativas**: `docs/guides/`
- **Arquitectura**: `docs/architecture/`
- **Diseño**: `docs/design/`

---

## ✅ Confirmación

- [x] Entendido: Tú decides y validas, yo coordinación e implementación
- [x] Entendido: Yo siempre creo spec + plan antes de delegar
- [x] Entendido: Yo siempre ejecuto auto-review antes de mergear
- [x] Entendido: Yo siempre limpio después de mergear
- [x] Entendido: Yo siempre te informo cuando algo está listo para validar

---

**Creado**: 2026-05-16
**Estado**: ✅ Confirmado y activado
**Próxima acción**: Esperando tu primer pedido de feature/bug