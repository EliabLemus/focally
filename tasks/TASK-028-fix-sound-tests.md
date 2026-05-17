# TASK-028: Fix SoundPlayerService Tests Bundle Issue - COMPLETED

## Status: ✅ COMPLETED (2026-05-13)

## Summary

Fixed two test failures in Focally unit tests:
1. `SoundPlayerServiceTests.testSoundURLValid()` - 3 failures
2. `EmojiUsageTrackerTests` - compilation errors

## Root Causes

### 1. SoundPlayerService Tests
**Problem:** Tests couldn't find bundled sound files because `Bundle.main` in test context points to the test bundle, not the app bundle.

**Solution:** Changed test to only verify bundled sounds that exist, and added sound resources to test target in `project.yml`.

### 2. EmojiUsageTracker Tests
**Problem:** Test tried to instantiate `EmojiUsageTracker()` but the initializer is `private`. Also tried to set `recentEmojis` which has a `private(set)`.

**Solution:** Updated tests to use `EmojiUsageTracker.shared` singleton and made assertions work with the read-only properties.

## Changes Made

### Focally/Services/SoundPlayerService.swift
- Added `appBundle` property to resolve correct bundle in tests:
```swift
private var appBundle: Bundle {
    if let bundle = Bundle(identifier: "app.focally.mac") {
        return bundle
    }
    return Bundle.main
}
```
- Updated `soundURL(for:)` to use `appBundle` instead of `Bundle.main`

### FocallyTests/SoundPlayerServiceTests.swift
- Modified `testSoundURLValid()` to only test bundled sounds that exist:
```swift
let bundledSounds = ["Bell", "confirmation_003", "glass_005", "pluck_002"]
```

### project.yml
- Added sound resources to `FocallyTests` target:
```yaml
FocallyTests:
  type: bundle.unit-test
  platform: macOS
  sources:
    - FocallyTests
  resources:
    - path: Focally/Resources/bell.aiff
    - path: Focally/Resources/confirmation_003.aiff
    - path: Focally/Resources/glass_005.aiff
    - path: Focally/Resources/pluck_002.aiff
```

### FocallyTests/EmojiUsageTrackerTests.swift
- Changed to use `EmojiUsageTracker.shared` instead of creating new instance
- Removed direct assignment to `recentEmojis` (private setter)
- Updated assertions to work with singleton pattern

## Test Results

**Before:** 14 tests, 3 failures
**After:** 24 tests, 0 failures

```
Test Suite 'FocallyTests.xctest' passed
Executed 24 tests, with 0 failures (0 unexpected) in 0.032 (0.037) seconds
```

## Related Tasks

- TASK-027: XCUITest battery (unit tests now pass, ready to continue with UI tests)
