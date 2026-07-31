# WORKFLOW_GUIDE.md — Flujo de Trabajo Diario

---

## Branching Strategy

### main
- **Estado**: Protected, requires PR
- **Contenido**: Solo merges de PRs aprobados
- **CI**: Ejecuta tests + build en cada commit

### feature/XXX
- **Estado**: Developer-owned
- **Contenido**: Work en progreso
- **CI**: Ejecuta tests en cada push

### hotfix/XXX
- **Estado**: Developer-owned
- **Contenido**: Bug fixes urgentes
- **CI**: Ejecuta tests en cada push

---

## Crear Branch

```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally

# Feature branch
git checkout -b feature/quick-sessions

# Hotfix branch
git checkout -b hotfix/dnd-fix
```

---

## Commits

### Commit message format
```bash
# feat: new feature
git commit -m "feat: add quick sessions feature"

# fix: bug fix
git commit -m "fix: resolve DND toggle issue"

# chore: maintenance
git commit -m "chore: bump version to 0.7.16"

# docs: documentation
git commit -m "docs: update AGENTS.md"

# test: tests
git commit -m "test: add unit tests for CalendarService"
```

### Commit frequently
- Commits pequeños y frecuentes
- Un commit = un cambio lógico
- NO hacer commits masivos ("WIP", "fix everything")

---

## Push y PR

```bash
# Push branch
git push -u origin feature/quick-sessions

# Crear PR via gh CLI
gh pr create --title "Add Quick Sessions" --body "Implements PLAN-XXX"

# O crear PR via GitHub web
# https://github.com/EliabLemus/focally/compare
```

---

## PR Checklist

Antes de crear PR:

- [ ] Tests pasan localmente (`xcodebuild test`)
- [ ] Build pasa localmente (`xcodebuild build`)
- [ ] NO hay warnings de SwiftLint
- [ ] NO hay código hardcodeado (colores, fonts)
- [ ] Type hints explícitos en closures
- [ ] Commits son limpios (no "WIP", "fix everything")
- [ ] Spec/plan referenciado (si aplica)

---

## Code Review

### Self-review
Antes de pedir review:
1. Leer diff (`git diff`)
2. Verificar que NO hay código hardcodeado
3. Verificar que tests pasan
4. Verificar que follows AGENTS.md

### Peer review
- Reviewer verifica: functionality, architecture, style
- Reviewer NO hace cambios directos (usa suggestions)
- Reviewer puede pedir cambios antes de approve

### Auto-review (futuro: Paso 6)
- Codex auto-review local
- Ralph Wiggum Loop (iterar hasta satisfacción)
- Ver [PLAN-006](../exec-plans/active/PLAN-006.md) cuando esté disponible

---

## Merge y Cleanup

```bash
# Squash merge (recomendado)
gh pr merge --squash --delete-branch

# O merge commit (si necesitas preservar history)
gh pr merge --merge --delete-branch

# Verificar que main está actualizado
git checkout main
git pull origin main

# Limpiar branches locales
git branch -d feature/quick-sessions
git remote prune origin
```

---

## Troubleshooting

### Merge conflict
```bash
git checkout main
git pull origin main
git checkout feature/quick-sessions
git rebase main
# Resolver conflictos
git rebase --continue
git push -f origin feature/quick-sessions
```

### CI fails pero local pasa
1. Verificar type hints en closures
2. Verificar que NO hay código hardcodeado
3. Verificar macOS version en CI (≥ 14.0)

### Tests flaky
1. Correr tests 3 veces: `for i in {1..3}; do xcodebuild test; done`
2. Si falla inconsistente, es flaky → arreglar antes de continuar

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [RELEASE_GUIDE.md](RELEASE_GUIDE.md) — Release workflow
- [TESTING_GUIDE.md](../implementation/TESTING_GUIDE.md) — Testing guide