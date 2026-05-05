#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Running Focally Unit Tests..."

# Build tests
echo "Building tests..."
xcodebuild build \
    -project Focally.xcodeproj \
    -scheme Focally \
    -destination 'platform=macOS' \
    -configuration Debug \
    ONLY_ACTIVE_ARCH=NO

# Build test bundle
echo "Building test bundle..."
xcodebuild build \
    -project Focally.xcodeproj \
    -target FocallyTests \
    -destination 'generic/platform=macOS' \
    -configuration Debug \
    ONLY_ACTIVE_ARCH=NO

# Run tests
echo "Running tests..."
xcrun xctest \
    -XCTest All \
    build/Debug/Focally.app/Contents/PlugIns/FocallyTests.xctest

echo "✅ All tests passed!"
