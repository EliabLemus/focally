#!/bin/bash
# Auto-generated por macos-menubar-xcode
# Build y launch local de Focally menubar app.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCHEME="Focally"
PROJECT="$PROJECT_DIR/Focally.xcodeproj"

echo "🔨 Building $SCHEME..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -quiet

echo "🚀 Launching $SCHEME..."
# Build completado. Ejecutar app directamente (menubar)
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Debug -maxdepth 1 -name 'Focally.app' 2>/dev/null | head -1)

if [ -n "$BUILD_DIR" ]; then
  echo "Found built app at: $BUILD_DIR"
  open -a "$BUILD_DIR"
  echo "✅ App launched successfully!"
else
  echo "⚠️  Built app not found, opening Xcode instead..."
  open -a Xcode "$PROJECT"
fi
