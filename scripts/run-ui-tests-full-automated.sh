#!/bin/bash
# Script automatizado completo para ejecutar UI tests en nexus
# Usa Xcode GUI automation vía AppleScript

set -e

cd "$(dirname "$0")/.."

PROJECT_DIR="$(pwd)"
XCODE_PROJECT="Focally.xcodeproj"
SCHEME="FocallyUITests"
RESULTS_DIR="$PROJECT_DIR/build/test-results"
XCRESULT_FILE="$RESULTS_DIR/FocallyUITests.xcresult"

echo "🚀 Ejecutando UI Tests de Focally en nexus (Mac mini M4)"
echo "📁 Directorio: $PROJECT_DIR"
echo ""

# Crear directorio de resultados
mkdir -p "$RESULTS_DIR"

# Script de AppleScript mejorado para ejecutar tests y capturar resultados
osascript <<EOF
tell application "Xcode"
    activate
    delay 2

    -- Abrir el proyecto
    open "$PROJECT_DIR/$XCODE_PROJECT"
    delay 3

    -- Seleccionar el scheme FocallyUITests
    tell application "System Events"
        tell process "Xcode"
            delay 1

            -- Ir al menu de schemes (Cmd + Shift + <)
            try
                key code 42 using {command down, shift down}
                delay 1

                -- Seleccionar FocallyUITests desde el menu
                key code 125 -- Down arrow varias veces hasta encontrar FocallyUITests
                delay 0.2
                key code 125
                delay 0.2
                key code 125
                delay 0.2
                key code 125
                delay 0.2
                key code 125
                delay 0.2
                key code 36 -- Enter

                delay 2
            on error
                log "No se pudo cambiar el scheme, usando el actual"
            end try

            -- Ejecutar tests (Cmd + U)
            key code 32 using {command down}
        end tell
    end tell

    -- Esperar a que los tests terminen (esperar 40 segundos)
    delay 40

    -- Cerrar Xcode después de ejecutar tests
    quit
end tell
EOF

echo ""
echo "⏱️  Tests ejecutados automáticamente..."
echo "📊 Buscando resultados de tests..."

# Buscar el xcresult más reciente
LATEST_XCRESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" -type d -mtime -1 | head -1)

if [ -n "$LATEST_XCRESULT" ]; then
    echo "✅ Results bundle encontrado: $LATEST_XCRESULT"
    echo ""

    # Copiar al directorio del proyecto
    cp -r "$LATEST_XCRESULT" "$XCRESULT_FILE"
    echo "✅ Resultados copiados a: $XCRESULT_FILE"
    echo ""

    # Extraer resumen de resultados usando xcrun
    echo "📋 Resumen de tests:"
    xcrun xcresulttool get --path "$XCRESULT_FILE" --format json | python3 -m json.tool 2>/dev/null | grep -A 5 -B 5 "\"testName\"" | head -40 || echo "⚠️  No se pudo extraer resumen en JSON"

    echo ""
    echo "📊 Resultados:"
    echo "   Ver detalles completos en Xcode: File -> Open -> $XCRESULT_FILE"
else
    echo "⚠️  No se encontraron resultados de tests"
fi

echo ""
echo "✅ Ejecución de UI tests completada"
echo ""
echo "🎯 Para ver los resultados:"
echo "   open $XCRESULT_FILE"
echo "   o usa: xcrun xcresulttool get --path $XCRESULT_FILE --format json"
