import CryptoKit
import Foundation

@MainActor
protocol CalendarMetricsDraftPersisting: AnyObject {
    func load() -> PersistedCalendarMetricsDraft?
    func save(_ draft: PersistedCalendarMetricsDraft)
    func clear()
}

protocol CalendarMetricsDraftDataStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: CalendarMetricsDraftDataStoring {}

@MainActor
final class UserDefaultsCalendarMetricsDraftPersistence: CalendarMetricsDraftPersisting {
    static let key = "focally.metrics.calendarDraft"
    private let store: CalendarMetricsDraftDataStoring
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        store = defaults
        self.now = now
    }

    init(store: CalendarMetricsDraftDataStoring, now: @escaping () -> Date) {
        self.store = store
        self.now = now
    }

    func load() -> PersistedCalendarMetricsDraft? {
        guard let data = store.data(forKey: Self.key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let draft = try? decoder.decode(PersistedCalendarMetricsDraft.self, from: data),
              draft.isValid(at: now()) else {
            clear()
            return nil
        }
        return draft
    }

    func save(_ draft: PersistedCalendarMetricsDraft) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(draft) else { return }
        store.set(data, forKey: Self.key)
    }

    func clear() {
        store.removeObject(forKey: Self.key)
    }
}

@MainActor
protocol CalendarMetricsRecording: AnyObject {
    func upsertSession(_ session: FocusSessionRecord)
    func session(withID id: UUID) -> FocusSessionRecord?
}

@MainActor
final class CalendarMetricsTracker {
    private let persistence: CalendarMetricsDraftPersisting
    private let metrics: CalendarMetricsRecording
    private let now: () -> Date
    private let maximumObservationGap: TimeInterval
    private var draft: PersistedCalendarMetricsDraft?

    init(
        persistence: CalendarMetricsDraftPersisting,
        metrics: CalendarMetricsRecording,
        now: @escaping () -> Date = Date.init,
        maximumObservationGap: TimeInterval = 90
    ) {
        self.persistence = persistence
        self.metrics = metrics
        self.now = now
        self.maximumObservationGap = maximumObservationGap
        if var recovered = persistence.load(),
           recovered.isValid(at: now()),
           recovered.recordID == Self.recordID(
               meetingID: recovered.meetingID,
               occurrenceStart: recovered.occurrenceStart
           ) {
            recovered.isObservationActive = false
            recovered.savedAt = now()
            draft = recovered
            persistence.save(recovered)
        } else {
            persistence.clear()
        }
    }

    func observeActiveMeeting(_ meeting: CalendarMeeting) {
        guard meeting.hasVideoCall,
              !meeting.isAllDay,
              !meeting.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              meeting.endTime >= meeting.startTime else {
            observeNoActiveMeeting()
            return
        }
        let timestamp = now()
        let id = Self.recordID(meetingID: meeting.id, occurrenceStart: meeting.startTime)
        if let existing = draft,
           existing.recordID == id,
           existing.meetingID == meeting.id,
           existing.occurrenceStart == meeting.startTime {
            updateCurrent(at: timestamp, remainsActive: true, addFinalDelta: true)
            return
        }
        if draft != nil {
            finalize(at: timestamp, addFinalDelta: true)
        }
        start(meeting, recordID: id, at: timestamp)
    }

    func observeNoActiveMeeting() {
        finalize(at: now(), addFinalDelta: true)
    }

    func prepareForTermination() {
        suspendObservationAtLifecycleBoundary()
    }

    func prepareForSystemSleep() {
        suspendObservationAtLifecycleBoundary()
    }

    private func suspendObservationAtLifecycleBoundary() {
        guard draft != nil else { return }
        updateCurrent(at: now(), remainsActive: false, addFinalDelta: true)
    }

    func finishBecauseMonitoringStopped() {
        finalize(at: now(), addFinalDelta: true)
    }

    private func start(_ meeting: CalendarMeeting, recordID: UUID, at timestamp: Date) {
        let boundedNow = min(max(timestamp, meeting.startTime), meeting.endTime)
        let prior = metrics.session(withID: recordID)
        let firstObserved = prior?.startTime ?? boundedNow
        draft = PersistedCalendarMetricsDraft(
            recordID: recordID,
            meetingID: meeting.id,
            occurrenceStart: meeting.startTime,
            scheduledEnd: meeting.endTime,
            firstObservedAt: firstObserved,
            lastObservedAt: boundedNow,
            accumulatedObservedSeconds: prior?.activeDuration ?? 0,
            isObservationActive: true,
            savedAt: timestamp
        )
        persistence.save(draft!)
    }

    private func updateCurrent(at timestamp: Date, remainsActive: Bool, addFinalDelta: Bool) {
        guard var current = draft else { return }
        let boundedNow = min(max(timestamp, current.occurrenceStart), current.scheduledEnd)
        if addFinalDelta, current.isObservationActive {
            let boundedLast = min(max(current.lastObservedAt, current.occurrenceStart), current.scheduledEnd)
            let delta = boundedNow.timeIntervalSince(boundedLast)
            if delta >= 0, delta <= maximumObservationGap {
                current.accumulatedObservedSeconds += delta
            }
        }
        if current.isObservationActive || remainsActive {
            current.lastObservedAt = boundedNow
        }
        current.isObservationActive = remainsActive
        current.savedAt = timestamp
        draft = current
        persistence.save(current)
    }

    private func finalize(at timestamp: Date, addFinalDelta: Bool) {
        guard draft != nil else { return }
        updateCurrent(at: timestamp, remainsActive: false, addFinalDelta: addFinalDelta)
        guard let completed = draft else { return }
        if completed.accumulatedObservedSeconds >= 5 {
            metrics.upsertSession(FocusSessionRecord(
                id: completed.recordID,
                modeType: .calendarVideoCall,
                modeID: FocusModeType.calendarVideoCall.id,
                startTime: completed.firstObservedAt,
                endTime: max(completed.lastObservedAt, completed.firstObservedAt),
                duration: completed.accumulatedObservedSeconds,
                activeDuration: completed.accumulatedObservedSeconds,
                pausedDuration: 0,
                breakDuration: 0,
                source: .calendar
            ))
        }
        draft = nil
        persistence.clear()
    }

    static func recordID(meetingID: String, occurrenceStart: Date) -> UUID {
        let timestampBits = occurrenceStart.timeIntervalSinceReferenceDate.bitPattern
        let identity = meetingID + "\u{0}" + String(timestampBits, radix: 16)
        var bytes = Array(SHA256.hash(data: Data(identity.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
