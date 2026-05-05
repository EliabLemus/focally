#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Ejecutando Tests Unitarios de Focally (XCTest)..."

# Ejecutar tests con xctest
xcrun xctest build/Debug/Focally.app/Contents/PlugIns/FocallyTests.xctest 2>&1

echo ""
echo "✅ Ejecución completada!"
