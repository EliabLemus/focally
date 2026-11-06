import Foundation
import os.log

/// Layer 1 adapter: `DNDService`'s legacy CFPreferences write path, expressed as
/// the reliability layer's core seam.
extension DNDService: DNDCoreWriting {}

/// Layer 2 — verification: reads the Control Center boolean
/// `defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes"`.
/// 1 = some Focus active. This is the cheapest truth source and needs no special
/// permissions. `Assertions.json` (TCC/FDA-gated) is explicitly NOT a dependency.
@MainActor
protocol DNDVerifying: AnyObject {
    func isAnyFocusActive() -> Bool
}

/// Layer 3 — escalation: the signed generic "Set Focus by Name" shortcut.
@MainActor
protocol FocusShortcutEscalating: AnyObject {
    func runFocusByName(_ modeName: String) async throws
}

@MainActor
protocol DNDCoreWriting: AnyObject {
    func activateDND()
    func deactivateDND()
    var isDNDActive: Bool { get }
}

/// Wraps the legacy CFPreferences write (Layer 1, performed by `DNDService`) with
/// a verify → escalate-at-most-once state machine. Verification runs once per
/// transition — never continuously — and a failed escalation surfaces an
/// observability event without retry-looping.
@MainActor
final class DNDReliabilityService {
    enum ObservabilityEvent: Equatable {
        case activationRequested
        case verificationConfirmed(targetActive: Bool)
        case escalationInvoked(targetActive: Bool)
        case escalationFailed(targetActive: Bool, detail: String)
        case deactivationRequested
    }

    static let defaultFocusModeName = "Do Not Disturb"
    static let verificationDelaySeconds: UInt64 = 1_000_000_000

    private let logger = Logger.dnd
    private let core: DNDCoreWriting
    private let verifier: DNDVerifying
    private let escalator: FocusShortcutEscalating
    private let focusModeName: String
    private let verificationDelay: () async -> Void
    private(set) var lastEvent: ObservabilityEvent?
    private(set) var eventHistory: [ObservabilityEvent] = []
    /// Idempotency: at most one escalation per transition.
    private var didEscalateCurrentTransition = false
    private var pendingVerificationTask: Task<Void, Never>?

    init(
        core: DNDCoreWriting,
        verifier: DNDVerifying,
        escalator: FocusShortcutEscalating,
        focusModeName: String = DNDReliabilityService.defaultFocusModeName,
        verificationDelay: @escaping () async -> Void = {
            try? await Task.sleep(nanoseconds: DNDReliabilityService.verificationDelaySeconds)
        }
    ) {
        self.core = core
        self.verifier = verifier
        self.escalator = escalator
        self.focusModeName = focusModeName
        self.verificationDelay = verificationDelay
    }

    /// Called after the legacy write path performed an activation.
    func activationRequested() {
        record(.activationRequested)
        didEscalateCurrentTransition = false
        scheduleVerification(targetActive: true)
    }

    /// Called after the legacy write path performed a deactivation.
    func deactivationRequested() {
        record(.deactivationRequested)
        didEscalateCurrentTransition = false
        scheduleVerification(targetActive: false)
    }

    /// Stops in-flight verification without firing (cleanup-on-terminate runs
    /// above all layers).
    func cancelPendingVerification() {
        pendingVerificationTask?.cancel()
        pendingVerificationTask = nil
    }

    private func scheduleVerification(targetActive: Bool) {
        pendingVerificationTask?.cancel()
        pendingVerificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.verificationDelay()
            guard !Task.isCancelled else { return }
            await self.verify(targetActive: targetActive)
        }
    }

    private func verify(targetActive: Bool) async {
        let focusActive = verifier.isAnyFocusActive()
        if focusActive == targetActive {
            // Layer 2 confirmed — no escalation needed.
            record(.verificationConfirmed(targetActive: targetActive))
            return
        }
        guard !didEscalateCurrentTransition else { return }
        didEscalateCurrentTransition = true
        record(.escalationInvoked(targetActive: targetActive))
        do {
            // Timeout/retry policy: invoke once. `shortcuts run` itself is
            // bounded by the shortcuts service timeout; failures are never
            // retried here.
            try await escalator.runFocusByName(focusModeName)
        } catch {
            // Layer 3 failed: surface an observability event, keep app state
            // consistent, never retry-loop. The call flow continues.
            record(.escalationFailed(targetActive: targetActive, detail: error.localizedDescription))
        }
    }

    private func record(_ event: ObservabilityEvent) {
        lastEvent = event
        eventHistory.append(event)
        if case .escalationFailed = event {
            logger.error("DND escalation failed: \(String(describing: event), privacy: .public)")
        } else {
            logger.info("DND reliability event: \(String(describing: event), privacy: .public)")
        }
    }
}

/// Real Layer 2 reader: Control Center's `NSStatusItem Visible FocusModes` key.
@MainActor
final class ControlCenterFocusVerifier: DNDVerifying {
    private let defaultsDomain = "com.apple.controlcenter"
    private let key = "NSStatusItem Visible FocusModes"

    func isAnyFocusActive() -> Bool {
        // Read via the global domain entry in the control center plist. CFPreferences
        // on another app's domain requires the value to be visible; fall back to the
        // `defaults` CLI when the preference is not readable in-process.
        let cfKey = key as CFString
        let domain = defaultsDomain as CFString
        if let value = CFPreferencesCopyAppValue(cfKey, domain) {
            if let boolValue = value as? Bool { return boolValue }
            if let intValue = value as? Int { return intValue != 0 }
            if let dict = value as? [String: Any] {
                // Control Center stores per-status-item visibility dictionaries in
                // some macOS versions; any truthy entry means the item is visible.
                return dict.values.contains { ($0 as? Bool) == true || ($0 as? Int) == 1 }
            }
        }
        return Self.readViaDefaultsCLI(domain: defaultsDomain, key: key)
    }

    private nonisolated static func readViaDefaultsCLI(domain: String, key: String) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", domain, key]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(bytes: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "1"
        } catch {
            return false
        }
    }
}
