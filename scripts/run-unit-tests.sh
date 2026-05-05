#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Ejecutando Tests Unitarios de Focally (XCTest)..."
echo ""

# Build y ejecutar tests con xcodebuild
echo "📦 Build y ejecución de tests..."
xcodebuild test \
    -scheme Focally \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:FocallyTests \
    2>&1 | tail -60

echo ""
echo "✅ Ejecución completada!"
