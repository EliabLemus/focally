#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Running Focally Unit Tests with Swift Testing..."

# Run tests using xcodebuild with scheme
xcodebuild test \
    -project Focally.xcodeproj \
    -scheme FocallyTests \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    ONLY_ACTIVE_ARCH=YES \
    -enableCodeCoverage NO

echo "✅ All tests completed!"
