# PR_AUTOMATION_GUIDE.md — Guía de PR Automation

---

## ¿Qué es PR Automation?

**PR Automation** es un sistema para automatizar el review de Pull Requests usando Codex como agente de review.

**Componentes**:
1. **Auto-review local** → Ejecuta checks en tu máquina antes de crear PR
2. **Remote review** → Ejecuta checks en CI y postea comentarios
3. **Ralph Wiggum Loop** → Itera hasta que reviewers estén satisfechos

---

## Auto-Review Local

### Ejecutar review completo

```bash
# Review completo (lints + tests + build)
./scripts/pr-auto-review.sh review feature/quick-sessions

# Review con auto-fix de lints
./scripts/pr-auto-review.sh review feature/quick-sessions --fix
```

### Ejecutar checks individuales

```bash
# Solo lints
./scripts/pr-auto-review.sh lint feature/quick-sessions

# Solo tests
./scripts/pr-auto-review.sh test feature/quick-sessions

# Solo build
./scripts/pr-auto-review.sh build feature/quick-sessions

# Ver diff
./scripts/pr-auto-review.sh diff feature/quick-sessions
```

---

## Remote Review

### Review en PR

```bash
# Ejecutar review remoto y aprobar
./scripts/pr-remote-review.sh review 123
```

Esto postea un comentario en la PR:
```markdown
## Auto-Review

**Branch**: feature/quick-sessions
**Status**: ✅ Pasó todos los checks

### Checks ejecutados:
- [x] SwiftLint (no violations)
- [x] Tests estructurales (LayerTests)
- [x] Tests unitarios (FocallyTests)
- [x] Build Debug
- [x] Build Release

### Recomendación:
✅ Aprobar PR
```

### Comentar en PR

```bash
# Comentario simple
./scripts/pr-remote-review.sh comment 123 "LGTM!"

# Comentario desde archivo
./scripts/pr-remote-review.sh comment 123 --body comment.md
```

### Aprobar/Rechazar PR

```bash
# Aprobar PR
./scripts/pr-remote-review.sh approve 123

# Solicitar cambios
./scripts/pr-remote-review.sh request-changes 123 "Por favor arreglar el crash en CalendarService"

# Merge PR
./scripts/pr-remote-review.sh merge 123
```

---

## Ralph Wiggum Loop

**Ralph Wiggum Loop** es el proceso de iterar hasta que todos los reviewers estén satisfechos.

### Flujo

```
1. Codex abre PR
2. Auto-review local (checks pasan)
3. Remote review (CI checks)
4. Human review (opcional)
5. Si hay comentarios → Codex responde y arregla
6. Repetir hasta satisfacción
7. Merge
```

### Ejemplo con Codex

**Prompt para Codex**:
> "Abre PR para PLAN-XXX. Ejecuta auto-review local. Si hay comentarios en PR, responde y arregla. Itera hasta que reviewers estén satisfechos."

**Codex ejecuta**:
1. Crea feature branch
2. Implementa cambios
3. Ejecuta `./scripts/pr-auto-review.sh review feature/xxx --fix`
4. Abre PR: `gh pr create --title "..." --body "..."`
5. Espera review (auto + humano)
6. Si hay comentarios → responde y arregla
7. Repite 5-6 hasta satisfacción
8. Merge: `gh pr merge --squash --delete-branch`

---

## Integración con CI

El workflow de CI ejecuta auto-review remoto en cada PR:

```yaml
# .github/workflows/ci.yml
jobs:
  review:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Auto-Review
        run: ./scripts/pr-remote-review.sh review ${{ github.event.pull_request.number }}
```

---

## Flujo de Trabajo Completo

### 1. Crear PR con Codex

```bash
# Prompt para Codex:
# "Implementa PLAN-XXX y abre PR. Ejecuta auto-review local. Si hay comentarios, responde y arregla."

# Codex ejecuta:
# 1. git checkout -b feature/xxx
# 2. Implementa cambios
# 3. git add -A && git commit -m "..."
# 4. git push -u origin feature/xxx
# 5. ./scripts/pr-auto-review.sh review feature/xxx --fix
# 6. gh pr create --title "..." --body "..."
# 7. Espera review
# 8. Si hay comentarios → responde y arregla
# 9. Repite 7-8 hasta satisfacción
# 10. gh pr merge --squash --delete-branch
```

### 2. Review Humano (opcional)

```bash
# Revisar PR
gh pr view 123

# Dejar comentario
./scripts/pr-remote-review.sh comment 123 "Por favor agregar tests para el nuevo feature"

# Solicitar cambios
./scripts/pr-remote-review.sh request-changes 123 "Tests faltan"
```

### 3. Codex responde

```bash
# Codex automáticamente:
# 1. Lee comentarios
# 2. Arregla issues
# 3. Ejecuta auto-review
# 4. Push cambios
# 5. Postea comentario: "Fixed issues from review"
```

### 4. Merge

```bash
# Codex mergea automáticamente cuando reviewers están satisfechos
gh pr merge --squash --delete-branch
```

---

## Troubleshooting

### Auto-review falla

```bash
# Ver errores detallados
./scripts/pr-auto-review.sh review feature/xxx --verbose

# Auto-fix lints
./scripts/pr-auto-review.sh review feature/xxx --fix

# Ver diff para entender qué cambió
./scripts/pr-auto-review.sh diff feature/xxx
```

### Remote review falla

```bash
# Ver estado de PR
gh pr view 123

# Ver checks de CI
gh run list --repo EliabLemus/focally --limit 1

# Re-ejecutar review
./scripts/pr-remote-review.sh review 123
```

### Ralph Wiggum Loop no termina

```bash
# Ver comentarios de PR
gh pr view 123 --json comments --jq '.comments[].body'

# Ver quién debe aprobar
gh pr view 123 --json reviewRequests --jq '.reviewRequests[]'

# Agregar comment manual para desbloquear
./scripts/pr-remote-review.sh comment 123 "LGTM, merge when ready"
```

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md) — Flujo de trabajo diario
- [PLAN-006_PR_AUTOMATION.md](../exec-plans/active/PLAN-006_PR_AUTOMATION.md) — Plan de PR automation