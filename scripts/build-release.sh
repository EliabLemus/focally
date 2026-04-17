#!/bin/bash
set -euo pipefail

# Build script for Focally
# Usage: ./scripts/build-release.sh
# Output: build/Focally.dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Focally"
ARCHIVE_NAME="$APP_NAME"
VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo '0.0.0')}"

echo "🔧 Building Focally v$VERSION..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Generate Xcode project
cd "$PROJECT_DIR"
xcodegen generate 2>&1 | tail -1

# Build Release
echo "📦 Building Release..."
xcodebuild build \
    -project "$PROJECT_DIR/Focally.xcodeproj" \
    -scheme Focally \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E '(BUILD|error:)' | tail -5

# Find the .app
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed: .app not found"
    exit 1
fi

echo "✅ Built: $APP_PATH"

# Create DMG
echo "💿 Creating DMG..."
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"
STAGING="$BUILD_DIR/dmg-staging"

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

# Create DMG with hdiutil
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" \
    2>&1 | tail -3

# Clean staging
rm -rf "$STAGING"

echo ""
echo "✅ Done!"
echo "📦 DMG: $DMG_PATH"
echo "🏷️ Version: $VERSION"
ls -lh "$DMG_PATH"
