#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🧪 Running Simple Unit Tests..."

# Clean build directory
rm -rf build

# Build with full debug symbols
echo "Building Focally with debug symbols..."
xcodebuild build \
    -project Focally.xcodeproj \
    -scheme Focally \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    ONLY_ACTIVE_ARCH=YES \
    DEBUG_INFORMATION_FORMAT=dwarf \
    ENABLE_TESTABILITY=YES

# Build test bundle
echo "Building test bundle..."
xcodebuild build \
    -project Focally.xcodeproj \
    -target FocallyTests \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    ONLY_ACTIVE_ARCH=YES \
    DEBUG_INFORMATION_FORMAT=dwarf \
    ENABLE_TESTABILITY=YES

# Try to run tests using xctest
echo "Running tests..."
TEST_BUNDLE="build/Debug/Focally.app/Contents/PlugIns/FocallyTests.xctest"

if [ ! -d "$TEST_BUNDLE" ]; then
    echo "❌ Test bundle not found at: $TEST_BUNDLE"
    exit 1
fi

echo "Found test bundle: $TEST_BUNDLE"

# Try to run tests
xcrun xctest "$TEST_BUNDLE" || {
    echo "❌ Tests failed to run"
    echo "💡 Tip: This might be a linking issue. Check if symbols are exported correctly."
    exit 1
}

echo "✅ Tests completed!"
