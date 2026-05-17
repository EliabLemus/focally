#!/bin/bash

# Script para limpiar worktrees
# Basado en docs/exec-plans/active/PLAN-005_WORKTREE_WORKFLOW.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <command> [branch]"
    echo ""
    echo "Comandos:"
    echo "  list                    - Listar todos los worktrees"
    echo "  remove <branch>         - Remover worktree específico"
    echo "  remove-merged           - Remover worktrees mergeados"
    echo "  remove-closed <pr>      - Remover worktree de PR cerrada"
    echo "  prune                   - Remover worktrees de branches eliminadas"
    echo "  clean-all               - Remover todos los worktrees"
    echo ""
    echo "Ejemplos:"
    echo "  $0 list"
    echo "  $0 remove feature/quick-sessions"
    echo "  $0 remove-merged"
    echo "  $0 remove-closed 123"
    echo "  $0 prune"
    echo "  $0 clean-all"
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    list)
        echo "Worktrees:"
        git worktree list
        ;;
    remove)
        if [ $# -eq 0 ]; then
            echo "Error: Se requiere branch"
            exit 1
        fi
        BRANCH="$1"
        WORKTREE_PATH="$PWD/.worktree/$BRANCH"
        if [ -d "$WORKTREE_PATH" ]; then
            echo "Removiendo worktree: $WORKTREE_PATH"
            git worktree remove "$WORKTREE_PATH" -f
            rm -rf "$WORKTREE_PATH"
            echo "Worktree removido"
        else
            echo "Error: Worktree no existe: $WORKTREE_PATH"
            exit 1
        fi
        ;;
    remove-merged)
        echo "Removiendo worktrees mergeados..."
        # Obtener lista de branches mergeadas
        MERGED_BRANCHES=$(git branch --merged main | grep -v "main" | sed 's/^[ \t]*//')

        if [ -z "$MERGED_BRANCHES" ]; then
            echo "No hay branches mergeadas"
            exit 0
        fi

        for BRANCH in $MERGED_BRANCHES; do
            WORKTREE_PATH="$PWD/.worktree/$BRANCH"
            if [ -d "$WORKTREE_PATH" ]; then
                echo "Removiendo worktree mergeado: $BRANCH"
                git worktree remove "$WORKTREE_PATH" -f
                rm -rf "$WORKTREE_PATH"
            fi
        done
        echo "Worktrees mergeados removidos"
        ;;
    remove-closed)
        if [ $# -eq 0 ]; then
            echo "Error: Se requiere número de PR"
            exit 1
        fi
        PR_NUMBER="$1"
        # Obtener branch de PR
        BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName -q '.headRefName')

        if [ -z "$BRANCH" ]; then
            echo "Error: No se pudo obtener branch de PR #$PR_NUMBER"
            exit 1
        fi

        WORKTREE_PATH="$PWD/.worktree/$BRANCH"
        if [ -d "$WORKTREE_PATH" ]; then
            echo "Removiendo worktree de PR #$PR_NUMBER ($BRANCH): $WORKTREE_PATH"
            git worktree remove "$WORKTREE_PATH" -f
            rm -rf "$WORKTREE_PATH"
            echo "Worktree removido"
        else
            echo "Worktree no existe para branch: $BRANCH"
        fi
        ;;
    prune)
        echo "Removiendo worktrees de branches eliminadas..."
        # Obtener lista de worktrees
        WORKTREES=$(git worktree list | grep -v "\[main\]" | awk '{print $1}')

        for WORKTREE in $WORKTREES; do
            # Obtener branch del worktree
            BRANCH=$(git -C "$WORKTREE" branch --show-current)

            # Verificar si branch existe en remoto
            if ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" && [ "$BRANCH" != "main" ]; then
                echo "Removiendo worktree de branch eliminada: $BRANCH"
                git worktree remove "$WORKTREE" -f
                rm -rf "$WORKTREE"
            fi
        done
        echo "Worktrees de branches eliminadas removidos"
        ;;
    clean-all)
        echo "Removiendo todos los worktrees..."
        git worktree remove --force
        rm -rf .worktree
        echo "Todos los worktrees removidos"
        ;;
    *)
        echo "Comando inválido: $COMMAND"
        exit 1
        ;;
esac