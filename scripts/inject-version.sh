#!/bin/bash
set -euo pipefail

# Post-build script to inject version into Info.plist
# Reads version from git tag (passed as argument) or falls back to project.yml

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-}"

# If no version passed, try git tag
if [ -z "$VERSION" ]; then
    VERSION=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")
fi

# Strip 'v' prefix if present
MARKETING_VERSION="${VERSION#v}"

# Fall back to project.yml if no tag found
if [ -z "$MARKETING_VERSION" ]; then
    MARKETING_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/project.yml" | awk -F'"' '{print $2}')
fi

CURRENT_VERSION=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_DIR/project.yml" | awk '{print $2}')

echo "📝 Injecting version info into app bundles..."
echo "   Version: $MARKETING_VERSION"
echo "   Build: $CURRENT_VERSION"

# Find all .app bundles in DerivedData
BUILD_DIR="$PROJECT_DIR/build"
APPS=$(find "$BUILD_DIR/DerivedData" -name "*.app" -type d 2>/dev/null || true)

for APP in $APPS; do
    if [ -d "$APP/Contents" ]; then
        INFO_PLIST="$APP/Contents/Info.plist"

        if [ -f "$INFO_PLIST" ]; then
            echo "   ✏️  Updating $APP"

            if ! plutil -extract CFBundleShortVersionString xml1 -o - "$INFO_PLIST" >/dev/null 2>&1; then
                echo "      Adding CFBundleShortVersionString"
                plutil -insert CFBundleShortVersionString -string "$MARKETING_VERSION" "$INFO_PLIST"
            else
                echo "      Updating CFBundleShortVersionString → $MARKETING_VERSION"
                plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$INFO_PLIST"
            fi

            if ! plutil -extract CFBundleVersion xml1 -o - "$INFO_PLIST" >/dev/null 2>&1; then
                echo "      Adding CFBundleVersion"
                plutil -insert CFBundleVersion -string "$CURRENT_VERSION" "$INFO_PLIST"
            else
                echo "      Updating CFBundleVersion → $CURRENT_VERSION"
                plutil -replace CFBundleVersion -string "$CURRENT_VERSION" "$INFO_PLIST"
            fi

            echo "      ✅ Done"
        fi
    fi
done

echo ""
echo "✅ Version injection complete!"
