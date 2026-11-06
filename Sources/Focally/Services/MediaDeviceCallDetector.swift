import AppKit
import CoreAudio
import CoreMediaIO
import Foundation
import os.log

// MARK: - Injected system seams (never hit real CoreAudio/CoreMediaIO in tests)

/// Identifies a media device being observed for `…DeviceIsRunningSomewhere`.
struct MediaDeviceID: Hashable {
    let systemID: UInt32
    let kind: Kind

    enum Kind: Hashable {
        case audioInput
        case video
    }
}

/// Token returned for a registered listener; used to unregister.
struct MediaListenerToken: Hashable {
    let device: MediaDeviceID
    let uuid = UUID()
}

@MainActor
protocol MediaDeviceListening: AnyObject {
    /// Enumerates every audio-input and video device currently present.
    func enumeratedDeviceIDs() -> [MediaDeviceID]
    /// Registers a passive property listener; the handler is invoked on every
    /// property change event (including bursts).
    func addListener(for device: MediaDeviceID, onChange: @escaping @MainActor () -> Void) -> MediaListenerToken
    func removeListener(_ token: MediaListenerToken)
    /// Re-queried inside callbacks — never trust the event payload (Bluetooth
    /// devices can report stale values).
    func isDeviceRunning(_ device: MediaDeviceID) -> Bool
}

@MainActor
protocol CallProcessAttributing: AnyObject {
    /// Bundle identifiers of processes currently capturing input, excluding
    /// nothing — filtering is the attributor's policy.
    func capturingBundleIdentifiers() -> [String]
}

// MARK: - Detector

/// Event-driven call detector. Zero scheduled work while idle: it only runs
/// while reacting to device property events, and every evaluation is debounced
/// so bursts (9+ callbacks/s during a Meet join) collapse into one transition.
@MainActor
final class MediaDeviceCallDetector {
    static let debounceInterval: TimeInterval = 1.5
    static let startGraceInterval: TimeInterval = 3.0
    static let endGraceInterval: TimeInterval = 2.0

    private let logger = Logger.callDetection
    private let deviceListener: MediaDeviceListening
    private let attributor: CallProcessAttributing
    private let clientFilter: CallProcessAttributor
    private let now: () -> Date
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private let cancel: (UUID) -> Void

    var onCallStarted: ((CallClient) -> Void)?
    var onCallEnded: (() -> Void)?

    private var tokens: [MediaListenerToken] = []
    private var isObserving = false
    private(set) var lastKnownClients: [CallClient] = []
    private(set) var isCallActive = false
    private var pendingDebounceID: UUID?
    private var pendingStartID: UUID?
    private var pendingEndID: UUID?
    private var pendingStartClient: CallClient?
    // Debug instrumentation for the idle-resource check: counts evaluations.
    private(set) var evaluationCount = 0

    init(
        deviceListener: MediaDeviceListening,
        attributor: CallProcessAttributing,
        clientFilter: CallProcessAttributor = CallProcessAttributor(),
        now: @escaping () -> Date = Date.init,
        schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action() }
        },
        cancel: @escaping (UUID) -> Void = { _ in }
    ) {
        self.deviceListener = deviceListener
        self.attributor = attributor
        self.clientFilter = clientFilter
        self.now = now
        self.schedule = schedule
        self.cancel = cancel
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        let handler: @MainActor () -> Void = { [weak self] in
            self?.handleDeviceEvent()
        }
        tokens = deviceListener.enumeratedDeviceIDs().map {
            deviceListener.addListener(for: $0, onChange: handler)
        }
        logger.info("Call detector observing \(self.tokens.count) devices")
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false
        for token in tokens {
            deviceListener.removeListener(token)
        }
        tokens = []
        cancelPending(pendingDebounceID); pendingDebounceID = nil
        cancelPending(pendingStartID); pendingStartID = nil; pendingStartClient = nil
        cancelPending(pendingEndID); pendingEndID = nil
        lastKnownClients = []
        isCallActive = false
    }

    /// Removing a device unregisters its listener cleanly; still-present devices
    /// keep (or regain) listeners.
    func refreshDeviceRegistration() {
        guard isObserving else { return }
        let current = deviceListener.enumeratedDeviceIDs()
        let currentSet = Set(current)
        for token in tokens where !currentSet.contains(token.device) {
            deviceListener.removeListener(token)
        }
        tokens.removeAll { !currentSet.contains($0.device) }
        let registered = Set(tokens.map(\.device))
        let handler: @MainActor () -> Void = { [weak self] in
            self?.handleDeviceEvent()
        }
        for device in current where !registered.contains(device) {
            tokens.append(deviceListener.addListener(for: device, onChange: handler))
        }
    }

    /// Raw system-callback entry point. Re-queries real state; the event payload
    /// is never trusted (Bluetooth stale values).
    func handleDeviceEvent() {
        guard isObserving else { return }
        // Debounce: one evaluation per real burst.
        if let existing = pendingDebounceID { cancel(existing) }
        let id = UUID()
        pendingDebounceID = id
        schedule(Self.debounceInterval) { [weak self] in
            guard let self, self.pendingDebounceID == id else { return }
            self.pendingDebounceID = nil
            self.evaluate()
        }
    }

    /// Single debounced evaluation: queries attribution, compares against the
    /// last known state and confirms transitions only after the grace windows.
    func evaluate() {
        guard isObserving else { return }
        evaluationCount += 1
        let clients = clientFilter.attributedClients(
            fromBundleIdentifiers: deviceListenerDeviceClients()
        )

        if clients == lastKnownClients {
            // Stable state — no transition, no republish (documented livelock mode).
            return
        }

        let previous = lastKnownClients
        lastKnownClients = clients

        if previous.isEmpty, let first = clients.first {
            // Candidate call start: confirm after the start grace so accidental
            // mic blips shorter than 3 s never fire.
            cancelPending(pendingStartID)
            pendingStartClient = first
            let id = UUID()
            pendingStartID = id
            schedule(Self.startGraceInterval) { [weak self] in
                guard let self, self.pendingStartID == id else { return }
                self.pendingStartID = nil
                self.confirmCallStart(first)
            }
        } else if !previous.isEmpty, clients.isEmpty {
            // Candidate call end: 2 s stable-idle absorbs mid-call input handoffs.
            cancelPending(pendingEndID)
            let id = UUID()
            pendingEndID = id
            schedule(Self.endGraceInterval) { [weak self] in
                guard let self, self.pendingEndID == id else { return }
                self.pendingEndID = nil
                self.confirmCallEnd()
            }
        } else {
            // Client composition changed while a call stays active (e.g. a second
            // capture joins). Presence semantics handle first-client persistence.
            pendingStartClient = clients.first
        }
    }

    private func deviceListenerDeviceClients() -> [String] {
        attributor.capturingBundleIdentifiers()
    }

    private func confirmCallStart(_ client: CallClient) {
        let clients = clientFilter.attributedClients(
            fromBundleIdentifiers: deviceListenerDeviceClients()
        )
        // Re-query real state before firing; stale payloads are ignored.
        guard !clients.isEmpty else {
            pendingStartClient = nil
            lastKnownClients = clients
            return
        }
        lastKnownClients = clients
        guard !isCallActive else { return }
        isCallActive = true
        let first = clients.first ?? client
        logger.info("Call started via \(first.bundlePrefix)")
        onCallStarted?(first)
    }

    private func confirmCallEnd() {
        let clients = clientFilter.attributedClients(
            fromBundleIdentifiers: deviceListenerDeviceClients()
        )
        // Bluetooth caveat: if any client still captures, the call has NOT ended.
        guard clients.isEmpty else {
            lastKnownClients = clients
            return
        }
        guard isCallActive else { return }
        isCallActive = false
        lastKnownClients = []
        logger.info("Call ended")
        onCallEnded?()
    }

    private func cancelPending(_ id: UUID?) {
        guard let id else { return }
        cancel(id)
    }
}

// MARK: - Real system implementation (never used in tests)

/// CoreAudio + CoreMediaIO passive property listeners. Idle cost: zero timers —
/// callbacks only fire when the system reports a device property change.
@MainActor
final class SystemMediaDeviceListener: MediaDeviceListening {
    private let queue = DispatchQueue(label: "com.focally.mediacall.detection")
    private var audioCallbacks: [UInt32: @Sendable () -> Void] = [:]
    private var cmioCallbacks: [UInt32: @Sendable () -> Void] = [:]
    private var handlerBox: HandlerBox?
    private var registeredAudioIDs: [UInt32] = []
    private var registeredVideoIDs: [UInt32] = []

    private final class HandlerBox: @unchecked Sendable {
        var handler: @MainActor () -> Void
        init(handler: @escaping @MainActor () -> Void) { self.handler = handler }
    }

    init() {}

    func enumeratedDeviceIDs() -> [MediaDeviceID] {
        var ids = Self.audioDeviceIDs().map { MediaDeviceID(systemID: $0, kind: .audioInput) }
        ids.append(contentsOf: Self.videoDeviceIDs().map { MediaDeviceID(systemID: $0, kind: .video) })
        return ids
    }

    func addListener(for device: MediaDeviceID, onChange: @escaping @MainActor () -> Void) -> MediaListenerToken {
        let box = handlerBox ?? {
            let box = HandlerBox(handler: {})
            handlerBox = box
            return box
        }()
        // Preserve the latest handler on the shared box so re-registration keeps
        // forwarding to the detector's current closure.
        box.handler = onChange
        switch device.kind {
        case .audioInput:
            audioCallbacks[device.systemID] = { [weak box] in
                guard let box else { return }
                Task { @MainActor in box.handler() }
            }
            Self.addAudioListener(deviceID: device.systemID, queue: queue) { [weak self] in
                self?.audioCallbacks[$0]?()
            }
        case .video:
            cmioCallbacks[device.systemID] = { [weak box] in
                guard let box else { return }
                Task { @MainActor in box.handler() }
            }
            addVideoListener(deviceID: device.systemID, queue: queue) { [weak self] in
                self?.cmioCallbacks[$0]?()
            }
        }
        return MediaListenerToken(device: device)
    }

    func removeListener(_ token: MediaListenerToken) {
        switch token.device.kind {
        case .audioInput:
            audioCallbacks.removeValue(forKey: token.device.systemID)
            removeAudioListener(deviceID: token.device.systemID) { [weak self] in
                self?.audioCallbacks[$0]?()
            }
        case .video:
            cmioCallbacks.removeValue(forKey: token.device.systemID)
            removeVideoListener(deviceID: token.device.systemID) { [weak self] in
                self?.cmioCallbacks[$0]?()
            }
        }
    }

    func isDeviceRunning(_ device: MediaDeviceID) -> Bool {
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        switch device.kind {
        case .audioInput:
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(device.systemID, &address, 0, nil, &size, &running) == noErr else { return false }
        case .video:
            var address = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(0x676F696E), // 'goin' — DeviceIsRunningSomewhere
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            guard CMIOObjectGetPropertyData(device.systemID, &address, 0, nil, size, &size, &running) == 0 else { return false }
        }
        return running != 0
    }

    private static func audioDeviceIDs() -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var deviceIDs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs) == noErr else {
            return []
        }
        // Keep only devices with at least one input channel.
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        return deviceIDs.filter { id in
            var streams: UInt32 = 0
            var streamSize = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyDataSize(id, &inputAddress, 0, nil, &streamSize) == noErr && streamSize > 0
        }
    }

    private static func videoDeviceIDs() -> [UInt32] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == 0, size > 0 else {
            return []
        }
        var deviceIDs = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &size, &deviceIDs) == 0 else {
            return []
        }
        return deviceIDs
    }

    private static func addAudioListener(deviceID: AudioObjectID, queue: DispatchQueue, fire: @escaping (UInt32) -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &address, queue) { _, _ in
            fire(deviceID)
        }
    }

    private func removeAudioListener(deviceID: AudioObjectID, fire: @escaping (UInt32) -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(deviceID, &address, queue) { _, _ in
            fire(deviceID)
        }
    }

    private func addVideoListener(deviceID: CMIOObjectID, queue: DispatchQueue, fire: @escaping (UInt32) -> Void) {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(0x676F696E), // 'goin'
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectAddPropertyListenerBlock(deviceID, &address, queue) { _, _ in
            fire(deviceID)
        }
    }

    private func removeVideoListener(deviceID: CMIOObjectID, fire: @escaping (UInt32) -> Void) {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(0x676F696E), // 'goin'
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectRemovePropertyListenerBlock(deviceID, &address, queue) { _, _ in
            fire(deviceID)
        }
    }
}

/// Reads capturing processes via `kAudioHardwarePropertyProcessObjects` +
/// `kAudioProcessPropertyIsRunningInput` (macOS 14.2+). No permission prompt.
@MainActor
final class SystemCallProcessAttributor: CallProcessAttributing {
    private let baseAttributor: CallProcessAttributor

    init(baseAttributor: CallProcessAttributor = CallProcessAttributor()) {
        self.baseAttributor = baseAttributor
    }

    static let unknownCaptureSentinel = "unknown.capture"

    func capturingBundleIdentifiers() -> [String] {
        guard #available(macOS 14.2, *) else { return [] }
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(0x706F626A), // 'pobj' = kAudioHardwarePropertyProcessObjects
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else {
            // TASK-057 fallback: some systems (observed on macOS 15.7) fail the
            // process-objects query outright. If a device IS running, something
            // is capturing — report the unknown client (:phone:) instead of
            // silently missing the call.
            return Self.fallbackClients(queryFailed: true, anyInputDeviceRunning: Self.anyInputDeviceRunning())
        }
        var processIDs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &processIDs) == noErr else {
            return Self.fallbackClients(queryFailed: true, anyInputDeviceRunning: Self.anyInputDeviceRunning())
        }

        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var bundleIDs: [String] = []
        for processID in processIDs {
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(processID, &inputAddress, 0, nil, &runningSize, &isRunning) == noErr, isRunning != 0 else {
                continue
            }
            if let bundleID = Self.bundleIdentifier(for: processID) {
                bundleIDs.append(bundleID)
            }
        }
        if bundleIDs.isEmpty, Self.anyInputDeviceRunning() {
            // Processes exist but attribution yielded nothing while a device is
            // capturing (e.g. process bundle extraction blocked by TCC).
            bundleIDs = [Self.unknownCaptureSentinel]
        }
        return bundleIDs
    }

    /// Pure decision core of the attribution fallback (unit-testable):
    /// - query failed + device running  → unknown client sentinel
    /// - query failed + nothing running → no clients (no call)
    static func fallbackClients(queryFailed: Bool, anyInputDeviceRunning: Bool) -> [String] {
        guard queryFailed else { return [] }
        return anyInputDeviceRunning ? [unknownCaptureSentinel] : []
    }

    /// True when at least one audio input device is currently running somewhere.
    nonisolated static func anyInputDeviceRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        var deviceIDs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs) == noErr else {
            return false
        }
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return deviceIDs.contains { id in
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            return AudioObjectGetPropertyData(id, &runningAddress, 0, nil, &runningSize, &isRunning) == noErr
                && isRunning != 0
        }
    }

    private nonisolated static func bundleIdentifier(for processObjectID: AudioObjectID) -> String? {
        // The process object id equals the BSD pid for process objects.
        let pid = pid_t(processObjectID)
        guard pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    func attributedClients(fromBundleIdentifiers bundleIDs: [String]) -> [CallClient] {
        baseAttributor.attributedClients(fromBundleIdentifiers: bundleIDs)
    }
}
