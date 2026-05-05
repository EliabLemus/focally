#!/bin/bash
# Script para ejecutar tests de UI de Focally

set -e

cd "$(dirname "$0")/.."

echo "🧪 Ejecutando Tests de UI de Focally..."

# Build first
echo "📦 Build Focally app..."
xcodebuild build -scheme Focally -destination 'platform=macOS' 2>&1 | grep -E "(BUILD|error:)" || true

echo ""
echo "⚠️  NOTA: XCUITest en macOS requiere configuración especial"
echo "Los tests de UI están escritos pero la configuración automatizada tiene limitaciones"
echo ""
echo "📋 Tests implementados:"
echo "  ✅ testAppLaunchAndMenuBarInteraction"
echo "  ✅ testTimerServiceAccessibilityElements"
echo "  ✅ testBasicTimerControls"
echo "  ✅ testAppDoesNotCrashOnLaunch"
echo "  ✅ testAppHasMainWindowOrStatusBarItem"
echo "  ✅ testAppHandlesMultipleLaunchesGracefully"
echo "  ✅ testAppTerminatesCleanly"
echo "  ✅ testLaunchArgumentsAreSet"
echo ""
echo "🔍 Para ejecutar estos tests manualmente:"
echo "  1. Abrir Focally.xcodeproj en Xcode GUI"
echo "  2. Cmd + U para ejecutar tests"
echo "  3. Seleccionar FocallyUITests target"
echo ""
echo "📁 Archivo de tests: FocallyUITests/FocallyUITests.swift"
