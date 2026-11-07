# TASK-061 STATUS

## Scope shipped

Ticker efficiency: 1 Hz UI updates anchored to the wall clock with tolerance; UI derived from the clock, not tick counts.

- **`SecondAnchoredTimer`** (new, `Sources/Focally/Services/SecondAnchoredTimer.swift`) — shared helper: first fire on the next integral wall-clock second (`Timer(fire:interval:repeats:)`), interval 1 s, `tolerance = 0.1`, added to main runloop in `.common` mode. Consolidates both 1 Hz tickers.
  - **Full consolidation achieved in both sites** (no per-site leftover): `FoundationFocusTimerTicker` (`Services/FocusTimerTicker.swift`) now delegates to it, and `OnItFocusApp.startStatusBarUpdates` uses a `SecondAnchoredTimer` instance instead of a bare `Timer.scheduledTimer`.
- **`StatusTitleAssigner`** (new, `Sources/Focally/Services/StatusTitleAssigner.swift`) — assigns the status-bar button title ONLY when the desired string changes (returns nil on no-change). Wired into `updateStatusBar()` for both the session-title and empty states; `reset()` is called in `setupStatusBar()` so a recreated button always gets an initial assignment. This removes redundant AppKit title writes on every 1 Hz tick.
- **Reconciliation by clock already existed** (`derivedRemaining(at:)` in `FocusTimerService`, Date-based) — untouched; the tolerance/anchoring change is safe because remaining time is never tick-count-derived.

## Test results

`xcodebuild test -scheme Focally -destination 'platform=macOS'` (after `xcodegen generate`):
**288/288 passed, TEST SUCCEEDED** — 190 XCTest tests (incl. new `StatusTitleAssignerTests` ×2 and `testFirstTickAfterWakeWithPastTargetShowsCorrectRemaining` in `FocusTimerServiceTests`) + 98 Swift Testing tests. 0 failures, no regressions.

## New tests

1. `StatusTitleAssignerTests.testAssignsOnlyWhenStringChanges` — first assignment applies, identical strings return nil, any change (incl. →empty) re-assigns.
2. `StatusTitleAssignerTests.testResetForcesNextAssignment`.
3. `FocusTimerServiceTests.testFirstTickAfterWakeWithPastTargetShowsCorrectRemaining` — post-sleep with phase target in the past: reconcile advances to break (59 s), first ticker fire shows clock-derived 58 s.

## Deviations

- `xcodegen generate` was required for the new files to enter the project (project.yml uses directory globs); the regenerated `Focally.xcodeproj` is part of the commit.
- The plan allowed leaving `FoundationFocusTimerTicker` with per-site tolerance if consolidation was too invasive; full consolidation via the shared helper was cleanly possible, so both tickers now share `SecondAnchoredTimer`.
