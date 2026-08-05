# TASK-044: Repair the Focally release pipeline end-to-end

## Problem
The release pipeline is broken even though local builds work and manual GitHub releases can be created.

Current failure from GitHub Actions release job `92185210359`:
```text
chmod: scripts/build-release.sh: No such file or directory
Process completed with exit code 1.
```

## Root Cause
The repository was reorganized but `.github/workflows/release.yml` still calls `scripts/build-release.sh`. That file no longer exists in `main`, and there is no `scripts/` directory in the repo.

The pipeline currently has no checked-in release build script that both local development and CI can use.

## Goal
Restore a working release pipeline from local source build to automated GitHub release + Homebrew tap update.

This task must leave the repo in a state where:
1. local release build works from source,
2. GitHub Actions can build the DMG from a tag,
3. the generated DMG name/path matches the workflow expectations,
4. the Homebrew tap update step keeps working unchanged.

## Archivos relevantes
- `.github/workflows/release.yml` — broken release workflow; currently calls missing script and uploads `build/Focally-${tag}.dmg`
- `project.yml` — source of truth for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`; bump to the next release used to validate the repaired pipeline
- `README.md` — installation/release text may mention old behavior if needed for consistency
- `Documentation/guides/RELEASE_GUIDE.md` — documented release process; update only if the implementation changes the canonical command materially
- `Documentation/guides/PROCEDIMIENTO_RELEASE.md` — Spanish release procedure mirror; update only if the canonical command materially changes
- `tasks/TASK-044-SPEC.md` — update Result section before finishing

## Files to create
- `scripts/build-release.sh` — canonical macOS release build script used by GitHub Actions and local verification
- `scripts/create-release.sh` — optional local wrapper only if needed to keep the local release flow coherent; do NOT add it unless it provides real value and is actually used by the documented flow

## Constraints
- Read ALL relevant files before modifying anything.
- Do NOT touch unrelated app logic in `Sources/Focally/**`.
- Do NOT modify the Homebrew tap workflow logic unless strictly necessary; prefer matching its current expectations.
- The build script must run on macOS locally and on GitHub Actions macOS runners.
- The build artifact path must remain:
  - `build/Focally-vX.Y.Z.dmg`
- The workflow step that updates Homebrew expects the DMG filename shape above. Preserve it.
- The script must validate that the requested tag version matches `project.yml` / built app version.
- The script must create `build/` itself if missing.
- Keep the workflow minimal: fix the broken path/dependency chain, not a broad CI redesign.
- Bump version for pipeline-validation release:
  - `MARKETING_VERSION`: `0.9.5` → `0.9.6`
  - `CURRENT_PROJECT_VERSION`: `78` → `79`
- AUTORIZADO a modificar:
  - `.github/workflows/release.yml`
  - `project.yml`
  - `Focally.xcodeproj/project.pbxproj` if `xcodegen generate` regenerates it as part of the repaired flow
  - `README.md` only if necessary
  - `Documentation/guides/RELEASE_GUIDE.md` only if necessary
  - `Documentation/guides/PROCEDIMIENTO_RELEASE.md` only if necessary
- AUTORIZADO a crear:
  - `scripts/build-release.sh`
  - `scripts/create-release.sh` only if justified by the final flow

## Tasks

### 1. Add canonical release build script
Create `scripts/build-release.sh`.

Required behavior:
```bash
./scripts/build-release.sh v0.9.6
```

It must:
1. fail fast (`set -euo pipefail`)
2. accept exactly one argument like `v0.9.6`
3. derive `VERSION_NO_V=0.9.6`
4. read `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from `project.yml`
5. fail if `VERSION_NO_V` does not equal `MARKETING_VERSION`
6. generate or refresh the Xcode project from `project.yml` (`xcodegen generate`)
7. build Release with a deterministic local path, e.g. `DerivedData/`
8. use no-sign / CI-safe build flags compatible with current repo
9. verify the built app Info.plist contains:
   - `CFBundleShortVersionString == MARKETING_VERSION`
   - `CFBundleVersion == CURRENT_PROJECT_VERSION`
10. assemble a DMG at exactly:
    - `build/Focally-v0.9.6.dmg`
11. include `Focally.app` and an `/Applications` symlink in the DMG staging folder
12. print the SHA256 of the generated DMG at the end

Implementation details are up to you, but the current local manual flow already proved these steps work. Reuse that logic rather than inventing a different packaging layout.

### 2. Repair the release workflow
Update `.github/workflows/release.yml` so the release job succeeds with the checked-in script.

Requirements:
- Ensure the workflow can execute `scripts/build-release.sh`
- Keep the upload path aligned with the generated DMG path
- Keep the Homebrew update step aligned with the same DMG path/name
- Do not leave references to missing files

If the workflow currently already matches the desired DMG path once the script exists, keep changes minimal.

### 3. Version bump for validation release
Update `project.yml`:
- `MARKETING_VERSION`: `"0.9.5"` → `"0.9.6"`
- `CURRENT_PROJECT_VERSION`: `"78"` → `"79"`

The repaired pipeline will be validated by tagging and releasing `v0.9.6`.

### 4. Documentation consistency
Only if needed, update release docs so they point to the real canonical script/command.

Preferred outcome:
- docs mention `scripts/build-release.sh` as the real checked-in build primitive
- no docs claim a missing script exists

### 5. Local verification
Before finishing, run and verify:
```bash
chmod +x scripts/build-release.sh
./scripts/build-release.sh v0.9.6
```

Then confirm from the built app Info.plist that:
- `CFBundleShortVersionString` = `0.9.6`
- `CFBundleVersion` = `79`

## Acceptance Criteria
- `scripts/build-release.sh` exists in the repo and is executable in CI/local environments
- local command `./scripts/build-release.sh v0.9.6` succeeds
- output DMG exists at `build/Focally-v0.9.6.dmg`
- workflow no longer references a missing path
- workflow is still compatible with Homebrew auto-update step
- `project.yml` is bumped to `0.9.6` build `79`
- no unrelated app logic changed

## Result
- Status: done
- Summary: Added the canonical release build script, bumped the validation release to 0.9.6 (79), regenerated the Xcode project, and aligned both release guides with the CI build command. The release app and DMG now build locally from the checked-in script.
- Files modified: `project.yml`; `Focally.xcodeproj/project.pbxproj` (regenerated by `xcodegen generate`); `Documentation/guides/RELEASE_GUIDE.md`; `Documentation/guides/PROCEDIMIENTO_RELEASE.md`; `tasks/TASK-044-SPEC.md`
- Files created: `scripts/build-release.sh` (executable)
- Tests / verification run: `bash -n scripts/build-release.sh`; invalid tag shape rejection; `./scripts/build-release.sh v0.9.6`; built `Info.plist` confirmed `CFBundleShortVersionString=0.9.6` and `CFBundleVersion=79`; `shasum -a 256 build/Focally-v0.9.6.dmg`
- Notes: `.github/workflows/release.yml` and its Homebrew update logic were left unchanged because they already use the required `build/Focally-vX.Y.Z.dmg` path. No `scripts/create-release.sh` wrapper was added. No files under `Sources/Focally/**` were modified.
- Blocked by:
