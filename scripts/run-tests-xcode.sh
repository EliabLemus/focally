#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Running Focally Unit Tests via Xcode..."

# Run tests using xcodebuild with scheme
xcodebuild test \
    -project Focally.xcodeproj \
    -scheme FocallyTests \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    ONLY_ACTIVE_ARCH=YES \
    -test-iterations 1 \
    -enableCodeCoverage NO \
    | grep -E "(Test Suite|Test Case|passed|failed|error:|warning:|BUILD)" || true

echo "✅ Test execution completed!"
