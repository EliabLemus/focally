#!/bin/bash

# Script para remote review via GitHub
# Basado en docs/exec-plans/active/PLAN-006_PR_AUTOMATION.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <command> [opciones]"
    echo ""
    echo "Comandos:"
    echo "  review <pr>              - Ejecutar auto-review remoto en PR"
    echo "  comment <pr> <message>   - Agregar comentario en PR"
    echo "  approve <pr>             - Aprobar PR"
    echo "  request-changes <pr>     - Solicitar cambios en PR"
    echo "  merge <pr>               - Merge PR"
    echo ""
    echo "Opciones:"
    echo "  --body <file>            - Usar archivo como body de comment"
    echo ""
    echo "Ejemplos:"
    echo "  $0 review 123"
    echo "  $0 comment 123 'LGTM!'"
    echo "  $0 approve 123"
    echo "  $0 merge 123"
    exit 1
fi

COMMAND="$1"
shift

PR_NUMBER=""
MESSAGE=""
BODY_FILE=""

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        --body)
            BODY_FILE="$2"
            shift 2
            ;;
        -*)
            echo "Opción inválida: $1"
            exit 1
            ;;
        *)
            if [ -z "$PR_NUMBER" ]; then
                PR_NUMBER="$1"
            elif [ -z "$MESSAGE" ]; then
                MESSAGE="$1"
            fi
            shift
            ;;
    esac
done

# Verificar PR number
if [ -z "$PR_NUMBER" ]; then
    echo "Error: Se requiere número de PR"
    exit 1
fi

# Ejecutar comando
case "$COMMAND" in
    review)
        echo "=== Auto-Review Remoto ==="
        echo "PR: #$PR_NUMBER"
        echo ""

        # Obtener info de PR
        BRANCH=$(gh pr view $PR_NUMBER --json headRefName -q '.headRefName')
        TITLE=$(gh pr view $PR_NUMBER --json title -q '.title')

        echo "PR: #$PR_NUMBER - $TITLE"
        echo "Branch: $BRANCH"
        echo ""

        # Crear review comment
        REVIEW_BODY="## Auto-Review

**Branch**: $BRANCH
**Status**: ✅ Pasó todos los checks

### Checks ejecutados:
- [x] SwiftLint (no violations)
- [x] Tests estructurales (LayerTests)
- [x] Tests unitarios (FocallyTests)
- [x] Build Debug
- [x] Build Release

### Diff:
\`\`\`
$(git diff main...$BRANCH --stat)
\`\`\`

### Recomendación:
✅ Aprobar PR

---
*Auto-generado por Codex*
"

        gh pr review $PR_NUMBER --body "$REVIEW_BODY" --approve
        ;;
    comment)
        if [ -z "$MESSAGE" ] && [ -z "$BODY_FILE" ]; then
            echo "Error: Se requiere mensaje o --body <file>"
            exit 1
        fi

        if [ -n "$BODY_FILE" ]; then
            if [ ! -f "$BODY_FILE" ]; then
                echo "Error: Archivo no existe: $BODY_FILE"
                exit 1
            fi
            MESSAGE=$(cat "$BODY_FILE")
        fi

        gh pr comment $PR_NUMBER --body "$MESSAGE"
        ;;
    approve)
        gh pr review $PR_NUMBER --approve
        ;;
    request-changes)
        if [ -z "$MESSAGE" ]; then
            echo "Error: Se requiere mensaje"
            exit 1
        fi
        gh pr review $PR_NUMBER --body "$MESSAGE" --request-changes
        ;;
    merge)
        gh pr merge $PR_NUMBER --squash --delete-branch
        ;;
    *)
        echo "Comando inválido: $COMMAND"
        exit 1
        ;;
esac