#!/bin/bash
# Script automatizado para ejecutar UI tests usando Xcode GUI automation

set -e

cd "$(dirname "$0")/.."

PROJECT_DIR="$(pwd)"
XCODE_PROJECT="Focally.xcodeproj"
SCHEME="FocallyUITests"

echo "🚀 Ejecutando UI Tests de Focally con Xcode GUI automation..."
echo "📁 Directorio: $PROJECT_DIR"
echo ""

# Script de AppleScript para controlar Xcode
osascript <<EOF
tell application "Xcode"
    activate
    delay 2

    -- Abrir el proyecto
    open "$PROJECT_DIR/$XCODE_PROJECT"
    delay 3

    -- Esperar que el proyecto cargue
    delay 2

    -- Ejecutar tests (Cmd + U)
    tell application "System Events"
        tell process "Xcode"
            delay 1
            key code 32 using {command down} -- Cmd + U
        end tell
    end tell

    -- Esperar a que los tests terminen (esperar 30 segundos máximo)
    delay 30

    -- Cerrar Xcode (opcional - descomentar si se desea cerrar)
    -- quit
end tell
EOF

echo ""
echo "⏱️  Esperando ejecución de tests (30 segundos)..."
echo "⚠️  NOTA: Este script inicia Xcode GUI automáticamente"
echo "ℹ️  Puedes monitorear el progreso en la ventana de Xcode"
echo ""

# Esperar un momento para que Xcode se cierre si está configurado para cerrarse
sleep 2

echo "✅ Script de automatización completado"
echo "📊 Verifica los resultados en Xcode para ver si los tests pasaron"
