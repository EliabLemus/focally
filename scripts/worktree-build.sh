#!/bin/bash

# Script para build en worktree
# Basado en docs/exec-plans/active/PLAN-005_WORKTREE_WORKFLOW.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <branch> [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --configuration CONFIG    - Debug (default) o Release"
    echo "  --clean                  - Clean build"
    echo "  --test                   - Ejecutar tests después del build"
    echo ""
    echo "Ejemplos:"
    echo "  $0 feature/quick-sessions"
    echo "  $0 feature/quick-sessions --configuration Release"
    echo "  $0 hotfix/dnd-fix --clean --test"
    exit 1
fi

BRANCH="$1"
shift

CONFIGURATION="Debug"
CLEAN_BUILD=false
RUN_TESTS=false

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Verificar que el worktree existe
WORKTREE_PATH="$PWD/.worktree/$BRANCH"
if [ ! -d "$WORKTREE_PATH" ]; then
    echo "Error: Worktree no existe: $WORKTREE_PATH"
    echo "Crea el worktree primero: ./scripts/worktree-create.sh $BRANCH"
    exit 1
fi

# Build en worktree
echo "Building en worktree: $WORKTREE_PATH"
echo "Configuration: $CONFIGURATION"

cd "$WORKTREE_PATH"

if [ "$CLEAN_BUILD" = true ]; then
    echo "Limpiando build..."
    xcodebuild clean -project Focally.xcodeproj -scheme Focally
fi

BUILD_CMD="xcodebuild -project Focally.xcodeproj -scheme Focally -configuration $CONFIGURATION build"

if [ "$RUN_TESTS" = true ]; then
    echo "Construyendo y ejecutando tests..."
    BUILD_CMD="xcodebuild -project Focally.xcodeproj -scheme Focally -configuration $CONFIGURATION -destination 'platform=macOS' test"
fi

# Ejecutar build
echo "Ejecutando: $BUILD_CMD"
eval $BUILD_CMD

echo ""
echo "Build completado en worktree: $WORKTREE_PATH"
echo "Build products: ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/$CONFIGURATION/"