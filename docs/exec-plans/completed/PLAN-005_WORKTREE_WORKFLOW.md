# PLAN-005: Worktree Workflow

## Estado
✅ completed

## Objetivo
Crear script para worktrees por PR, permitiendo builds aislados y logs ephemerales.

## Pasos
1. [x] Crear script `scripts/worktree-create.sh` (crear worktree por PR)
2. [x] Crear script `scripts/worktree-build.sh` (build en worktree)
3. [x] Crear script `scripts/worktree-clean.sh` (clean-up worktrees)
4. [x] Integrar con workflow de PR (GitHub Actions)
5. [x] Documentar flujo de trabajo en docs/guides/WORKTREE_GUIDE.md

## Criterios de Aceptación
- [x] Script `worktree-create.sh` crea worktree para branch
- [x] Script `worktree-build.sh` build en worktree aislado
- [x] Script `worktree-clean.sh` limpia worktrees mergeados/cerrados
- [x] Integración con PR workflow en CI
- [x] WORKTREE_GUIDE.md documentado

## Notas
Basado en enfoque de OpenAI: "git worktree para instancias aisladas". Cada PR tiene su propio worktree con logs ephemerales.

## Archivos Creados
- `scripts/worktree-create.sh` — Crear worktree
- `scripts/worktree-build.sh` — Build en worktree
- `scripts/worktree-clean.sh` — Limpiar worktrees
- `docs/guides/WORKTREE_GUIDE.md` — Guía de worktrees

## Fecha de Creación
2026-05-16

## Fecha de Completado
2026-05-16