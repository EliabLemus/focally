import Foundation
import Testing

@testable import Focally

// TASK-057 tests 1, 2, 3, 6, 10: MediaDeviceCallDetector — listener wiring,
// burst dedupe, attribution filters, short-blip grace, Bluetooth stale payload.

@MainActor
private final class FakeMediaDeviceListener: MediaDeviceListening {
    struct Registration: Equatable {
        let device: MediaDeviceID
        let kind: String
    }

    private(set) var added: [MediaDeviceID] = []
    private(set) var removed: [MediaDeviceID] = []
    var enumerated: [MediaDeviceID]
    /// Raw capturing bundle ids re-queried on every evaluation.
    var capturingBundleIDs: [String] = []
    private var handlers: [MediaDeviceID: @MainActor () -> Void] = [:]

    init(devices: [MediaDeviceID]) {
        self.enumerated = devices
    }

    func enumeratedDeviceIDs() -> [MediaDeviceID] { enumerated }

    func addListener(for device: MediaDeviceID, onChange: @escaping @MainActor () -> Void) -> MediaListenerToken {
        added.append(device)
        handlers[device] = onChange
        return MediaListenerToken(device: device)
    }

    func removeListener(_ token: MediaListenerToken) {
        removed.append(token.device)
        handlers.removeValue(forKey: token.device)
    }

    func isDeviceRunning(_ device: MediaDeviceID) -> Bool { !capturingBundleIDs.isEmpty }

    /// Simulates the system firing a device property-change event.
    func fire(device: MediaDeviceID) {
        handlers[device]?()
    }
}

@MainActor
private final class FakeCallProcessAttributor: CallProcessAttributing {
    var bundleIDs: [String] = []
    func capturingBundleIdentifiers() -> [String] { bundleIDs }
}

/// Manual clock: pending closures are fired explicitly. Stale closures
/// self-guard inside the detector (pending*ID == id), so cancel is a counter.
@MainActor
private final class ManualScheduler {
    private(set) var pending: [(delay: TimeInterval, action: @MainActor () -> Void)] = []
    private(set) var cancelCount = 0

    func schedule(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        pending.append((delay, action))
    }

    func cancel(_ id: UUID) { cancelCount += 1 }

    func advance(_ interval: TimeInterval) {
        let due = pending.filter { $0.delay <= interval }
        pending.removeAll { $0.delay <= interval }
        for item in due { item.action() }
    }
}

@MainActor
final class MediaDeviceCallDetectorTests {
    private let audio = MediaDeviceID(systemID: 11, kind: .audioInput)
    private let audio2 = MediaDeviceID(systemID: 12, kind: .audioInput)
    private let video = MediaDeviceID(systemID: 21, kind: .video)
    private let chromeBundle = "com.google.chrome.helper"
    private let chrome = CallClient(bundlePrefix: "com.google.chrome", displayName: "Google Meet (Chrome)", emoji: ":google-meet:")

    private func makeDetector(
        devices: [MediaDeviceID],
        bundleIDs: [String],
        scheduler: ManualScheduler,
        outputBundles: [String] = [],
        cameraRunning: Bool = false
    ) -> (MediaDeviceCallDetector, FakeMediaDeviceListener, FakeCallProcessAttributor) {
        let listener = FakeMediaDeviceListener(devices: devices)
        let attributor = FakeCallProcessAttributor()
        attributor.bundleIDs = bundleIDs
        let detector = MediaDeviceCallDetector(
            deviceListener: listener,
            attributor: attributor,
            outputBundleProbe: { outputBundles },
            cameraProbe: { cameraRunning },
            now: { Date() },
            schedule: { scheduler.schedule($0, $1) },
            cancel: { scheduler.cancel($0) }
        )
        return (detector, listener, attributor)
    }

    // MARK: Test 1 — listener wiring

    @Test func listenerWiringRegistersAllEnumeratedInputAndVideoDevices() {
        let scheduler = ManualScheduler()
        let (detector, listener, _) = makeDetector(devices: [audio, audio2, video], bundleIDs: [], scheduler: scheduler)

        detector.start()

        #expect(listener.added.count == 3)
        #expect(Set(listener.added) == Set([audio, audio2, video]))

        detector.stop()
        #expect(Set(listener.removed) == Set([audio, audio2, video]))
        #expect(listener.added.count == 3)
    }

    @Test func deviceRemovalUnregistersCleanlyAndNewDeviceRegisters() {
        let scheduler = ManualScheduler()
        let (detector, listener, _) = makeDetector(devices: [audio, video], bundleIDs: [], scheduler: scheduler)
        detector.start()

        listener.enumerated = [video, audio2]
        detector.refreshDeviceRegistration()

        #expect(listener.removed == [audio])
        #expect(listener.added.count == 3) // 2 initial + 1 new
        #expect(listener.added.contains(audio2))
        #expect(listener.added.filter { $0 == audio2 }.count == 1)
    }

    // MARK: Test 2 — burst dedupe

    @Test func callbackBurstCollapsesIntoSingleTransition() {
        let scheduler = ManualScheduler()
        let (detector, listener, attributor) = makeDetector(devices: [audio], bundleIDs: [chromeBundle], scheduler: scheduler)
        var starts = 0
        detector.onCallStarted = { _ in starts += 1 }
        detector.start()

        // CoreAudio burst: 12 events in 200 ms with mixed payloads.
        for _ in 0..<12 {
            listener.fire(device: audio)
        }
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)

        #expect(detector.evaluationCount == 1)
        #expect(starts == 0) // start grace has not elapsed yet

        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)

        #expect(starts == 1)
        #expect(detector.isCallActive)
    }

    // MARK: Test 3 — attribution filters

    @Test func ownBundleIsExcludedFromAttribution() {
        let filter = CallProcessAttributor(ownBundleIdentifier: "com.focally.app")
        let clients = filter.attributedClients(fromBundleIdentifiers: ["com.focally.app", chromeBundle])
        #expect(clients == [chrome])
    }

    @Test func systemHelperListIsExcludedFromAttribution() {
        let filter = CallProcessAttributor(ownBundleIdentifier: "com.focally.app")
        let clients = filter.attributedClients(fromBundleIdentifiers: [
            "com.apple.corespeech",
            "com.apple.assistantd",
            "com.apple.universalaccessd",
            "com.apple.controlcenter",
            "com.apple.audiomxd",
            chromeBundle
        ])
        #expect(clients == [chrome])
    }

    // MARK: 2.2 / 2.7 — no Apple-prefix rule; FaceTime/Safari corroborate

    @Test func faceTimeAndSafariCountAsCorroboration() {
        let filter = CallProcessAttributor(ownBundleIdentifier: "com.focally.app")
        // FaceTime and Safari are legitimate call apps — NOT dropped by prefix.
        #expect(filter.attributedClients(fromBundleIdentifiers: ["com.apple.FaceTime"]).count == 1)
        #expect(filter.attributedClients(fromBundleIdentifiers: ["com.apple.Safari"]).count == 1)
        #expect(CallClientCatalog.isSystemCaptureHelper("com.apple.FaceTime") == false)
        #expect(CallClientCatalog.isSystemCaptureHelper("com.apple.Safari") == false)
    }

    @Test func dictationHelperProducesNoCorroborationInSnapshot() {
        let scheduler = ManualScheduler()
        let (detector, _, attributor) = makeDetector(devices: [audio], bundleIDs: [], scheduler: scheduler)
        attributor.bundleIDs = ["com.apple.corespeech"]
        let snapshot = detector.currentSnapshot()
        #expect(snapshot.anyInput == false)
        #expect(snapshot.clients.isEmpty)
    }

    @Test func longestMatchingPrefixWinsForHelperProcesses() {
        #expect(CallClientCatalog.client(for: "com.google.chrome.helper-x").emoji == ":google-meet:")
        #expect(CallClientCatalog.client(for: "com.tinyspeck.slackmacgap").emoji == ":slack-call:")
        #expect(CallClientCatalog.client(for: "us.zoom.zoomosx").emoji == ":zoom:")
        #expect(CallClientCatalog.client(for: "com.zoom").emoji == ":zoom:")
    }

    @Test func unknownNonAppleClientMapsToPhoneEmoji() {
        #expect(CallClientCatalog.client(for: "com.acme.meetings") == CallClientCatalog.unknownClient)
        #expect(CallClientCatalog.unknownClient.emoji == ":phone:")
    }

    // MARK: Test 6 — short blip never fires

    @Test func micBlipShorterThanGraceProducesNoTransitionOrSlackWrite() {
        let scheduler = ManualScheduler()
        let (detector, listener, attributor) = makeDetector(devices: [audio], bundleIDs: [chromeBundle], scheduler: scheduler)
        var starts = 0
        var ends = 0
        detector.onCallStarted = { _ in starts += 1 }
        detector.onCallEnded = { ends += 1 }
        detector.start()

        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        // Blip over before the 3 s start grace: attribution now finds nothing.
        attributor.bundleIDs = []
        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)

        #expect(starts == 0)
        #expect(ends == 0)
        #expect(!detector.isCallActive)
    }

    // MARK: Test 10 — Bluetooth stale payload

    @Test func stalePayloadWithStillActiveClientDoesNotEndCall() {
        let scheduler = ManualScheduler()
        let (detector, listener, _) = makeDetector(devices: [audio], bundleIDs: [chromeBundle], scheduler: scheduler)
        var ends = 0
        detector.onCallEnded = { ends += 1 }
        detector.start()

        // Call becomes active.
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)
        #expect(detector.isCallActive)

        // BT device reports a stale isRunning=0 event, but the process objects
        // still show Chrome capturing → re-query wins, call does NOT end.
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.endGraceInterval)

        #expect(ends == 0)
        #expect(detector.isCallActive)
    }

    // MARK: - TASK-057 attribution fallback (macOS 15.x 'pobj' failure)

    @Test("fallback: query failed + device running reports unknown capture sentinel")
    func fallbackQueryFailedWithDeviceRunningReportsUnknown() {
        let bundles = SystemCallProcessAttributor.fallbackClients(
            queryFailed: true, anyInputDeviceRunning: true)
        #expect(bundles == [SystemCallProcessAttributor.unknownCaptureSentinel])
    }

    @Test("fallback: query failed + nothing running reports no clients")
    func fallbackQueryFailedWithoutDeviceRunningReportsEmpty() {
        let bundles = SystemCallProcessAttributor.fallbackClients(
            queryFailed: true, anyInputDeviceRunning: false)
        #expect(bundles.isEmpty)
    }

    @Test("fallback: query succeeded never returns sentinel from fallback")
    func fallbackQuerySucceededReturnsEmpty() {
        let bundles = SystemCallProcessAttributor.fallbackClients(
            queryFailed: false, anyInputDeviceRunning: true)
        #expect(bundles.isEmpty)
    }

    @Test("fallback: sentinel maps to unknown client with :phone: emoji")
    func sentinelMapsToUnknownClient() {
        let attributor = CallProcessAttributor(ownBundleIdentifier: "app.focally.mac")
        let clients = attributor.attributedClients(
            fromBundleIdentifiers: [SystemCallProcessAttributor.unknownCaptureSentinel])
        #expect(clients.count == 1)
        #expect(clients.first?.emoji == ":phone:")
    }

    // MARK: - Change calendar-first-call-detection (Lane A)

    // 2.1 — detector emits a boolean snapshot; bundle identity is naming only.
    @Test("2.1: unknown browser bundle capturing yields input=true, naming only")
    func unknownBundleSnapshotIsBooleanCorroboration() {
        let scheduler = ManualScheduler()
        let (detector, _, attributor) = makeDetector(devices: [audio], bundleIDs: [], scheduler: scheduler)
        attributor.bundleIDs = ["com.acme.mysterybrowser"]
        let snapshot = detector.currentSnapshot()
        #expect(snapshot.anyInput == true) // corroboration regardless of bundle
        #expect(snapshot.clients.map(\.bundlePrefix) == ["unknown"]) // cosmetic naming
        #expect(snapshot.cameraRunning == false)
        #expect(snapshot.anyOutputNative == false)
    }

    // 2.3 — empty attribution while device runs → unknown.capture sentinel.
    @Test("2.3: empty bundle list + device running resolves to unknown.capture")
    func emptyAttributionWithDeviceRunningYieldsSentinel() {
        let bundles = SystemCallProcessAttributor.captureOutcome(
            bundles: [], anyInputDeviceRunning: true)
        #expect(bundles == [SystemCallProcessAttributor.unknownCaptureSentinel])
        #expect(SystemCallProcessAttributor.captureOutcome(bundles: [], anyInputDeviceRunning: false).isEmpty)
        #expect(SystemCallProcessAttributor.captureOutcome(bundles: ["com.zoom"], anyInputDeviceRunning: false) == ["com.zoom"])
    }

    // 2.4 — mid-call handoff: empty blip + restoration before end grace.
    @Test("2.4: restoration during end grace cancels the pending end")
    func midCallBlipWithRestorationBeforeEndGraceDoesNotEndCall() {
        let scheduler = ManualScheduler()
        let (detector, listener, attributor) = makeDetector(devices: [audio], bundleIDs: [chromeBundle], scheduler: scheduler)
        var ends = 0
        detector.onCallEnded = { ends += 1 }
        detector.start()
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)
        #expect(detector.isCallActive)

        // Handoff blip: capture empties, end-grace is scheduled…
        attributor.bundleIDs = []
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        // …but capture is restored before the 2 s grace elapses.
        attributor.bundleIDs = [chromeBundle]
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.endGraceInterval)

        #expect(ends == 0)
        #expect(detector.isCallActive)
        #expect(scheduler.cancelCount > 0) // pending end was really cancelled
    }

    // 2.5 — heartbeat disarms orphaned calls; idle cost is zero.
    @Test("2.5: heartbeat ends an orphaned call within 2 cycles")
    func heartbeatDisarmsOrphanedCallWhenEndEventLost() {
        let scheduler = ManualScheduler()
        let (detector, listener, attributor) = makeDetector(devices: [audio], bundleIDs: [chromeBundle], scheduler: scheduler)
        var ends = 0
        detector.onCallEnded = { ends += 1 }
        detector.start()
        listener.fire(device: audio)
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)
        #expect(detector.isCallActive)
        let heartbeatScheduled = scheduler.pending.contains { $0.delay == MediaDeviceCallDetector.heartbeatInterval }
        #expect(heartbeatScheduled)

        // End event is LOST: no device event fires, capture just goes empty.
        attributor.bundleIDs = []
        // Cycle 1: heartbeat re-evaluates → schedules end grace.
        scheduler.advance(MediaDeviceCallDetector.heartbeatInterval)
        // End grace fires → confirmCallEnd.
        scheduler.advance(MediaDeviceCallDetector.endGraceInterval)

        #expect(ends == 1)
        #expect(!detector.isCallActive)
    }

    @Test("2.5: idle detector schedules zero timers")
    func idleDetectorRunsNoTimers() {
        let scheduler = ManualScheduler()
        let (detector, _, _) = makeDetector(devices: [audio], bundleIDs: [], scheduler: scheduler)
        detector.start()
        #expect(scheduler.pending.isEmpty)
        #expect(detector.evaluationCount == 0)
        #expect(!detector.isCallActive)
    }

    // 2.6 — output + camera corroborants in the snapshot.
    @Test("2.6: trusted native output corroborates; browser output does not")
    func outputCorroborationIsTrustedNativeOnly() {
        #expect(CallClientCatalog.isTrustedNative("com.zoom"))
        #expect(CallClientCatalog.isTrustedNative("us.zoom.xos"))
        #expect(CallClientCatalog.isTrustedNative("com.microsoft.teams2"))
        #expect(CallClientCatalog.isTrustedNative("com.tinyspeck.slackmacgap"))
        #expect(!CallClientCatalog.isTrustedNative("com.google.chrome"))
        #expect(!CallClientCatalog.isTrustedNative("com.apple.Safari"))
    }

    @Test("2.6: snapshot reports native output and camera booleans")
    func snapshotIncludesOutputAndCameraSignals() {
        let scheduler = ManualScheduler()
        let (detector, _, _) = makeDetector(
            devices: [audio], bundleIDs: [], scheduler: scheduler,
            outputBundles: ["com.zoom"], cameraRunning: true)
        let snapshot = detector.currentSnapshot()
        #expect(snapshot.anyOutputNative == true)
        #expect(snapshot.cameraRunning == true)
        #expect(snapshot.anyInput == false) // muted: no input capture
    }
}
