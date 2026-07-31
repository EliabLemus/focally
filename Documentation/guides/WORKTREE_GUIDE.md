# WORKTREE_GUIDE.md — Guía de Worktrees

---

## ¿Qué es un Worktree?

Un **git worktree** te permite tener múltiples copias de trabajo del mismo repo al mismo tiempo, cada una en su propia branch.

**Para qué sirve en Focally**:
- Build aislado por PR
- Logs ephemerales (cada worktree tiene sus propios logs)
- Desarrollo paralelo sin conflicto
- Testing de cambios sin afectar el worktree principal

---

## Crear Worktree

```bash
# Crear worktree para branch
./scripts/worktree-create.sh feature/quick-sessions

# Crear worktree con base específica
./scripts/worktree-create.sh hotfix/dnd-fix --base main

# Recrear worktree existente (limpiar primero)
./scripts/worktree-create.sh feature/quick-sessions --clean
```

**Ubicación**:
```
Focally/
├── .worktree/
│   ├── feature/quick-sessions/  # Worktree para branch
│   └── hotfix/dnd-fix/          # Worktree para hotfix
```

---

## Build en Worktree

```bash
# Build Debug en worktree
./scripts/worktree-build.sh feature/quick-sessions

# Build Release en worktree
./scripts/worktree-build.sh feature/quick-sessions --configuration Release

# Clean build + tests
./scripts/worktree-build.sh feature/quick-sessions --clean --test
```

**Ubicación de build products**:
```
~/Library/Developer/Xcode/DerivedData/Focally-<HASH>/Build/Products/Debug/
```

---

## Limpiar Worktrees

```bash
# Listar worktrees
./scripts/worktree-clean.sh list

# Remover worktree específico
./scripts/worktree-clean.sh remove feature/quick-sessions

# Remover worktrees mergeados
./scripts/worktree-clean.sh remove-merged

# Remover worktree de PR cerrada
./scripts/worktree-clean.sh remove-closed 123

# Remover worktrees de branches eliminadas
./scripts/worktree-clean.sh prune

# Remover todos los worktrees
./scripts/worktree-clean.sh clean-all
```

---

## Flujo de Trabajo

### Crear PR

```bash
# 1. Crear worktree
./scripts/worktree-create.sh feature/quick-sessions

# 2. Hacer cambios en worktree
cd .worktree/feature/quick-sessions
# ... hacer cambios ...

# 3. Commit y push
git add -A && git commit -m "feat: add quick sessions"
git push -u origin feature/quick-sessions

# 4. Crear PR
gh pr create --title "Add Quick Sessions" --body "Implements PLAN-XXX"

# 5. Build en worktree (opcional)
cd ../..
./scripts/worktree-build.sh feature/quick-sessions --test
```

### Merge PR

```bash
# 1. Merge PR en GitHub
gh pr merge --squash --delete-branch

# 2. Limpiar worktree
./scripts/worktree-clean.sh remove feature/quick-sessions
```

### Branch Eliminada

```bash
# Limpiar worktrees de branches eliminadas
./scripts/worktree-clean.sh prune
```

---

## Logs Ephemerales

Cada worktree tiene sus propios logs ephemerales:

```bash
# Logs en worktree específico
cd .worktree/feature/quick-sessions
./scripts/query-logs.sh category:Timer --follow

# Logs en worktree principal
cd ../..
./scripts/query-logs.sh category:Timer --follow
```

**Ventajas**:
- Logs no se contaminan entre worktrees
- Cada PR tiene su own isolated logs
- Fácil debugging sin interferencia

---

## Troubleshooting

### Worktree ya existe

```bash
# Error: Worktree ya existe
./scripts/worktree-create.sh feature/quick-sessions

# Solución: Limpiar y recrear
./scripts/worktree-create.sh feature/quick-sessions --clean
```

### Worktree corrupto

```bash
# Remover worktree manualmente
git worktree remove .worktree/feature/quick-sessions -f
rm -rf .worktree/feature/quick-sessions

# Recrear
./scripts/worktree-create.sh feature/quick-sessions
```

### Worktree no listado

```bash
# Verificar estado de worktrees
git worktree list

# Limpiar worktrees huérfanos
git worktree prune
```

---

## Integración con CI

El workflow de CI usa worktrees para builds aislados:

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Create Worktree
        run: ./scripts/worktree-create.sh ${{ github.head_ref }}
      - name: Build
        run: ./scripts/worktree-build.sh ${{ github.head_ref }} --test
```

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md) — Flujo de trabajo diario
- [PLAN-005_WORKTREE_WORKFLOW.md](../exec-plans/active/PLAN-005_WORKTREE_WORKFLOW.md) — Plan de worktree workflow