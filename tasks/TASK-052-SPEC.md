# TASK-052 — Honest asynchronous integration feedback

## Status

`done`

## Goal

Replace timing guesses and stale synchronous reads in the Integrations settings flow with explicit, testable asynchronous operation states. The user must see when a Slack operation is running, receive the real eventual result, and be able to retry a failed operation.

## Current defects

1. `IntegrationsSettingsView.testSlackConnection()` calls `slackService.testConnection()` and immediately reads `isConnected` / `connectionError`, before `auth.test` finishes.
2. `FocusIntegrationService.runSlackTest()` launches two network operations and guesses completion after `0.2` seconds.
3. Buttons remain actionable while an operation is running; there is no operation-specific spinner or reliable retry affordance.
4. Some failure feedback is hard-coded in English.

## Required behavior

### Shared operation state

Introduce a small explicit, Equatable state model suitable for observation and tests:

- `.idle`
- `.working`
- `.success(message)`
- `.failed(message)`

The exact type name and placement may follow the existing architecture, but do not create parallel boolean flags that can contradict the state.

### Slack connection test

- Starting a connection test transitions immediately to `.working`.
- Completion comes from the actual `auth.test` response, not an immediate read or timer.
- A valid `xoxp-` response transitions to `.success` and keeps `isConnected == true`.
- Missing token, network failure, invalid response, unsupported token type, or Slack API failure transitions to `.failed` with a concrete user-facing message and keeps `isConnected == false`.
- A later retry must clear the previous terminal result by entering `.working`, then publish the new real result.

### Slack focus-status test

- Starting the test transitions immediately to `.working`.
- Remove the `DispatchQueue.main.asyncAfter(...0.2)` completion guess.
- Completion must be driven by the actual Slack request callback/result.
- Report `.success` only after the test focus status request genuinely succeeds.
- Report `.failed` with the concrete error when it fails.
- Do not require the DND cleanup request to win a race before reporting status success. Preserve existing intended DND/status behavior without adding extra external effects.

### Settings UI

For Test Connection and Test Focus Status independently:

- show a compact `ProgressView` while that operation is `.working`;
- disable that operation's button while it is `.working` to prevent duplicate requests;
- show success feedback in the positive color and failure feedback in the error color;
- show a localized Retry action after failure that reruns the corresponding operation;
- do not show stale success while a retry is running;
- keep the existing visual system (`FocallySpacing`, typography, colors, glass cards), without redesigning the settings screen.

### Localization

Add every new user-visible string to:

- English
- Spanish
- Portuguese

No newly introduced hard-coded English feedback in the view.

## Strict TDD sequence

Production changes are forbidden before a failing test exists.

For each vertical behavior slice:

1. Add one focused test.
2. Run it and record the expected RED failure caused by missing behavior.
3. Implement the minimum production change.
4. Run it again and record GREEN.
5. Continue to the next behavior.

Tests must cover at least:

1. connection state transitions `idle -> working -> success`;
2. connection state transitions `idle -> working -> failed`;
3. retry clears a previous failure and can succeed;
4. focus-status test completion is callback-driven, not delay-driven;
5. overlapping duplicate invocation while `.working` does not launch a second equivalent request, or the UI/service otherwise enforces the same invariant deterministically.

Use injected inert closures/protocols/recording stubs. Unit tests MUST NOT use `SlackService.shared` in a way that performs network traffic, changes real Slack state, writes a real token, toggles system DND, runs Shortcuts, or mutates user credentials.

## Relevant files — read all before modifying

- `Sources/Focally/Services/SlackService.swift` — current callback-based Slack API, token validation, errors, and connection state.
- `Sources/Focally/Services/FocusIntegrationService.swift` — current focus integration test with the fixed 0.2-second guess.
- `Sources/Focally/Views/Settings/IntegrationsSettingsView.swift` — current synchronous stale read and feedback UI.
- `Sources/Focally/Resources/en.lproj/Localizable.strings` — English integration strings.
- `Sources/Focally/Resources/es.lproj/Localizable.strings` — Spanish integration strings.
- `Sources/Focally/Resources/pt.lproj/Localizable.strings` — Portuguese integration strings.
- `Tests/FocallyTests/SlackServiceSingletonTests.swift` — singleton identity guardrails; do not make these tests trigger external effects.
- `Tests/FocallyTests/PresenceCoordinatorTests.swift` — examples of inert integration stubs and main-actor tests.
- `project.yml` — source discovery is directory-based; do not modify versions/build numbers.

## Authorized changes

Codex may modify only:

- `Sources/Focally/Services/SlackService.swift`
- `Sources/Focally/Services/FocusIntegrationService.swift`
- `Sources/Focally/Views/Settings/IntegrationsSettingsView.swift`
- `Sources/Focally/Resources/en.lproj/Localizable.strings`
- `Sources/Focally/Resources/es.lproj/Localizable.strings`
- `Sources/Focally/Resources/pt.lproj/Localizable.strings`
- existing tests under `Tests/FocallyTests/` only if directly required by this task
- one or more new focused test files under `Tests/FocallyTests/`
- this spec's `Result` section

## Forbidden changes

- No push, tag, GitHub release, Homebrew update, version bump, or build-number bump.
- Do not modify `project.yml`, `Focally.xcodeproj`, Info.plists, `.hermes/`, `build/`, app icons, README, or release scripts.
- Do not redesign presence precedence, durable sessions, metrics, Calendar ownership, App Intents, Quick Start, or DND policy.
- Do not replace the single shared production `SlackService` invariant.
- Do not log raw Slack tokens or Authorization headers.
- Do not make tests contact Slack or alter real machine/user state.
- Do not claim full-suite or Release-build success unless the exact command really ran and completed successfully in this worktree.

## Verification commands

Generate only if needed to discover a new test file, but restore generated project churn before handoff:

```bash
xcodegen generate
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests/<NewTestClass>
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'
git diff --check
```

The coordinator will independently run the final suite and clean Release build.

## Acceptance criteria

- No immediate synchronous read after starting `auth.test` determines displayed success/failure.
- No fixed-delay completion guess remains in `runSlackTest`.
- Explicit async states drive button/spinner/result/retry UI.
- Retry is deterministic and does not preserve stale success.
- New feedback is localized in EN/ES/PT.
- Tests are inert and demonstrate RED then GREEN.
- Existing full unit suite passes.
- Worktree diff is limited to authorized files.

## Result — Codex fills this section

- Status: done.
- Summary: Explicit `connectionTestState` and `slackTestState` now drive the two Settings tests independently. Each operation has compact working progress, operation-specific disabling, positive/error feedback, and localized retry without stale terminal feedback. The immediate `isConnected`/`connectionError` read and parallel `slackTestFeedback` view state were removed. Both services ignore an equivalent duplicate invocation while their operation is `.working`, while terminal states remain retryable.
- Files modified: `Sources/Focally/Services/SlackService.swift`, `Sources/Focally/Services/FocusIntegrationService.swift`, `Sources/Focally/Views/Settings/IntegrationsSettingsView.swift`, the EN/ES/PT `Localizable.strings` files, `Tests/FocallyTests/SlackOperationStateTests.swift`, and this Result section.
- Verification supplied by the host: all 5 original `SlackOperationStateTests` are GREEN. The existing focus-status test was then strengthened to assert deterministically that a duplicate invocation while `.working` does not launch a second `/api/users.profile.set` request.
- Final focused local attempt: `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-final -only-testing:FocallyTests/SlackOperationStateTests` exited 65 before test execution because the sandboxed `swift-plugin-server` could not load `ObservationMacros` and produced malformed responses. No local GREEN is claimed for the strengthened assertion.
- Tests and RED/GREEN evidence:
  - Valid host RED supplied for this continuation: `SlackOperationStateTests.connectionTestTransitionsFromWorkingToSuccess` compiled the project and failed because `SlackService` had neither the injectable initializer nor `connectionTestState`.
  - Local GREEN attempt: `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-green -only-testing:FocallyTests/SlackOperationStateTests` did not reach test execution. The build failed across existing `@Observable` production types with `External macro implementation type 'ObservationMacros.ObservableMacro' could not be found` and `swift-plugin-server produced malformed response`. No GREEN is claimed.
- Slice 2 RED/GREEN evidence: Valid host RED was supplied for `SlackOperationStateTests.connectionTestTransitionsFromWorkingToFailedForSlackAPIError`: `invalid_auth` left `connectionTestState` at `.working`. After the production patch, the focused command `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-slice2-green -only-testing:FocallyTests/SlackOperationStateTests/connectionTestTransitionsFromWorkingToFailedForSlackAPIError` was attempted locally, but compilation again stopped before test execution because `swift-plugin-server` could not load `ObservationMacros` and produced a malformed response (exit 65). The host-provided RED is recorded; no local runtime GREEN is claimed.
- Host verification received for this continuation: the existing success and failure tests are GREEN.
- Slice 3 host result: `SlackOperationStateTests.connectionTestRetryClearsFailureAndCanSucceed` passed immediately. That is an honest GREEN from behavior already implemented by slices 1–2, not evidence of a new slice 3 production patch; none was made.
- Slice 4 RED evidence: Added `SlackOperationStateTests.focusStatusTestCompletesOnlyFromStatusResponse` without modifying production. The focused command `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-slice4-red -only-testing:FocallyTests/SlackOperationStateTests/focusStatusTestCompletesOnlyFromStatusResponse` exited 65 before test execution because `swift-plugin-server` could not load `ObservationMacros` and produced a malformed response. This is an environment-blocked RED attempt, not a claimed behavioral execution. On a healthy host the test is expected to be RED because `FocusIntegrationService` does not yet expose `slackTestState`, and its current fixed-delay callback would also complete before the synthetic status response.
- Slice 4 production: `SlackService.setStatus` now has a completion-bearing overload using an optional `Result<Void, Error>` closure, while the original signature remains as a forwarding overload so existing callers and protocol conformance are preserved. Every early or network/API outcome reports exactly once. `runSlackTest` consumes that result directly; DND state and shared `connectionError` are not consulted to determine the focus-status test result.
- Slice 4 local GREEN attempt: `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-slice4-green -only-testing:FocallyTests/SlackOperationStateTests/focusStatusTestCompletesOnlyFromStatusResponse` exited 65 before test execution because `swift-plugin-server` again could not load `ObservationMacros` and produced malformed responses. No local runtime GREEN is claimed; `git diff --check` passed.
- Safety: The dummy token is the clearly fictitious `xoxp-test-only-not-a-real-slack-token`. The `SlackService` test initializer keeps it in memory and routes every request through the synthetic recording transport. The injected `PresenceCoordinating` and shortcut closure are inert; the isolated `UserDefaults` suite is cleaned up. The test cannot contact Slack, read or write Keychain, toggle system DND, or run Shortcuts.
- Slice 5 test-only RED: Added `SlackOperationStateTests.connectionTestIgnoresDuplicateInvocationWhileWorking`. It calls `testConnection()` twice without completing the first request and requires exactly one total and one pending `/api/auth.test` request. The recording transport remains fully inert. No production, UI, or localization change was made; the duplicate-invocation production fix is intentionally deferred.
- Slice 5 local RED attempt: `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-slice5-red -only-testing:FocallyTests/SlackOperationStateTests/connectionTestIgnoresDuplicateInvocationWhileWorking` exited 65 before test execution because `swift-plugin-server` could not load `ObservationMacros` and produced malformed responses. This is an environment-blocked attempt, not a claimed behavioral RED execution. On the verified host, the test is expected to fail because the current `testConnection()` launches `validateToken()` again while state is already `.working`, recording two total and two pending `/api/auth.test` requests.
- Slice 5 host RED: `connectionTestIgnoresDuplicateInvocationWhileWorking` was verified failing because two calls to `testConnection()` launched two `auth.test` requests.
- Slice 5 production: `SlackService.testConnection()` now exits immediately only when `connectionTestState == .working`. The guard does not cover `.idle`, `.success`, or `.failed`, so a later invocation after any terminal result still starts a fresh request and enters `.working`.
- Slice 5 local GREEN attempt: `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-derived-slice5-green -only-testing:FocallyTests/SlackOperationStateTests/connectionTestIgnoresDuplicateInvocationWhileWorking` exited 65 before test execution because `swift-plugin-server` could not load `ObservationMacros` and produced malformed responses. No local runtime GREEN is claimed.
- Final scope: UI and EN/ES/PT localization are complete. `git diff --check` passed. No host full-suite or Release validation is claimed. No commit, push, tag, or release was performed.
- TASK-052 review follow-up (2026-08-10): the test initializer now accepts `enabled` and initializes it without triggering `isEnabled.didSet`; the focus-status test no longer mutates `isEnabled` after construction, and an inert serialized test preserves/restores `UserDefaults.standard.slackEnabled` while proving construction does not persist it. The test-token override is tri-state, so an explicitly injected `nil` cannot fall back to Keychain.
- TASK-052 review follow-up: `testConnection()` now enters `.working` immediately after its duplicate-operation guard and before token validation. An inert explicit-`nil` token test verifies the terminal `.failed("No token configured")` result and that no request is launched.
- TASK-052 review follow-up: `operationFeedback` localizes every static error emitted by `testConnection` and the completion-bearing `setStatus`, including network/API dynamic-prefix variants while retaining their detail. Matching EN/ES/PT keys were added, with unit coverage for every exact mapping and both dynamic formats.
- TASK-052 review verification: the focused `SlackOperationStateTests` command exited 65 before test execution because `swift-plugin-server` could not load `ObservationMacros` and returned malformed responses across existing observable types. No runtime GREEN is claimed from this environment. `git diff --check` passed. No real network or Keychain path was used, and no commit was created.
- TASK-052 host-failure follow-up (2026-08-10): `SlackService` now injects the `UserDefaults` used only by `isEnabled.didSet`; production uses `.standard`, while tests can supply an isolated suite. The initializer regression test uses a UUID-named suite, a local sentinel, and persistent-domain cleanup to prove initialization adopts `enabled` without persisting it. It never reads or writes `UserDefaults.standard`, Keychain, or the network.
- TASK-052 host-failure verification: the focused `testInitializerDoesNotPersistEnabledToStandardDefaults` command exited 65 before test execution because the sandbox rejected `swift-plugin-server` and `ObservationMacros` produced malformed responses across existing observable types. No runtime GREEN is claimed; the final `git diff --check` passed.
- TASK-052 defaults-initialization follow-up (2026-08-10): `SlackService` now explicitly suppresses `isEnabled.didSet` persistence only around the initial assignment in both production and test initializers. The isolated-defaults regression test retains its sentinel assertion and additionally verifies that a post-init `isEnabled` change persists to the injected suite.
- TASK-052 defaults-initialization verification: the focused `testInitializerDoesNotPersistEnabledToStandardDefaults` command exited 65 before test execution because the sandboxed `swift-plugin-server` could not load `ObservationMacros`/`ObservationIgnoredMacro` and returned malformed responses. No runtime GREEN is claimed; `git diff --check` passed.
- TASK-052 final HIGH follow-up (2026-08-10): `SlackService.setStatus` now records emoji usage through an injected closure. The production initializer preserves the prior asynchronous `EmojiUsageTracker.shared.recordUsage` behavior exactly, while the test initializer defaults to a no-op. `focusStatusTestCompletesOnlyFromStatusResponse` therefore cannot mutate `emojiUsageHistory` or `UserDefaults.standard`; no TASK-052 test accesses either singleton.
- TASK-052 final HIGH coverage: added the inert `setStatusReportsEmojiUsageThroughInjectedRecorder` seam test, which records into a local array and verifies the normalized emoji plus the synthetic request without reading or writing standard defaults.
- TASK-052 final HIGH verification: `rg` found no `EmojiUsageTracker.shared`, `UserDefaults.standard`, or `emojiUsageHistory` reference in `SlackOperationStateTests`. The focused `xcodebuild test -quiet -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -derivedDataPath /tmp/focally-task052-final-high -only-testing:FocallyTests/SlackOperationStateTests` attempt exited 65 before test execution because `swift-plugin-server` could not load `ObservationMacros`/`ObservationIgnoredMacro` and returned malformed responses across existing observable types. No runtime GREEN is claimed.
