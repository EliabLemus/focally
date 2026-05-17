#!/bin/bash

# Script para crear worktree por PR
# Basado en docs/exec-plans/active/PLAN-005_WORKTREE_WORKFLOW.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <branch> [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --base BASE              - Branch base (default: main)"
    echo "  --clean                  - Limpiar worktree existente si ya existe"
    echo ""
    echo "Ejemplos:"
    echo "  $0 feature/quick-sessions"
    echo "  $0 feature/quick-sessions --base main"
    echo "  $0 hotfix/dnd-fix --clean"
    exit 1
fi

BRANCH="$1"
shift

BASE="main"
CLEAN=false

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        --base)
            BASE="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Verificar que estamos en un repo git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: No estás en un repo git"
    exit 1
fi

# Verificar que la branch base existe
if ! git show-ref --verify --quiet refs/heads/"$BASE"; then
    echo "Error: Branch base '$BASE' no existe"
    exit 1
fi

# Crear nombre de worktree
WORKTREE_NAME=".worktree/$BRANCH"
WORKTREE_PATH="$PWD/$WORKTREE_NAME"

# Limpiar worktree existente si se solicita
if [ -d "$WORKTREE_PATH" ] && [ "$CLEAN" = true ]; then
    echo "Limpiando worktree existente: $WORKTREE_PATH"
    git worktree remove "$WORKTREE_PATH" -f
    rm -rf "$WORKTREE_PATH"
fi

# Crear worktree
if [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree ya existe: $WORKTREE_PATH"
    echo "Para recrear, usa --clean"
    exit 1
fi

echo "Creando worktree para branch '$BRANCH'..."
git worktree add "$WORKTREE_PATH" "$BASE"

# Crear branch nueva si no existe en remoto
if ! git show-ref --verify --quiet refs/heads/"$BRANCH"; then
    echo "Branch '$BRANCH' no existe localmente, creando desde '$BASE'..."
    cd "$WORKTREE_PATH"
    git checkout -b "$BRANCH" origin/"$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
fi

echo "Worktree creado: $WORKTREE_PATH"
echo ""
echo "Para usar el worktree:"
echo "  cd $WORKTREE_PATH"
echo "  xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build"
echo ""
echo "Para limpiar el worktree:"
echo "  git worktree remove $WORKTREE_PATH"
echo "  rm -rf $WORKTREE_PATH"