import XCTest
@testable import Focally

@MainActor
final class CalendarMetricsTrackerTests: XCTestCase {
    private let occurrence = Date(timeIntervalSince1970: 2_000_000_000)

    func testDraftPersistenceRoundTripAndInvalidPayloadClearing() throws {
        let now = occurrence.addingTimeInterval(60)
        let store = FakeCalendarDraftDataStore()
        let persistence = UserDefaultsCalendarMetricsDraftPersistence(store: store, now: { now })
        let draft = makeDraft(savedAt: now)
        persistence.save(draft)
        XCTAssertEqual(persistence.load(), draft)

        store.value = Data("not json".utf8)
        XCTAssertNil(persistence.load())
        XCTAssertNil(store.value)
    }

    func testFutureNegativeNonFiniteAndStaleDraftsAreRejected() {
        let now = occurrence.addingTimeInterval(60)
        var draft = makeDraft(savedAt: now)
        draft.schemaVersion = 2
        XCTAssertFalse(draft.isValid(at: now))
        draft = makeDraft(savedAt: now)
        draft.accumulatedObservedSeconds = -1
        XCTAssertFalse(draft.isValid(at: now))
        draft.accumulatedObservedSeconds = .infinity
        XCTAssertFalse(draft.isValid(at: now))
        draft = makeDraft(savedAt: now.addingTimeInterval(-8 * 86_400))
        XCTAssertFalse(draft.isValid(at: now))
    }

    func testDraftRejectsObservationEndpointAfterSaveTime() {
        let now = occurrence.addingTimeInterval(60)
        var draft = makeDraft(savedAt: now)
        draft.lastObservedAt = now.addingTimeInterval(1)

        XCTAssertFalse(draft.isValid(at: now))
    }

    func testPersistenceLoadClearsFutureObservationEndpointBeforeItCanBecomeMetrics() throws {
        let now = occurrence.addingTimeInterval(60)
        let store = FakeCalendarDraftDataStore()
        let persistence = UserDefaultsCalendarMetricsDraftPersistence(store: store, now: { now })
        let metrics = FakeCalendarMetricsRecorder()
        var draft = makeDraft(savedAt: now)
        draft.recordID = CalendarMetricsTracker.recordID(
            meetingID: draft.meetingID,
            occurrenceStart: draft.occurrenceStart
        )
        draft.lastObservedAt = now.addingTimeInterval(1)
        persistence.save(draft)

        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: { now })
        tracker.finishBecauseMonitoringStopped()

        XCTAssertNil(store.value)
        XCTAssertTrue(metrics.sessions.isEmpty)
    }

    func testCalendarReadEligibilityRequiresEnabledFullAccess() {
        XCTAssertTrue(CalendarSlackIntegrationService.canReadCalendar(
            isEnabled: true,
            authorizationStatus: .fullAccess
        ))
        XCTAssertFalse(CalendarSlackIntegrationService.canReadCalendar(
            isEnabled: false,
            authorizationStatus: .fullAccess
        ))
        XCTAssertFalse(CalendarSlackIntegrationService.canReadCalendar(
            isEnabled: true,
            authorizationStatus: .denied
        ))
    }

    func testPresenceTransitionRequiresObservableMeetingChange() {
        let original = CalendarMeeting(
            id: "recurring",
            title: "Planning",
            startTime: occurrence,
            endTime: occurrence.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: true
        )
        let changedEnd = CalendarMeeting(
            id: "recurring",
            title: "Planning",
            startTime: occurrence,
            endTime: occurrence.addingTimeInterval(5_400),
            isAllDay: false,
            hasVideoCall: true
        )

        XCTAssertFalse(CalendarSlackIntegrationService.isPresenceTransition(
            currentMeeting: nil,
            nextMeeting: nil
        ))
        XCTAssertFalse(CalendarSlackIntegrationService.isPresenceTransition(
            currentMeeting: original,
            nextMeeting: original
        ))
        XCTAssertTrue(CalendarSlackIntegrationService.isPresenceTransition(
            currentMeeting: original,
            nextMeeting: changedEnd
        ))
        XCTAssertTrue(CalendarSlackIntegrationService.isPresenceTransition(
            currentMeeting: original,
            nextMeeting: nil
        ))
    }

    func testActiveMeetingUsesHalfOpenIntervalAndExcludesAllDayEvents() {
        let active = CalendarMeeting(
            id: "active",
            title: "Active",
            startTime: occurrence,
            endTime: occurrence.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: false
        )
        let allDay = CalendarMeeting(
            id: "all-day",
            title: "All day",
            startTime: occurrence.addingTimeInterval(-3_600),
            endTime: occurrence.addingTimeInterval(7_200),
            isAllDay: true,
            hasVideoCall: false
        )

        XCTAssertEqual(
            CalendarSlackIntegrationService.activeMeeting(at: occurrence, in: [allDay, active]),
            active
        )
        XCTAssertEqual(
            CalendarSlackIntegrationService.activeMeeting(
                at: occurrence.addingTimeInterval(3_599),
                in: [active]
            ),
            active
        )
        XCTAssertNil(CalendarSlackIntegrationService.activeMeeting(
            at: occurrence.addingTimeInterval(3_600),
            in: [active]
        ))
    }

    func testOverlappingActiveMeetingsSelectFirstSourceOrderedEvent() {
        let first = CalendarMeeting(
            id: "first",
            title: "First",
            startTime: occurrence.addingTimeInterval(-600),
            endTime: occurrence.addingTimeInterval(1_800),
            isAllDay: false,
            hasVideoCall: false
        )
        let second = CalendarMeeting(
            id: "second",
            title: "Second",
            startTime: occurrence.addingTimeInterval(-300),
            endTime: occurrence.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: true
        )

        XCTAssertEqual(
            CalendarSlackIntegrationService.activeMeeting(at: occurrence, in: [first, second]),
            first
        )
    }

    func testFirstObservationAndBoundedAccumulationThenFinalization() {
        let clock = FakeCalendarClock(Date(timeIntervalSince1970: 2_000_000_010))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        let meeting = makeMeeting()

        tracker.observeActiveMeeting(meeting)
        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 0)
        XCTAssertTrue(metrics.sessions.isEmpty)

        clock.advance(30)
        tracker.observeActiveMeeting(meeting)
        clock.advance(30)
        tracker.observeNoActiveMeeting()

        XCTAssertNil(persistence.draft)
        XCTAssertEqual(metrics.sessions.single?.duration, 60)
        XCTAssertEqual(metrics.sessions.single?.activeDuration, 60)
        XCTAssertEqual(metrics.sessions.single?.startTime, Date(timeIntervalSince1970: 2_000_000_010))
        XCTAssertEqual(metrics.sessions.single?.endTime, Date(timeIntervalSince1970: 2_000_000_070))
        XCTAssertEqual(metrics.sessions.single?.source, .calendar)
        XCTAssertNil(metrics.sessions.single?.pomodorosCompleted)
        XCTAssertEqual(metrics.sessions.single?.pausedDuration, 0)
        XCTAssertEqual(metrics.sessions.single?.breakDuration, 0)
    }

    func testLongGapAndTerminationDoNotClaimUnobservedTime() {
        let clock = FakeCalendarClock(Date(timeIntervalSince1970: 2_000_000_010))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        let meeting = makeMeeting()
        tracker.observeActiveMeeting(meeting)
        clock.advance(120)
        tracker.observeActiveMeeting(meeting)
        clock.advance(30)
        tracker.prepareForTermination()

        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 30)
        XCTAssertEqual(persistence.draft?.isObservationActive, false)
        XCTAssertTrue(metrics.sessions.isEmpty)
    }

    func testShortSystemSleepBelowMaximumGapIsExcluded() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(
            persistence: persistence, metrics: metrics, now: clock.now, maximumObservationGap: 90
        )
        let meeting = makeMeeting()

        tracker.observeActiveMeeting(meeting)
        clock.advance(30)
        tracker.prepareForSystemSleep()
        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 30)
        XCTAssertEqual(persistence.draft?.isObservationActive, false)

        clock.advance(60)
        tracker.observeActiveMeeting(meeting)
        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 30)
        XCTAssertEqual(persistence.draft?.isObservationActive, true)

        clock.advance(30)
        tracker.observeNoActiveMeeting()
        XCTAssertEqual(metrics.sessions.single?.duration, 60)
    }

    func testRecoveredActiveDraftIsSuspendedAndOfflineGapIsExcluded() {
        let clock = FakeCalendarClock(Date(timeIntervalSince1970: 2_000_000_010))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        var tracker: CalendarMetricsTracker? = CalendarMetricsTracker(
            persistence: persistence, metrics: metrics, now: clock.now
        )
        let meeting = makeMeeting()
        tracker?.observeActiveMeeting(meeting)
        clock.advance(30)
        tracker?.observeActiveMeeting(meeting)
        tracker = nil
        clock.advance(300)

        tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        XCTAssertEqual(persistence.draft?.isObservationActive, false)
        tracker?.observeActiveMeeting(meeting)
        clock.advance(30)
        tracker?.observeNoActiveMeeting()
        XCTAssertEqual(metrics.sessions.single?.duration, 60)
    }

    func testTerminationThenRelaunchResumesWithoutOfflineDelta() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let meeting = makeMeeting()
        var tracker: CalendarMetricsTracker? = CalendarMetricsTracker(
            persistence: persistence, metrics: metrics, now: clock.now
        )

        tracker?.observeActiveMeeting(meeting)
        clock.advance(20)
        tracker?.prepareForTermination()
        tracker = nil
        clock.advance(60)

        tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        tracker?.observeActiveMeeting(meeting)
        clock.advance(20)
        tracker?.observeNoActiveMeeting()

        XCTAssertEqual(metrics.sessions.single?.duration, 40)
    }

    func testSwitchFinalizesOldAndStartsEligibleNewMeeting() {
        let clock = FakeCalendarClock(Date(timeIntervalSince1970: 2_000_000_010))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        tracker.observeActiveMeeting(makeMeeting(id: "one"))
        clock.advance(10)
        let second = makeMeeting(id: "two", start: occurrence.addingTimeInterval(5))
        tracker.observeActiveMeeting(second)
        XCTAssertEqual(metrics.sessions.single?.duration, 10)
        XCTAssertEqual(persistence.draft?.meetingID, "two")
        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 0)
    }

    func testIneligibleMeetingsNeverCreateDrafts() {
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: { self.occurrence })
        tracker.observeActiveMeeting(makeMeeting(video: false))
        XCTAssertNil(persistence.draft)
        tracker.observeActiveMeeting(makeMeeting(allDay: true))
        XCTAssertNil(persistence.draft)
        XCTAssertTrue(metrics.sessions.isEmpty)
    }

    func testBelowFiveSecondsIsDiscarded() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        tracker.observeActiveMeeting(makeMeeting())
        clock.advance(4.999)
        tracker.observeNoActiveMeeting()
        XCTAssertTrue(metrics.sessions.isEmpty)
        XCTAssertNil(persistence.draft)
    }

    func testDeterministicIdentityDiffersForRecurringOccurrence() {
        let first = CalendarMetricsTracker.recordID(meetingID: "recurring", occurrenceStart: occurrence)
        let same = CalendarMetricsTracker.recordID(meetingID: "recurring", occurrenceStart: occurrence)
        let next = CalendarMetricsTracker.recordID(
            meetingID: "recurring", occurrenceStart: occurrence.addingTimeInterval(86_400)
        )
        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, next)
        XCTAssertEqual((first.uuid.6 & 0xF0), 0x50)
        XCTAssertEqual((first.uuid.8 & 0xC0), 0x80)
    }

    func testTransientReentrySeedsCompletedRecordAndAccumulatesOneID() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        let meeting = makeMeeting()
        tracker.observeActiveMeeting(meeting)
        clock.advance(10)
        tracker.observeNoActiveMeeting()
        clock.advance(10)
        tracker.observeActiveMeeting(meeting)
        clock.advance(10)
        tracker.observeNoActiveMeeting()
        XCTAssertEqual(metrics.sessions.count, 1)
        XCTAssertEqual(metrics.sessions.single?.duration, 20)
        XCTAssertEqual(metrics.sessions.single?.startTime, occurrence.addingTimeInterval(10))
    }

    func testMonitoringStoppedAddsFinalBoundedInterval() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(
            persistence: persistence, metrics: metrics, now: clock.now, maximumObservationGap: 90
        )
        tracker.observeActiveMeeting(makeMeeting())
        clock.advance(30)
        tracker.finishBecauseMonitoringStopped()
        XCTAssertEqual(metrics.sessions.single?.duration, 30)
        XCTAssertEqual(metrics.sessions.single?.endTime, occurrence.addingTimeInterval(40))
        XCTAssertNil(persistence.draft)
    }

    func testMonitoringStoppedDoesNotAddLongGap() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(10))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)
        tracker.observeActiveMeeting(makeMeeting())
        clock.advance(30)
        tracker.observeActiveMeeting(makeMeeting())
        clock.advance(300)
        tracker.finishBecauseMonitoringStopped()
        XCTAssertEqual(metrics.sessions.single?.duration, 30)
        XCTAssertNil(persistence.draft)
    }

    func testRecoveredDraftWithMismatchedRecordIDIsClearedWithoutFinalization() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(60))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        persistence.draft = makeDraft(savedAt: clock.value)

        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)

        XCTAssertNil(persistence.draft)
        tracker.observeActiveMeeting(makeMeeting())
        clock.advance(10)
        tracker.observeNoActiveMeeting()
        XCTAssertEqual(metrics.sessions.count, 1)
        XCTAssertEqual(
            metrics.sessions.single?.id,
            CalendarMetricsTracker.recordID(meetingID: "meeting", occurrenceStart: occurrence)
        )
    }

    func testSuspendedRecoveredDraftFinalizesOnlyPreviouslyAccumulatedTimeWhenMonitoringIsDisabled() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(60))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        var recovered = makeDraft(savedAt: clock.value)
        recovered.recordID = CalendarMetricsTracker.recordID(
            meetingID: recovered.meetingID, occurrenceStart: recovered.occurrenceStart
        )
        persistence.draft = recovered
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)

        tracker.finishBecauseMonitoringStopped()

        XCTAssertEqual(metrics.sessions.single?.duration, 30)
        XCTAssertEqual(metrics.sessions.single?.endTime, occurrence.addingTimeInterval(40))
        XCTAssertNil(persistence.draft)
    }

    func testSuspendedRecoveredDraftResumesAtCurrentTimeWithoutAddingOfflineInterval() {
        let clock = FakeCalendarClock(occurrence.addingTimeInterval(60))
        let persistence = FakeCalendarDraftPersistence()
        let metrics = FakeCalendarMetricsRecorder()
        var recovered = makeDraft(savedAt: clock.value)
        recovered.recordID = CalendarMetricsTracker.recordID(
            meetingID: recovered.meetingID, occurrenceStart: recovered.occurrenceStart
        )
        persistence.draft = recovered
        let tracker = CalendarMetricsTracker(persistence: persistence, metrics: metrics, now: clock.now)

        tracker.observeActiveMeeting(makeMeeting())

        XCTAssertEqual(persistence.draft?.accumulatedObservedSeconds, 30)
        XCTAssertEqual(persistence.draft?.lastObservedAt, occurrence.addingTimeInterval(60))
        XCTAssertEqual(persistence.draft?.isObservationActive, true)
        XCTAssertTrue(metrics.sessions.isEmpty)
    }

    private func makeMeeting(
        id: String = "meeting", start: Date? = nil, allDay: Bool = false, video: Bool = true
    ) -> CalendarMeeting {
        CalendarMeeting(id: id, title: "Call", startTime: start ?? occurrence,
                        endTime: occurrence.addingTimeInterval(3_600), isAllDay: allDay, hasVideoCall: video)
    }

    private func makeDraft(savedAt: Date) -> PersistedCalendarMetricsDraft {
        PersistedCalendarMetricsDraft(recordID: UUID(), meetingID: "meeting", occurrenceStart: occurrence,
            scheduledEnd: occurrence.addingTimeInterval(3_600), firstObservedAt: occurrence.addingTimeInterval(10),
            lastObservedAt: occurrence.addingTimeInterval(40), accumulatedObservedSeconds: 30,
            isObservationActive: true, savedAt: savedAt)
    }
}

@MainActor private final class FakeCalendarClock {
    var value: Date
    init(_ value: Date) { self.value = value }
    func now() -> Date { value }
    func advance(_ seconds: TimeInterval) { value = value.addingTimeInterval(seconds) }
}

@MainActor private final class FakeCalendarDraftPersistence: CalendarMetricsDraftPersisting {
    var draft: PersistedCalendarMetricsDraft?
    func load() -> PersistedCalendarMetricsDraft? { draft }
    func save(_ draft: PersistedCalendarMetricsDraft) { self.draft = draft }
    func clear() { draft = nil }
}

@MainActor private final class FakeCalendarMetricsRecorder: CalendarMetricsRecording {
    var sessions: [FocusSessionRecord] = []
    func upsertSession(_ session: FocusSessionRecord) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) { sessions[index] = session }
        else { sessions.append(session) }
    }
    func session(withID id: UUID) -> FocusSessionRecord? { sessions.first { $0.id == id } }
}

private final class FakeCalendarDraftDataStore: CalendarMetricsDraftDataStoring {
    var value: Data?
    func data(forKey key: String) -> Data? { value }
    func set(_ value: Any?, forKey key: String) { self.value = value as? Data }
    func removeObject(forKey key: String) { value = nil }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
