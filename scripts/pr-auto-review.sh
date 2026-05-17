#!/bin/bash

# Script para auto-review local
# Basado en docs/exec-plans/active/PLAN-006_PR_AUTOMATION.md

set -e

# Verificar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <command> [opciones]"
    echo ""
    echo "Comandos:"
    echo "  review <branch>          - Ejecutar auto-review local en branch"
    echo "  lint <branch>            - Ejecutar lints (SwiftLint + tests estructurales)"
    echo "  test <branch>            - Ejecutar tests (unit + UI)"
    echo "  build <branch>           - Ejecutar build (Debug + Release)"
    echo "  diff <branch>            - Verificar diff del PR"
    echo ""
    echo "Opciones:"
    echo "  --fix                    - Auto-fix lints (SwiftLint --fix)"
    echo "  --verbose                - Output detallado"
    echo ""
    echo "Ejemplos:"
    echo "  $0 review feature/quick-sessions"
    echo "  $0 review feature/quick-sessions --fix"
    echo "  $0 lint hotfix/dnd-fix"
    echo "  $0 test feature/quick-sessions"
    exit 1
fi

COMMAND="$1"
shift

BRANCH=""
FIX=false
VERBOSE=false

# Parsear opciones
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Opción inválida: $1"
            exit 1
            ;;
        *)
            if [ -z "$BRANCH" ]; then
                BRANCH="$1"
            fi
            shift
            ;;
    esac
done

# Verificar branch
if [ -z "$BRANCH" ]; then
    echo "Error: Se requiere branch"
    exit 1
fi

# Ejecutar comando
case "$COMMAND" in
    review)
        echo "=== Auto-Review Local ==="
        echo "Branch: $BRANCH"
        echo ""

        # 1. Verificar diff
        echo "1. Verificando diff..."
        git diff main...$BRANCH --stat

        # 2. Lints
        echo ""
        echo "2. Ejecutando lints..."
        if [ "$FIX" = true ]; then
            swiftlint lint --fix --strict
        else
            swiftlint lint --strict
        fi

        # 3. Tests estructurales
        echo ""
        echo "3. Ejecutando tests estructurales..."
        xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests/LayerTests

        # 4. Tests unitarios
        echo ""
        echo "4. Ejecutando tests unitarios..."
        xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests

        # 5. Build
        echo ""
        echo "5. Ejecutando build..."
        xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build

        echo ""
        echo "=== Auto-Review Completado ==="
        echo "Branch: $BRANCH"
        echo "Estado: ✅ Pasó todos los checks"
        ;;
    lint)
        echo "=== Lints ==="
        if [ "$FIX" = true ]; then
            swiftlint lint --fix --strict
        else
            swiftlint lint --strict
        fi

        echo ""
        echo "Tests estructurales..."
        xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests/LayerTests
        ;;
    test)
        echo "=== Tests ==="
        xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'
        ;;
    build)
        echo "=== Build ==="
        echo "Build Debug..."
        xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build

        echo ""
        echo "Build Release..."
        xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build
        ;;
    diff)
        echo "=== Diff ==="
        git diff main...$BRANCH --stat
        echo ""
        git diff main...$BRANCH | head -100
        ;;
    *)
        echo "Comando inválido: $COMMAND"
        exit 1
        ;;
esac