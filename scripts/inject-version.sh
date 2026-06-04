#!/bin/bash
set -euo pipefail

# Post-build script to inject version into Info.plist
# This fixes the issue where build variables don't get substituted in release builds

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Read version from project.yml
MARKETING_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/project.yml" | awk -F'"' '{print $2}')
CURRENT_VERSION=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_DIR/project.yml" | awk '{print $2}')

echo "📝 Injecting version info into app bundles..."
echo "   Version: $MARKETING_VERSION"
echo "   Build: $CURRENT_VERSION"

# Find all .app bundles in the project
APPS=$(find "$PROJECT_DIR" -name "*.app" -type d 2>/dev/null || true)

for APP in $APPS; do
    if [ -d "$APP/Contents" ]; then
        INFO_PLIST="$APP/Contents/Info.plist"

        if [ -f "$INFO_PLIST" ]; then
            echo "   ✏️  Updating $APP"

            # Check if keys exist, if not add them
            if ! plutil -extract CFBundleShortVersionString xml1 -o - "$INFO_PLIST" >/dev/null 2>&1; then
                echo "      Adding CFBundleShortVersionString"
                plutil -insert CFBundleShortVersionString -string "$MARKETING_VERSION" "$INFO_PLIST"
            else
                echo "      Updating CFBundleShortVersionString"
                plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$INFO_PLIST"
            fi

            if ! plutil -extract CFBundleVersion xml1 -o - "$INFO_PLIST" >/dev/null 2>&1; then
                echo "      Adding CFBundleVersion"
                plutil -insert CFBundleVersion -string "$CURRENT_VERSION" "$INFO_PLIST"
            else
                echo "      Updating CFBundleVersion"
                plutil -replace CFBundleVersion -string "$CURRENT_VERSION" "$INFO_PLIST"
            fi

            echo "      ✅ Done"
        fi
    fi
done

echo ""
echo "✅ Version injection complete!"