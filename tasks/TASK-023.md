# TASK-023: Add Unit Tests

## Status: TODO

## Date: 2026-05-01

## Objective
Focally has zero tests. The services (`FocusTimerService`, `SoundPlayerService`, `HistoryService`) are well-structured for testing after the v0.5.0 refactoring. Add a test target and core unit tests using Swift Testing framework (`@Test`, `#expect`).

## Files to Create
- Test target: `FocallyTests` (configured in `project.yml`)
- `FocallyTests/FocusTimerServiceTests.swift`
- `FocallyTests/SoundPlayerServiceTests.swift`
- `FocallyTests/HistoryServiceTests.swift`
- `FocallyTests/DNDServiceTests.swift`
- `FocallyTests/Models/PomodoroStateTests.swift`

## project.yml Changes

Add test target:

```yaml
targets:
  FocallyTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - FocallyTests
    dependencies:
      - target: Focally
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.focally.mac.tests
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        SWIFT_VERSION: "5.9"
```

## Detailed Test Specifications

### FocusTimerServiceTests

```swift
import Testing
@testable import Focally

@Suite("FocusTimerService")
struct FocusTimerServiceTests {
    
    @Test("Initial state is idle")
    func initialState() {
        let service = makeService()
        #expect(service.pomodoroState == .idle)
        #expect(service.isActive == false)
        #expect(service.isPaused == false)
        #expect(service.currentRound == 0)
    }
    
    @Test("Start work session sets correct state")
    func startWorkSession() {
        let service = makeService()
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        
        #expect(service.pomodoroState == .work)
        #expect(service.isActive == true)
        #expect(service.isPaused == false)
        #expect(service.remainingSeconds == 25 * 60)
        #expect(service.currentActivity == "Test")
        #expect(service.currentEmoji == "📝")
    }
    
    @Test("Pause and resume")
    func pauseResume() {
        let service = makeService()
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        
        service.pauseSession()
        #expect(service.isPaused == true)
        #expect(service.isActive == true)
        
        service.resumeSession()
        #expect(service.isPaused == false)
        #expect(service.isActive == true)
    }
    
    @Test("Reset to idle clears state")
    func resetToIdle() {
        let service = makeService()
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        service.resetToIdle()
        
        #expect(service.pomodoroState == .idle)
        #expect(service.isActive == false)
        #expect(service.remainingSeconds == 0)
        #expect(service.currentRound == 0)
    }
    
    @Test("Skip from work to break")
    func skipFromWorkToBreak() {
        let service = makeService()
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        service.skipToNextPhase()
        
        #expect(service.pomodoroState == .shortBreak)
        #expect(service.currentRound == 1)
    }
    
    @Test("Skip reaches long break after configured rounds")
    func skipToLongBreak() {
        let service = makeService()
        service.roundsUntilLongBreak = 2
        
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        service.skipToNextPhase() // round 1 → short break
        service.skipToNextPhase() // back to work
        service.skipToNextPhase() // round 2 → long break
        
        #expect(service.pomodoroState == .longBreak)
    }
    
    @Test("Progress calculation")
    func progressCalculation() {
        let service = makeService()
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        
        #expect(service.progress == 0.0)
        
        service.remainingSeconds = 24 * 60 // 1 minute elapsed
        #expect(service.progress == 1.0 / 25.0)
        
        service.remainingSeconds = 0
        #expect(service.progress == 1.0)
    }
    
    @Test("Remaining time string formatting")
    func timeStringFormatting() {
        let service = makeService()
        service.remainingSeconds = 25 * 60
        #expect(service.remainingTimeString == "25:00")
        
        service.remainingSeconds = 5 * 60 + 30
        #expect(service.remainingTimeString == "5:30")
        
        service.remainingSeconds = 59
        #expect(service.remainingTimeString == "0:59")
    }
    
    @Test("State icons")
    func stateIcons() {
        let service = makeService()
        #expect(service.stateIcon == "⏸️") // idle
        
        service.startWorkSession(activity: "Test", emoji: "📝", durationMinutes: 25)
        #expect(service.stateIcon == "🟢") // work
    }
    
    // Helper to create service without side effects
    private func makeService() -> FocusTimerService {
        FocusTimerService(
            soundPlayer: SoundPlayerService.shared,
            notificationService: NotificationService(),
            historyService: HistoryService.shared
        )
    }
}
```

### SoundPlayerServiceTests

```swift
@Suite("SoundPlayerService")
struct SoundPlayerServiceTests {
    
    @Test("Sound list is not empty")
    func soundListNotEmpty() {
        let service = SoundPlayerService.shared
        #expect(!service.sounds.isEmpty)
    }
    
    @Test("Sound list contains expected system sounds")
    func soundListContainsExpected() {
        let service = SoundPlayerService.shared
        #expect(service.sounds.contains("Basso"))
        #expect(service.sounds.contains("Glass"))
        #expect(service.sounds.contains("Ping"))
        #expect(service.sounds.contains("Hero"))
    }
    
    @Test("resolveSoundName returns correct sounds")
    func resolveSoundName() {
        let service = SoundPlayerService.shared
        // Note: verify current logic — may need adjustment if M1 is fixed
        let workEnd = service.resolveSoundName(for: .workEnd)
        let breakEnd = service.resolveSoundName(for: .breakEnd)
        let longBreakEnd = service.resolveSoundName(for: .longBreakEnd)
        
        #expect(!workEnd.isEmpty)
        #expect(!breakEnd.isEmpty)
        #expect(!longBreakEnd.isEmpty)
    }
    
    @Test("soundURL returns valid URL for known sounds")
    func soundURLValid() {
        let service = SoundPlayerService.shared
        for sound in service.sounds {
            let url = service.soundURL(for: sound)
            #expect(url != nil, "Sound URL for \(sound) should not be nil")
        }
    }
    
    @Test("soundURL returns nil for unknown sound")
    func soundURLUnknown() {
        let service = SoundPlayerService.shared
        #expect(service.soundURL(for: "NonExistentSound") == nil)
    }
}
```

### HistoryServiceTests

```swift
@Suite("HistoryService")
struct HistoryServiceTests {
    
    @Test("Load sessions for empty date returns empty array")
    func loadEmptyDate() {
        let service = HistoryService.shared
        // Use a date far in the past with no data
        let date = Date.distantPast
        let sessions = service.loadSessions(for: date)
        #expect(sessions.isEmpty)
    }
    
    @Test("SessionEntry is Codable")
    func sessionEntryCodable() throws {
        let entry = HistoryService.SessionEntry(
            id: UUID(),
            activity: "Testing",
            emoji: "🧪",
            durationMinutes: 25,
            startTime: Date(),
            endTime: Date().addingTimeInterval(25 * 60),
            round: 1
        )
        
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryService.SessionEntry.self, from: data)
        
        #expect(decoded.activity == entry.activity)
        #expect(decoded.emoji == entry.emoji)
        #expect(decoded.durationMinutes == entry.durationMinutes)
        #expect(decoded.round == entry.round)
    }
    
    @Test("Record and load session")
    func recordAndLoad() {
        let service = HistoryService.shared
        let activity = "UnitTest-\(UUID().uuidString.prefix(8))"
        
        service.recordWorkSession(
            activity: activity,
            emoji: "🧪",
            durationMinutes: 1,
            round: 0,
            startTime: Date(),
            endTime: Date()
        )
        
        let sessions = service.loadTodaySessions()
        let recorded = sessions.last { $0.activity == activity }
        #expect(recorded != nil)
        #expect(recorded?.durationMinutes == 1)
    }
}
```

### PomodoroStateTests

```swift
@Suite("PomodoroState")
struct PomodoroStateTests {
    
    @Test("All cases have raw values")
    func rawValues() {
        #expect(PomodoroState.idle.rawValue == "idle")
        #expect(PomodoroState.work.rawValue == "work")
        #expect(PomodoroState.shortBreak.rawValue == "shortBreak")
        #expect(PomodoroState.longBreak.rawValue == "longBreak")
        #expect(PomodoroState.completed.rawValue == "completed")
    }
    
    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(PomodoroState(rawValue: "work") == .work)
        #expect(PomodoroState(rawValue: "invalid") == nil)
    }
}
```

## Acceptance Criteria
- [ ] `FocallyTests` target added to `project.yml`
- [ ] `FocusTimerServiceTests` — 9+ tests covering state transitions, progress, formatting
- [ ] `SoundPlayerServiceTests` — 5 tests covering sound list, URL resolution
- [ ] `HistoryServiceTests` — 3 tests covering loading, recording, codable
- [ ] `PomodoroStateTests` — 2 tests covering raw values
- [ ] All tests pass: `xcodebuild test -scheme Focally -destination 'platform=macOS'`
- [ ] Build succeeds

## Notes
- Tests that create `FocusTimerService` may have side effects (UserDefaults writes, history files). Consider adding cleanup in `defer` blocks.
- `HistoryServiceTests.recordAndLoad` writes to the real history directory — acceptable for now, but ideally we'd inject a temp directory.
- Sound tests don't verify actual playback (system-dependent) — only configuration.

## Priority
**v0.6.0** — Testing infrastructure is foundational
