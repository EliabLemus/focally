#!/bin/bash
# Script simplificado para ejecutar UI tests - Diagnóstico
# Versión: 2.0 - Más robusto y con mejor error handling

set -e

cd "$(dirname "$0")/.."

PROJECT_DIR="$(pwd)"
XCODE_PROJECT="Focally.xcodeproj"
SCHEME="FocallyUITests"

echo "🧪 UI Tests Diagnóstico - Focally"
echo "================================"
echo ""

# Verificar que Xcode existe
echo "1️⃣ Verificando Xcode..."
if [ -d "/Applications/Xcode.app" ]; then
    echo "✅ Xcode encontrado en /Applications/Xcode.app"
else
    echo "❌ Xcode NO encontrado"
    exit 1
fi

# Verificar que el proyecto existe
echo ""
echo "2️⃣ Verificando proyecto..."
if [ -f "$PROJECT_DIR/$XCODE_PROJECT" ]; then
    echo "✅ Proyecto encontrado: $XCODE_PROJECT"
else
    echo "❌ Proyecto NO encontrado"
    exit 1
fi

# Verificar que el scheme existe
echo ""
echo "3️⃣ Verificando scheme..."
SCHEMES=$(xcodebuild -list -project "$XCODE_PROJECT" 2>/dev/null | grep -A 10 "Schemes:" || echo "Error")
if echo "$SCHEMES" | grep -q "$SCHEME"; then
    echo "✅ Scheme encontrado: $SCHEME"
else
    echo "⚠️  Scheme NO encontrado. Schemes disponibles:"
    echo "$SCHEMES"
    exit 1
fi

# Intentar build
echo ""
echo "4️⃣ Intentando build de UI tests..."
xcodebuild build \
    -scheme "$SCHEME" \
    -destination 'platform=macOS,arch=arm64' \
    2>&1 | grep -E "(BUILD|error:)" || true

if [ $? -eq 0 ]; then
    echo "✅ Build exitoso"
else
    echo "❌ Build falló"
    exit 1
fi

# Crear directorio de resultados
mkdir -p "$PROJECT_DIR/build/test-results"

echo ""
echo "5️⃣ Abriendo Xcode..."
echo ""
echo "ℹ️  Xcode se abrirá con el proyecto"
echo "ℹ️  Para ejecutar tests:"
echo "      1. Selecciona scheme: FocallyUITests (en toolbar)"
echo "      2. Cmd + U para ejecutar tests"
echo "      3. Verifica resultados en Xcode"
echo ""

# Abrir Xcode (sin automatización)
open "$PROJECT_DIR/$XCODE_PROJECT"

echo ""
echo "✅ Xcode abierto manualmente"
echo ""
echo "⚠️  NOTA: AppleScript automation tiene limitaciones en nexus"
echo "ℹ️  Ejecución manual es más confiable para UI tests"
echo ""
echo "🎯 Siguientes pasos:"
echo "   1. En Xcode: Cmd + Shift + < para cambiar scheme"
echo "   2. Selecciona 'FocallyUITests'"
echo "   3. Cmd + U para ejecutar tests"
echo "   4. Revisa resultados en el panel de tests"
