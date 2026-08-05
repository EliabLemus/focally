# TASK-047: Single SlackService Source of Truth

## Objective
Eliminate the duplicate runtime SlackService instances. The instance observed by settings and SwiftUI must be the same instance used by focus-session and Calendar Slack actions.

## Base
- Worktree: `/tmp/focally-integration-integrity`
- Branch: `refactor/single-slack-service`
- Base commit: `90c68e0`
- Audit: `/tmp/focally-audit-integration-integrity.md`

## Safety and scope
- Do not push, tag, release, modify Homebrew, or bump version/build.
- This task only unifies object identity and adds regression coverage.
- Do not redesign presence policy, rewrite App Intents, change metrics, add async UI feedback, add protocols, or annotate SlackService with `@MainActor`.
- Do not change Slack API behavior, credentials, UserDefaults keys, Keychain keys, network requests, or public method signatures.

## Authorized files
- `Sources/Focally/Services/SlackService.swift`
- `Sources/Focally/Services/FocusIntegrationService.swift`
- `Sources/Focally/OnItFocusApp.swift`
- `Tests/FocallyTests/SlackServiceEmojiTests.swift`
- Create: `Tests/FocallyTests/SlackServiceSingletonTests.swift`
- `tasks/TASK-047-SPEC.md`

Explicitly forbidden:
- `Sources/Focally/Services/CalendarSlackIntegrationService.swift` — it already receives the AppDelegate instance correctly.
- all timer, metrics, update UX, localization, release, and project configuration files.

`Focally.xcodeproj/project.pbxproj` is generated. You may run `xcodegen generate` locally for tests, but restore it before committing. Final integration will regenerate it once.

## Required implementation

### 1. Add the shared instance
In `SlackService`:
- add `static let shared = SlackService()`;
- make direct production construction impossible by making the initializer private unless Swift compilation constraints require the smallest equivalent restriction;
- preserve all existing initialization behavior and stored-state defaults.

Do not make the class `@MainActor` in this task.

### 2. Wire all production consumers to it
- `AppDelegate.slackService` must be `SlackService.shared`.
- The default Slack dependency in `FocusIntegrationService` must be `.shared`.
- Leave Calendar initialization structurally unchanged; because AppDelegate now owns `.shared`, Calendar receives the same instance.
- Leave all SwiftUI `.environment(slackService)` sites unchanged.

Afterward, `SlackService(` in production Sources must appear only in the singleton's own construction/initializer declaration, never at consumer sites.

### 3. Preserve testability
Update `SlackServiceEmojiTests` to use `.shared` and reset mutable emoji state in `setUp` and `tearDown` so tests remain isolated.

Add the smallest internal, non-public identity inspection seam to `FocusIntegrationService` if needed so `@testable import Focally` can prove it uses `SlackService.shared`. Do not expose credentials, token contents, or network internals.

### 4. Regression tests
Create `SlackServiceSingletonTests.swift` covering:
1. repeated `SlackService.shared` access returns identical object identity;
2. `FocusIntegrationService.shared` owns that exact instance;
3. mutable in-memory `isEnabled` state is observed through the FocusIntegrationService dependency rather than a second object;
4. shared observable error/emoji state is not duplicated;
5. restore every modified shared property/UserDefaults value in teardown.

Tests must not make Slack network calls and must not require a token.

If testing state propagation requires a tiny internal read-only seam, keep it narrowly scoped and document it. Do not alter operational methods merely to satisfy tests.

## Verification

```bash
xcodegen generate
xcodebuild test \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

rg -n 'SlackService\(' Sources/Focally
```

The constructor census must show no consumer-created instance.

Then:

```bash
git restore Focally.xcodeproj/project.pbxproj
git status --short
git diff --check
```

Only authorized files may remain changed.

## Acceptance criteria
- AppDelegate, FocusIntegrationService, CalendarSlackIntegrationService, and SwiftUI environment use one SlackService identity.
- Toggling in-memory Slack enabled state cannot diverge between UI and focus integrations.
- Existing emoji tests remain isolated.
- New identity/state regression tests pass without network access.
- Full test suite passes.
- No public API, persistence key, credential, network, timer, metrics, presence policy, or update UX change.
- No generated-project commit, version bump, push, tag, release, or Homebrew update.
- One commit: `refactor: share one Slack service instance`.

## Result
- Status: implemented and host-verified; ready for review and commit
- Summary: Added a private `SlackService.shared` singleton, wired AppDelegate and FocusIntegrationService to it, preserved Calendar/SwiftUI wiring, and added isolated identity/state regression coverage.
- Files modified: `Sources/Focally/Services/SlackService.swift`, `Sources/Focally/Services/FocusIntegrationService.swift`, `Sources/Focally/OnItFocusApp.swift`, `Tests/FocallyTests/SlackServiceEmojiTests.swift`, `tasks/TASK-047-SPEC.md`
- Files created: `Tests/FocallyTests/SlackServiceSingletonTests.swift`
- Tests / verification:
  - `xcodegen generate` — passed; generated project churn restored.
  - Host `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` — passed: 57 tests, 0 failures.
  - Constructor census shows only `SlackService.shared` construction in production Sources.
  - `git diff --check` — passed.
- Commit: pending review; required message: `refactor: share one Slack service instance`.
- Notes: No network calls, token access, public API changes, generated-project changes, version changes, push, tag, release, or Homebrew changes were made.
