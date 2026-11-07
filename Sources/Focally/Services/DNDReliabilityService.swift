import Foundation
import os.log

/// Layer 1 adapter (macOS ≤ 13): `DNDService`'s legacy CFPreferences write path,
/// expressed as the reliability layer's core seam. On macOS 14+ the core write
/// is NOT the first layer — the signed shortcut is — so the core is only invoked
/// by callers for the legacy tier.
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
        /// TASK-060: Layer 1 (signed shortcut) completed successfully on macOS 14+.
        case shortcutSucceeded(targetActive: Bool)
        case verificationConfirmed(targetActive: Bool)
        case escalationInvoked(targetActive: Bool)
        case escalationFailed(targetActive: Bool, detail: String)
        case deactivationRequested
    }

    nonisolated static let defaultFocusModeName = "Do Not Disturb"
    static let verificationDelaySeconds: UInt64 = 1_000_000_000
    /// TASK-060: shortcut-first applies from macOS 14.0 on; CFPreferences is
    /// the primary (and only first) layer on macOS 13 or earlier.
    nonisolated static let shortcutFirstMinimumOSVersion = OperatingSystemVersion(
        majorVersion: 14, minorVersion: 0, patchVersion: 0
    )
    nonisolated static func isOperatingSystemAtLeastShortcutsFirst(
        _ info: ProcessInfo = .processInfo
    ) -> Bool {
        info.isOperatingSystemAtLeast(shortcutFirstMinimumOSVersion)
    }

    private let logger = Logger.dnd
    private let core: DNDCoreWriting
    private let verifier: DNDVerifying
    private let escalator: FocusShortcutEscalating
    private let focusModeName: String
    private let verificationDelay: () async -> Void
    /// TASK-060: injected so tests can exercise both OS tiers.
    private let isShortcutsFirstOS: () -> Bool
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
        },
        isShortcutsFirstOS: @escaping () -> Bool = {
            DNDReliabilityService.isOperatingSystemAtLeastShortcutsFirst()
        }
    ) {
        self.core = core
        self.verifier = verifier
        self.escalator = escalator
        self.focusModeName = focusModeName
        self.verificationDelay = verificationDelay
        self.isShortcutsFirstOS = isShortcutsFirstOS
    }

    /// Called to request an activation. TASK-060: on macOS 14+ the signed
    /// shortcut IS the first layer (the CFPreferences core is never written);
    /// on macOS ≤ 13 the caller has already performed the legacy core write
    /// and this goes straight to verification (escalating to the shortcut).
    func activationRequested() {
        record(.activationRequested)
        didEscalateCurrentTransition = false
        if isShortcutsFirstOS() {
            scheduleShortcutFirst(targetActive: true)
        } else {
            scheduleVerification(targetActive: true)
        }
    }

    /// Called to request a deactivation — same tiering as activation.
    func deactivationRequested() {
        record(.deactivationRequested)
        didEscalateCurrentTransition = false
        if isShortcutsFirstOS() {
            scheduleShortcutFirst(targetActive: false)
        } else {
            scheduleVerification(targetActive: false)
        }
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

    /// TASK-060: macOS 14+ Layer 1 — the signed shortcut runs FIRST. The
    /// CFPreferences core is never invoked here; on failure we surface the
    /// event without silently degrading to the legacy write path.
    private func scheduleShortcutFirst(targetActive: Bool) {
        pendingVerificationTask?.cancel()
        pendingVerificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            self.didEscalateCurrentTransition = true
            do {
                // Timeout policy: `shortcuts run` is bounded by the shortcuts
                // service timeout (5 s); a failure here is never retried and
                // never falls back to CFPreferences on macOS 14+.
                try await self.escalator.runFocusByName(self.focusModeName)
                guard !Task.isCancelled else { return }
                self.record(.shortcutSucceeded(targetActive: targetActive))
                await self.verificationDelay()
                guard !Task.isCancelled else { return }
                // Layer 2 verification reads the Control Center boolean —
                // never the value any layer wrote.
                await self.verify(targetActive: targetActive)
            } catch {
                guard !Task.isCancelled else { return }
                self.record(.escalationFailed(targetActive: targetActive, detail: error.localizedDescription))
            }
        }
    }

    /// Layer 2 verification: reads ONLY the external truth source (`verifier`,
    /// the Control Center boolean in production). It never reads the legacy
    /// CFPreferences key that the core layer writes, so a legacy write can
    /// never self-validate.
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
            logger.error("DND escalation failed: \(String(describing: event))")
        } else {
            logger.info("DND reliability event: \(String(describing: event))")
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
