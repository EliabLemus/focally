#!/bin/bash
set -euo pipefail

# Focally Release Script
# Validates versions, builds DMG, and prepares GitHub release
# Usage: ./scripts/create-release.sh v0.9.1

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "❌ Error: Version required"
  echo "Usage: $0 <version>"
  echo "Example: $0 v0.9.1"
  exit 1
fi

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Error: Invalid version format (must be v0.9.1)"
  exit 1
fi

VERSION_NUM="${VERSION#v}"

echo "🔍 Focally Release Script - $VERSION_NUM"
echo "=========================================="

# Check if tag exists
if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "❌ Error: Tag $VERSION already exists"
  exit 1
fi

# Check working tree is clean
if ! git diff-index --quiet HEAD --; then
  echo "❌ Error: Working tree not clean. Commit or stash changes."
  exit 1
fi

# Read version from project.yml
MARKETING_VERSION=$(grep "MARKETING_VERSION:" project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
BUILD_VERSION=$(grep "CURRENT_PROJECT_VERSION:" project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')

echo "📋 project.yml version: $MARKETING_VERSION (build $BUILD_VERSION)"

# Verify version matches
if [[ "$MARKETING_VERSION" != "$VERSION_NUM" ]]; then
  echo "❌ Error: project.yml MARKETING_VERSION ($MARKETING_VERSION) does not match requested version ($VERSION_NUM)"
  exit 1
fi

# Generate Xcode project
echo "🏗️  Generating Xcode project..."
xcodegen generate

# Build Release
echo "🔨 Building Release $VERSION..."
xcodebuild -project Focally.xcodeproj \
  -scheme Focally \
  -configuration Release \
  clean build \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

BUILD_EXIT_CODE=$?
if [ $BUILD_EXIT_CODE -ne 0 ]; then
  echo "❌ Build failed with exit code $BUILD_EXIT_CODE"
  exit 1
fi

# Verify Info.plist version
INFOPLIST="./DerivedData/Build/Products/Release/Focally.app/Contents/Info.plist"
PLIST_VERSION=$(plutil -p "$INFOPLIST" | grep "CFBundleShortVersionString" | sed 's/.*"\(.*\)".*/\1/')
PLIST_BUILD=$(plutil -p "$INFOPLIST" | grep "CFBundleVersion" | sed 's/.*"\(.*\)".*/\1/')

echo "📋 Info.plist version: $PLIST_VERSION (build $PLIST_BUILD)"

if [[ "$PLIST_VERSION" != "$VERSION_NUM" ]]; then
  echo "❌ CRITICAL: Info.plist version ($PLIST_VERSION) does not match project.yml ($VERSION_NUM)"
  echo "This is the bug that caused v0.9.0/v0.8.19 mismatch!"
  echo "Fix: Move MARKETING_VERSION to target settings in project.yml"
  exit 1
fi

if [[ "$BUILD_VERSION" != "$PLIST_BUILD" ]]; then
  echo "❌ Error: Info.plist build ($PLIST_BUILD) does not match project.yml ($BUILD_VERSION)"
  exit 1
fi

# Create DMG
echo "📦 Creating DMG..."
APP="./DerivedData/Build/Products/Release/Focally.app"
DMG="./Focally-${VERSION_NUM}.dmg"

hdiutil create -volname "Focally" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  "$DMG"

DMG_SHA256=$(shasum -a 256 "$DMG" | cut -d' ' -f1)

echo "✅ DMG created: $DMG"
echo "🔒 SHA256: $DMG_SHA256"

# Tag the release
echo "🏷️  Creating tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION_NUM"
git push origin "$VERSION"

echo ""
echo "=========================================="
echo "✅ Release $VERSION prepared successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Upload DMG to GitHub release:"
echo "   gh release create $VERSION --title '$VERSION' --notes 'See CHANGELOG.md' '$DMG'"
echo ""
echo "2. Update homebrew-focally:"
echo "   cd /tmp/homebrew-focally"
echo "   # Update version to $VERSION_NUM"
echo "   # Update sha256 to: $DMG_SHA256"
echo "   git commit -m 'focally: update to $VERSION'"
echo "   git push"
echo ""