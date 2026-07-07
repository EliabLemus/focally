# TASK-040 URGENT: Fix version not appearing in release builds

**Priority:** CRITICAL
**Blocker:** YES
**Target Version:** v0.7.30

## 🚨 CRITICAL ISSUE FOUND

**Root Cause Identified:**

The `Focally.xcodeproj/project.pbxproj` file contains **OUTDATED VERSIONS**:
- **MARKETING_VERSION = 0.7.22** (should be 0.7.29)
- **CURRENT_PROJECT_VERSION = 35** (should be 43)

This is why the release build has no version info in Info.plist!

## Verification

```bash
# Check current project file versions
grep "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" /Users/openjaime/projects/focally/Focally.xcodeproj/project.pbxproj

# Check project.yml (correct source of truth)
grep "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" /Users/openjaime/projects/focally/project.yml

# Check release DMG Info.plist (missing versions!)
cat "/Volumes/Focally/Focally.app/Contents/Info.plist" | grep -i version
```

## The Problem

1. **project.yml** (source of truth) has:
   - MARKETING_VERSION: "0.7.29"
   - CURRENT_PROJECT_VERSION: "43"

2. **Focally.xcodeproj/project.pbxproj** (stale, not regenerated) has:
   - MARKETING_VERSION: "0.7.22"  ❌ WRONG
   - CURRENT_PROJECT_VERSION: "35"  ❌ WRONG

3. **Release build** uses stale project.pbxproj → Info.plist missing versions

4. **About view** can't read version → shows nothing or fallback "0.5.1"

## Why This Happened

- project.yml was bumped to 0.7.29
- Commit + push + tag was done
- BUT `xcodegen generate` was NOT run locally
- The stale `Focally.xcodeproj/project.pbxproj` from v0.7.22 was committed
- CI runs `xcodegen generate` BUT CODE_SIGNING_ALLOWED=NO might affect variable substitution

## 🛠️ Fix Required

### Step 1: Regenerate Xcode project locally

```bash
cd /Users/openjaime/projects/focally

# Delete stale project
rm -rf Focally.xcodeproj

# Regenerate from project.yml
xcodegen generate

# Verify versions are correct
grep "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" Focally.xcodeproj/project.pbxproj
# Should show: MARKETING_VERSION = 0.7.29, CURRENT_PROJECT_VERSION = 43
```

### Step 2: Build and verify locally

```bash
# Build release locally
xcodebuild build \
    -project Focally.xcodeproj \
    -scheme Focally \
    -configuration Release \
    -destination 'platform=macOS'

# Check Info.plist
cat ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Release/Focally.app/Contents/Info.plist | grep -i "Bundle.*Version"
# Should show CFBundleShortVersionString and CFBundleVersion
```

### Step 3: Commit and push regenerated project

```bash
git add Focally.xcodeproj/project.pbxproj
git commit -m "fix: regenerate Xcode project with correct versions (0.7.29)"
git push origin main
```

### Step 4: Retag and rebuild release

```bash
# Delete old tag (GitHub doesn't allow reusing tags)
git push origin --delete v0.7.29
git tag -d v0.7.29

# Create new tag
git tag v0.7.30
git push origin v0.7.30

# CI will automatically rebuild v0.7.30
```

### Step 5: Update Homebrew cask

After CI completes v0.7.30:

```bash
# Download new DMG
gh release download v0.7.30 --repo EliabLemus/focally --pattern "*.dmg" --dir /tmp

# Calculate SHA
shasum -a 256 /tmp/Focally-v0.7.30.dmg

# Update cask
cd /opt/homebrew/Library/Taps/eliablemus/homebrew-focally
# Edit Casks/focally.rb with new version and SHA

git add Casks/focally.rb
git commit -m "bump: focally cask to v0.7.30"
git push origin main
```

## Additional Issues to Investigate

After fixing version display, these issues remain:

### 2. DND not working
- Review `DNDService.swift` implementation
- Verify Accessibility permissions granted
- Check Console.app for DND activation logs
- macOS 15 may have changed DND API

### 3. Slack not working
- Check Console.app for Slack API logs
- Verify Slack integration enabled in settings
- Verify Slack token valid
- Check for API errors

### 4. Meeting category not visible
- Review Console.app for migration logs
- Verify `migrateTasksIfNeeded()` is called
- Check if Meeting task persisted to UserDefaults

## Questions for Eliab

1. **Can you regenerate the Xcode project?** This is the blocker.
2. **Do you have the "focally.logs" file?** Can you paste the contents or share the path?
3. **Have you granted Accessibility permissions to Focally?** (System Settings > Privacy & Security > Accessibility)
4. **Is Slack integration enabled in Focally settings?** Does it show "Connected"?

## Acceptance Criteria

✅ Focally.xcodeproj/project.pbxproj has MARKETING_VERSION = 0.7.29
✅ Focally.xcodeproj/project.pbxproj has CURRENT_PROJECT_VERSION = 43
✅ Release build Info.plist contains CFBundleShortVersionString
✅ Release build Info.plist contains CFBundleVersion
✅ About view shows "Version 0.7.29"
✅ Menu bar shows version (optional enhancement)
✅ v0.7.30 release published with correct version
✅ Homebrew cask updated to v0.7.30