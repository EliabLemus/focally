# Release Procedure for Focally

## Context and Lessons Learned

### Common Issues (2026-05-06)

1. **Code sync between local and GitHub**
   - CI workflow used old code even though tag pointed to correct commit
   - **Cause**: Some files weren't committed correctly (`FocusTimerService.swift`)
   - **Solution**: Verify ALL modified files before committing

2. **Strict Swift compiler in CI**
   - Local compiles, but CI fails with type inference errors
   - **Cause**: CI uses stricter Swift than local environment
   - **Solution**: Add explicit type annotations for closures and parameters

3. **Multiple tags causing confusion**
   - Multiple tags (`v0.7.0`, `v0.7.1`) cause confusion
   - **Solution**: Delete old tags, use single tag per version

## Standard Release Procedure

### 1. Code Preparation

```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally

# Check what files are modified
git status --short

# Make sure ALL necessary files are staged
git add .

# Commit changes
git commit -m "feat: concise description of changes"
```

**IMPORTANT**: Verify ALL files are included, especially:
- New or modified `.swift` files
- `Focally.xcodeproj/project.pbxproj` (if new files added to project)
- `project.yml` (if version bump)

### 2. Version Bump

```bash
# Edit project.yml
vim project.yml

# Change:
# MARKETING_VERSION: "0.6.4" -> "0.7.0"
# CURRENT_PROJECT_VERSION: "13" -> "14"

# Commit the bump
git add project.yml
git commit -m "chore: bump version to X.Y.Z, build N"
```

**Versioning rule**:
- `0.X.Y` → 0.7.0 (major change, new big feature)
- `0.X.Y` → 0.6.5 (minor change, bug fixes)
- `0.X.Y` → 0.6.4.1 (patch, critical hotfix)

### 3. Local Build Verification

```bash
# Build in Debug first
xcodebuild -scheme Focally -configuration Debug build

# if passes, build in Release
xcodebuild -scheme Focally -configuration Release build

# Verify .app was created
find ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Release -name "Focally.app"
```

**CRITICAL**: If build fails locally, DO NOT push. Fix first.

### 4. Push to Main Repo

```bash
# Use GitHub PAT (deploy key doesn't have write permissions)
git config --local credential.helper 'store --file=/tmp/git-cred'
echo "https://$(gh auth token)@github.com" > /tmp/git-cred

# Push main
git push origin main
```

### 5. Create Tag

```bash
# Create version tag
git tag v0.7.0 HEAD

# Verify tag points to correct commit
git show v0.7.0 --stat

# Push tag
git push origin v0.7.0
```

**IMPORTANT**:
- Tag should point to `HEAD` (last commit on main)
- Use semantic format: `vX.Y.Z` where X=major, Y=minor, Z=patch
- Only one tag per version

### 6. Monitor GitHub Actions Workflow

```bash
# Check latest workflow
gh run list --repo EliabLemus/focally --limit 1

# View workflow logs (if failed)
gh run view --repo EliabLemus/focally --log <workflow-id> | grep -A5 "error:"

# Wait for completion (can take 3-5 minutes)
sleep 180
gh run list --repo EliabLemus/focally --limit 1
```

**Workflow states**:
- `queued` → Waiting to run
- `in_progress` → Building
- `success` → Release successful!
- `failure` → Review logs and fix

**NEW RULE — always do this before declaring the release done:**
- Confirm the workflow finished with `success`
- Confirm the GitHub Release exists and is not draft
- Confirm the DMG asset was uploaded
- Confirm the Homebrew tap was updated to the same version and SHA256

### 7. Verify Release

```bash
# List releases
gh release list --repo EliabLemus/focally

# View latest release details
gh release view --repo EliabLemus/focally v0.7.0

# Verify DMG exists
gh release view --repo EliabLemus/focally v0.7.0 --json assets
```

### 8. Verify Homebrew Tap

This step is mandatory. A release is **not done** until the tap matches the release asset.

```bash
# Check version in cask
gh api repos/EliabLemus/homebrew-focally/contents/Casks/focally.rb --jq '.content' | base64 -d | grep "version"

# Check SHA256
gh api repos/EliabLemus/homebrew-focally/contents/Casks/focally.rb --jq '.content' | base64 -d | grep "sha256"
```

### 9. Test Release (Optional)

```bash
# On another machine or clean environment:
brew update && brew upgrade --cask focally

# Verify app installs and opens
open -a Focally
```

## Troubleshooting

### Issue: Build fails in CI but passes locally

**Symptoms**:
- Local: `xcodebuild` → `BUILD SUCCEEDED`
- CI: `error: cannot infer type of closure parameter` / `error: extra arguments`

**Solution**:
1. Add explicit type annotations to problematic closures
2. Example: `.sink { [weak self] _ in` → `.sink { [weak self] (_: Never) in`
3. Example: `lazy var timerService = FocusTimerService(...)` → `private lazy var timerService: FocusTimerService = FocusTimerService(...)`

**Common problematic files**:
- `Focally/OnItFocusApp.swift` → Combine closures
- `Focally/Services/*.swift` → dependency injection

### Issue: CI uses old code even though tag is correct

**Symptoms**:
- Tag points to correct commit (`git show v0.7.0 --stat`)
- CI uses older code (error on line that was already fixed)

**Solution**:
1. Verify ALL modified files are committed
2. Example: `FocusTimerService.swift` had old parameters
3. Commit the missing file: `git add Focally/Services/FocusTimerService.swift`
4. Push: `git push origin main`
5. Update tag: `git tag -d v0.7.0 && git tag v0.7.0 HEAD && git push origin v0.7.0 --force`

### Issue: Deploy key doesn't have write permissions

**Symptoms**:
- `ERROR: Permission to EliabLemus/focally.git denied to deploy key`

**Solution**:
1. Use `gh` CLI with GitHub PAT
2. Configure credentials:
   ```bash
   git config --local credential.helper 'store --file=/tmp/git-cred'
   echo "https://$(gh auth token)@github.com" > /tmp/git-cred
   ```
3. Push with `https://` instead of `git@github.com:`

### Issue: Workflow fails with `xcodegen` error

**Symptoms**:
- `Created project at /Users/runner/work/focally/focally/Focally.xcodeproj`
- `** BUILD FAILED **`

**Solution**:
1. Run `xcodegen generate` locally before committing
2. Verify project was generated without errors
3. Commit `Focally.xcodeproj/project.pbxproj` if it changed

## Release Checklist

Before making push:

- [ ] All modified files are committed
- [ ] `project.yml` has version and build bumped
- [ ] Local build passes: `xcodebuild -scheme Focally -configuration Release build`
- [ ] Tag created: `git tag v0.7.0 HEAD`
- [ ] Tag verified: `git show v0.7.0 --stat`
- [ ] GitHub credentials configured
- [ ] Push main: `git push origin main`
- [ ] Push tag: `git push origin v0.7.0`

After workflow completion:

- [ ] Workflow success: `gh run list --limit 1 --json conclusion`
- [ ] Release created: `gh release list --limit 1`
- [ ] DMG uploaded: `gh release view v0.7.0 --json assets`
- [ ] Homebrew tap updated: version and SHA256 correct
- [ ] Installation test: `brew upgrade --cask focally`

**Do not stop at tag push.** Always verify workflow + release asset + tap before reporting success.

## References

- **Main repo**: `EliabLemus/focally`
- **Homebrew tap**: `EliabLemus/homebrew-focally`
- **Workflow**: `.github/workflows/release.yml`
- **Build script**: `scripts/build-release.sh`
- **Configuration**: `project.yml`

## Updates

- **2026-05-06**: Initial version based on v0.7.1 troubleshooting
  - Added missing files verification
  - Added Swift type annotations guide
  - Added deploy key permissions solution
