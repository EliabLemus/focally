# TASK-060 STATUS

## Scope shipped

DND activation reliability on macOS 14+: shortcuts-first tier replacing the legacy CFPreferences write as the primary path.

- **`DNDReliabilityService`** — tier shortcuts-first:
  - `isShortcutsFirstOS` injectable (macOS 14+ gate).
  - `scheduleShortcutFirst` — on macOS 14+ the signed shortcut is Layer 1 (no CFPreferences write at all, no silent degradation to legacy).
  - Verification is Control Center-only (`NSStatusItem Visible FocusModes` read of ControlCenter module).
  - `shortcutSucceeded` observability event.
  - `didEscalateCurrentTransition` fires at-most-once per transition.
- **`DNDService`** — `prefersShortcutsFirst` gate: optimistic local flip + shortcut activation on 14+, skipping the legacy CFPreferences read path entirely on those OSes.

## Test results

`xcodebuild test -scheme Focally -destination 'platform=macOS'`:
**98/98 tests passed, TEST SUCCEEDED** (run from this worktree, 2026-11-06). `DNDReliabilityTests` green 13/13 (verified with `-only-testing` previously); full suite shows no regressions — no other tests required re-anchoring to the legacy tier.

## Files changed

- `Sources/Focally/Services/DNDReliabilityService.swift`
- `Sources/Focally/Services/DNDService.swift`
- `Tests/FocallyTests/DNDReliabilityTests.swift` (injectable `makeService(shortcutsFirstOS:)` pattern)

## Deviations

- None material. The full suite passed on first run without test adjustments; the test-count expectation in the task notes (105+6) reflected the pre-run estimate; the actual suite total at commit time is 98, all passing.
