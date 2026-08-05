# TASK-046: Discreet Update UX and Documentation Truth

## Objective
Make update availability deliberately quiet: no dashboard banner, no menu-bar popover banner, and no native update notification path. The sole user-facing update indicator must live in Settings → About.

## Base
- Worktree: `/tmp/focally-update-ux`
- Branch: `fix/discreet-update-ux`
- Base commit: `90c68e0`
- Audit: `/tmp/focally-audit-update-ux.md`

## Safety and scope
- Do not push, tag, release, or modify Homebrew.
- Do not bump version/build.
- Do not modify `UpdateCheckerService.swift`, timer services, FocusIntegrationService, CalendarSlackIntegrationService, SlackService, OnItFocusApp, project.yml, release workflow, or generated Xcode project.
- Preserve the 4-hour update-check cadence and GitHub API behavior.

## Authorized files
- `Sources/Focally/Views/Timer/IdleDashboardView.swift`
- `Sources/Focally/Views/MenuBar/MenuBarDropdownView.swift`
- `Sources/Focally/Views/Settings/AboutSettingsView.swift`
- `Sources/Focally/Services/NotificationService.swift`
- `Sources/Focally/Resources/en.lproj/Localizable.strings`
- `Sources/Focally/Resources/es.lproj/Localizable.strings`
- `Sources/Focally/Resources/pt.lproj/Localizable.strings`
- `README.md`
- `CHANGELOG.md`
- `tasks/focally-update-alert-v0.9.2.yaml`
- `tasks/TASK-046-SPEC.md`

## Required changes

### 1. Remove aggressive surfaces
From `IdleDashboardView` and `MenuBarDropdownView`:
- remove the `UpdateCheckerService` environment property;
- remove the entire update-available banner block;
- leave surrounding layout unchanged.

These files must contain zero `updateChecker` references afterward.

### 2. Keep About as the only update surface
Retain the conditional update indicator and download action in `AboutSettingsView`.

Make it discreet:
- use one system icon, not an icon plus warning emoji;
- use the existing subdued inline/bordered presentation;
- do not add banners, sheets, alerts, notifications, or automatic browser opening.

### 3. Localize About
Replace user-visible hardcoded strings, except the `Focally` brand, with localization keys.

Reuse existing:
- `about_version`
- `about_build`
- `about_update_available`
- `about_copyright`
- `update_version`

Add in EN/ES/PT:
- `about_get_update`
- `about_tagline`
- `about_description`
- `about_github_link`
- `about_license`

Preserve the meaning of the current English copy. Use natural Spanish and Portuguese. Avoid embedding locale-specific string composition where format keys are more appropriate.

### 4. Remove dead native update-notification path
From `NotificationService.Event` and its switch:
- remove `.updateAvailable(version:)`;
- remove the corresponding title/body branch.

Confirm there are no call sites first. Do not change focus, break, permission, or session notifications.

Remove now-unused keys from all locales:
- `notification_update_title`
- `notification_update_body`
- `update_available_badge`

Keep `update_version` because About uses it.

### 5. Correct documentation drift
- README EN/ES/PT: update checker runs every 4 hours, not every 24 hours.
- Confirm README states the indicator appears in Settings → About.
- Add a concise `[Unreleased]` changelog item explaining the quiet update UX.
- Mark `tasks/focally-update-alert-v0.9.2.yaml` as superseded at the top. Do not reference `/tmp` paths in durable repository documentation; reference the product decision directly.

Do not expand this task into general README cleanup.

## Verification

### Static checks
```bash
! grep -R "updateChecker" Sources/Focally/Views/Timer/IdleDashboardView.swift Sources/Focally/Views/MenuBar/MenuBarDropdownView.swift
grep -R "updateAvailable" Sources/Focally || true
```

The second command must show no native update notification case/call. `isNewVersionAvailable` in UpdateChecker/About is expected and must remain.

Confirm localization parity by comparing key sets across all three `Localizable.strings` files.

### Build and tests
```bash
xcodebuild test \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

xcodebuild \
  -project Focally.xcodeproj \
  -scheme Focally \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

No XcodeGen regeneration is expected because no source files are added.

## Acceptance criteria
- Dashboard and menu-bar popover never show update banners.
- About remains the only indicator and opens the update URL only after user action.
- No native update-notification event exists.
- About renders localized EN/ES/PT copy and current copyright.
- README cadence matches the actual 4-hour implementation.
- All tests and Debug build pass.
- Only authorized files are changed.
- No version bump, push, tag, release, Homebrew update, or generated-project change.
- One commit: `fix: make update availability discreet`.

## Result
- Status: implemented and host-verified; ready for review and commit
- Summary: Removed dashboard, menu-bar, and native-notification update surfaces; retained a discreet, localized Settings → About indicator; corrected update documentation and superseded the prior alert task.
- Files modified: `IdleDashboardView.swift`, `MenuBarDropdownView.swift`, `AboutSettingsView.swift`, `NotificationService.swift`, EN/ES/PT `Localizable.strings`, `README.md`, `CHANGELOG.md`, `tasks/focally-update-alert-v0.9.2.yaml`, and this task spec.
- Tests / verification:
  - No `updateChecker` references remain in dashboard or menu-bar views.
  - No native `updateAvailable` notification event remains.
  - EN/ES/PT each contain the same 229 localization keys with no duplicates.
  - Host `xcodebuild test ...` — passed: 53 tests, 0 failures.
  - Host Debug `xcodebuild ... build ...` — passed (`** BUILD SUCCEEDED **`).
  - `git diff --check` — passed.
- Commit: pending review; required message: `fix: make update availability discreet`.
- Notes: No version/build bump, push, tag, release, Homebrew change, XcodeGen regeneration, generated-project change, timer cadence change, or GitHub API behavior change.
