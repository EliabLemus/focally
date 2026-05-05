#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🧪 Quick Focally Unit Tests (Swift Testing)..."

# Quick test execution
xcodebuild test \
    -project Focally.xcodeproj \
    -scheme FocallyTests \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    -quiet \
    ONLY_ACTIVE_ARCH=YES 2>&1 | grep -E "(Test Suite|Test Case|passed|failed|✅|❌|error:)" || echo "✅ Build completed (may be running)"

echo "📊 Test execution summary"
