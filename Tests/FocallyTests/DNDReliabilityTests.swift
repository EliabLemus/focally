import Foundation
import Testing

@testable import Focally

// TASK-057 tests 15, 16 (+ Layer semantics): DNDReliabilityService — verify →
// escalate-at-most-once state machine with an injectable verification delay.

@MainActor
private final class FakeDNDCore: DNDCoreWriting {
    private(set) var isDNDActive = false
    private(set) var activations = 0
    private(set) var deactivations = 0

    func activateDND() { activations += 1; isDNDActive = true }
    func deactivateDND() { deactivations += 1; isDNDActive = false }
}

@MainActor
private final class FakeFocusVerifier: DNDVerifying {
    /// Truth reported by Layer 2 (Control Center boolean in production).
    var isFocusActive = false
    /// After this many reads, the verifier reports DND off (fake "user/system
    /// settled" behavior — deterministic, no sleeps).
    var becomesInactiveAfterReads = Int.max
    private(set) var readCount = 0

    func isAnyFocusActive() -> Bool {
        readCount += 1
        if readCount > becomesInactiveAfterReads { return false }
        return isFocusActive
    }
}

@MainActor
private final class FakeShortcutEscalator: FocusShortcutEscalating {
    var shouldFail = false
    /// Fails the first N invocations deterministically, then succeeds.
    var failFirstCount = 0
    private(set) var invocations: [String] = []

    func runFocusByName(_ modeName: String) async throws {
        invocations.append(modeName)
        if failFirstCount > 0 {
            failFirstCount -= 1
            throw NSError(domain: "FakeShortcutEscalator", code: 1, userInfo: [NSLocalizedDescriptionKey: "shortcuts run timed out"])
        }
        if shouldFail {
            throw NSError(domain: "FakeShortcutEscalator", code: 1, userInfo: [NSLocalizedDescriptionKey: "shortcuts run timed out"])
        }
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    maxTicks: Int = 200
) async -> Bool {
    for _ in 0..<maxTicks {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

@MainActor
final class DNDReliabilityTests {
    private func makeService(
        core: FakeDNDCore,
        verifier: FakeFocusVerifier,
        escalator: FakeShortcutEscalator,
        shortcutsFirstOS: Bool = false
    ) -> DNDReliabilityService {
        DNDReliabilityService(
            core: core,
            verifier: verifier,
            escalator: escalator,
            verificationDelay: { await Task.yield() },
            isShortcutsFirstOS: { shortcutsFirstOS }
        )
    }

    private func makeService(
        verifier: FakeFocusVerifier,
        escalator: FakeShortcutEscalator,
        shortcutsFirstOS: Bool = false
    ) -> DNDReliabilityService {
        makeService(
            core: FakeDNDCore(),
            verifier: verifier,
            escalator: escalator,
            shortcutsFirstOS: shortcutsFirstOS
        )
    }

    // MARK: Test 15a — verification confirmed → no escalation

    @Test func verifiedFocusActiveAfterActivationSkipsEscalation() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(core: core, verifier: verifier, escalator: escalator)

        core.activateDND() // Layer 1 legacy write
        verifier.isFocusActive = true
        service.activationRequested()

        let settled = await waitUntil { service.eventHistory.count >= 2 }
        #expect(settled)
        #expect(service.lastEvent == .verificationConfirmed(targetActive: true))
        #expect(escalator.invocations.isEmpty) // Layer 3 never invoked
        #expect(core.activations == 1) // exactly one legacy write
    }

    // MARK: Test 15b — verification OFF → exactly one escalation, no retry

    @Test func unverifiedActivationEscalatesExactlyOnceWithoutRetry() async {
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(verifier: verifier, escalator: escalator)

        verifier.isFocusActive = false
        service.activationRequested()

        let escalated = await waitUntil { !escalator.invocations.isEmpty }
        #expect(escalated)
        #expect(escalator.invocations.count == 1)
        #expect(escalator.invocations.first == DNDReliabilityService.defaultFocusModeName)
        #expect(service.lastEvent == .escalationInvoked(targetActive: true))

        // No retry loop: after settling, no further escalations or events appear.
        await waitUntil { verifier.readCount >= 1 }
        #expect(verifier.readCount == 1) // verification ran once per transition
        #expect(escalator.invocations.count == 1)
    }

    @Test func verificationIsIdempotentPerTransitionNotContinuous() async {
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(verifier: verifier, escalator: escalator)

        verifier.isFocusActive = false
        service.activationRequested()
        _ = await waitUntil { !escalator.invocations.isEmpty }

        let ticksAfterSettle = verifier.readCount
        await waitUntil { verifier.readCount > ticksAfterSettle + 5 }
        #expect(verifier.readCount == ticksAfterSettle) // no continuous polling
    }

    // MARK: Test 16 — escalation failure surfaces event, no retry loop

    @Test func escalationFailureSurfacesEventAndNeverRetries() async {
        let escalator = FakeShortcutEscalator()
        escalator.shouldFail = true
        let service = makeService(verifier: FakeFocusVerifier(), escalator: escalator)

        service.activationRequested()

        let failed = await waitUntil {
            if case .escalationFailed = service.lastEvent { return true }
            return false
        }
        #expect(failed)
        if case let .escalationFailed(target, detail)? = service.lastEvent {
            #expect(target == true)
            #expect(!detail.isEmpty)
        } else {
            Issue.record("expected escalationFailed event")
        }
        #expect(escalator.invocations.count == 1) // invoked once, never retried

        // App state consistent: the call flow continues — deactivation still works.
        service.deactivationRequested()
        let settled = await waitUntil { service.lastEvent == DNDReliabilityService.ObservabilityEvent.deactivationRequested }
        #expect(settled)
    }

    // MARK: Deactivation layer semantics

    @Test func verifiedDeactivationSkipsEscalation() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(core: core, verifier: verifier, escalator: escalator)

        core.activateDND()
        verifier.isFocusActive = false
        service.deactivationRequested()

        let settled = await waitUntil { service.eventHistory.count >= 2 }
        #expect(settled)
        #expect(service.lastEvent == .verificationConfirmed(targetActive: false))
        #expect(escalator.invocations.isEmpty)
    }

    @Test func unverifiedDeactivationEscalatesOnce() async {
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(verifier: verifier, escalator: escalator)

        verifier.isFocusActive = true // Focus still visible → deactivation didn't take
        service.deactivationRequested()

        let escalated = await waitUntil { !escalator.invocations.isEmpty }
        #expect(escalated)
        #expect(service.lastEvent == .escalationInvoked(targetActive: false))
        #expect(escalator.invocations.count == 1)
    }

    @Test func cancelPendingVerificationPreventsVerification() async {
    // Cancellable delay (Task.sleep throws immediately on cancellation), so
    // the race seen on CI runners (gate stream not unblocking deterministically)
    // cannot happen: once cancelled, the delay returns at once and the
    // `Task.isCancelled` guard inside scheduleVerification stops verification.
    var delayEntered = false
    let service = DNDReliabilityService(
        core: FakeDNDCore(),
        verifier: FakeFocusVerifier(),
        escalator: FakeShortcutEscalator(),
        verificationDelay: {
            delayEntered = true
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 s; cancel desperta al instante
        },
        isShortcutsFirstOS: { false } // legacy tier under test
    )

    service.activationRequested()
    // Wait until the delay closure actually started.
    let sawDelay = await waitUntil { delayEntered }
    #expect(sawDelay)
    service.cancelPendingVerification()

    _ = await waitUntil { false } // drain a few ticks
    #expect(service.lastEvent == DNDReliabilityService.ObservabilityEvent.activationRequested) // never verified/escalated
}

    // MARK: TASK-060 — shortcut-first tier (macOS 14+)

    @Test func modernTierActivationUsesShortcutAsFirstLayerNeverWritesCore() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: true
        )

        verifier.isFocusActive = true
        service.activationRequested()

        let settled = await waitUntil { service.lastEvent == .verificationConfirmed(targetActive: true) }
        #expect(settled)
        #expect(escalator.invocations == [DNDReliabilityService.defaultFocusModeName]) // shortcut IS Layer 1
        #expect(core.activations == 0) // CFPreferences never written on macOS 14+
        #expect(service.eventHistory.contains { if case .shortcutSucceeded = $0 { return true }; return false })
    }

    @Test func modernTierShortcutFailureNeverDegradesToCFPreferences() async {
        let core = FakeDNDCore()
        let escalator = FakeShortcutEscalator()
        escalator.shouldFail = true
        let verifier = FakeFocusVerifier()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: true
        )

        service.activationRequested()

        let failed = await waitUntil {
            if case .escalationFailed = service.lastEvent { return true }
            return false
        }
        #expect(failed)
        #expect(escalator.invocations.count == 1) // no retry loop
        #expect(core.activations == 0) // silent degrade to CFPreferences forbidden
        #expect(verifier.readCount == 0) // no verification after shortcut failure
    }

    @Test func modernTierVerificationIsIndependentOfWrittenPreference() async {
        // Shortcut succeeded but Layer 2 (Control Center) still reports false:
        // the mismatch must surface through verification, never be masked by
        // the value a layer wrote.
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier() // stays false
        let escalator = FakeShortcutEscalator()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: true
        )

        service.activationRequested()
        let verified = await waitUntil { verifier.readCount >= 1 }
        #expect(verified)
        #expect(escalator.invocations.count == 1) // at-most-once, no second shortcut run
        #expect(core.activations == 0)
        #expect(service.lastEvent == .verificationConfirmed(targetActive: true) || service.lastEvent == .shortcutSucceeded(targetActive: true))
        // Mismatch observed: no confirmation event recorded.
        #expect(!service.eventHistory.contains { if case .verificationConfirmed = $0 { return true }; return false })
    }

    @Test func modernTierDeactivationUsesShortcutFirst() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: true
        )

        verifier.isFocusActive = false
        service.deactivationRequested()

        let settled = await waitUntil { service.lastEvent == .verificationConfirmed(targetActive: false) }
        #expect(settled)
        #expect(escalator.invocations.count == 1)
        #expect(core.deactivations == 0)
    }

    // MARK: TASK-060 — legacy tier (macOS ≤ 13) keeps CFPreferences primary

    @Test func legacyTierKeepsCFPreferencesPrimaryWithShortcutEscalation() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: false
        )

        core.activateDND() // legacy caller performs the core write first
        verifier.isFocusActive = false // pref write didn't take
        service.activationRequested()

        let escalated = await waitUntil { !escalator.invocations.isEmpty }
        #expect(escalated)
        #expect(escalator.invocations.count == 1) // shortcut remains the escalation layer
        #expect(core.activations == 1) // legacy core written exactly once
        #expect(service.lastEvent == .escalationInvoked(targetActive: true))
    }

    @Test func legacyTierConfirmedVerificationSkipsShortcut() async {
        let core = FakeDNDCore()
        let verifier = FakeFocusVerifier()
        let escalator = FakeShortcutEscalator()
        let service = makeService(
            core: core, verifier: verifier, escalator: escalator, shortcutsFirstOS: false
        )

        core.activateDND()
        verifier.isFocusActive = true
        service.activationRequested()

        let settled = await waitUntil { service.lastEvent == .verificationConfirmed(targetActive: true) }
        #expect(settled)
        #expect(escalator.invocations.isEmpty)
    }

    // MARK: call-reliability 4.1 — release retries with backoff

    private func makeService(
        verifier: FakeFocusVerifier,
        escalator: FakeShortcutEscalator,
        recordedDelays: DelayRecorder,
        shortcutsFirstOS: Bool = false
    ) -> DNDReliabilityService {
        DNDReliabilityService(
            core: FakeDNDCore(),
            verifier: verifier,
            escalator: escalator,
            verificationDelay: { await Task.yield() },
            isShortcutsFirstOS: { shortcutsFirstOS },
            retryDelay: { seconds in recordedDelays.append(seconds) } // fake sleep ADVANCES the fake clock
        )
    }

    private final class DelayRecorder {
        private(set) var delays: [TimeInterval] = []
        func append(_ d: TimeInterval) { delays.append(d) }
    }

    @Test func failedDeactivationRetriesWithBackoffUntilVerified() async {
        let verifier = FakeFocusVerifier()
        verifier.isFocusActive = true // DND stuck on after the call ends
        verifier.becomesInactiveAfterReads = 1 // read 2 (post-retry) reports off
        let escalator = FakeShortcutEscalator()
        escalator.failFirstCount = 1 // initial release attempt fails, retry succeeds
        let clock = DelayRecorder()
        let service = makeService(verifier: verifier, escalator: escalator, recordedDelays: clock)

        service.deactivationRequested()

        let succeeded = await waitUntil {
            service.eventHistory.contains { if case .deactivationRetrySucceeded = $0 { return true }; return false }
        }
        #expect(succeeded)
        // ≥3 attempts scheduled, first ≤10 s, fake clock advanced in order.
        let scheduled = service.eventHistory.compactMap {
            if case let .deactivationRetryScheduled(attempt, delay) = $0 { return (attempt, delay) }
            return nil
        }
        #expect(scheduled.count == 1)
        #expect(scheduled.first?.1 == DNDReliabilityService.deactivationRetryDelaysSeconds[0])
        #expect(clock.delays == [5.0])
        #expect(service.lastEvent == .deactivationRetrySucceeded)
        // Ownership cleared ONLY after external verification.
        #expect(!service.hasPendingDeactivationRelease)
        #expect(service.systemDNDOwnership == .none)
    }

    @Test func exhaustedRetriesRetainOwnershipUntilLaterVerification() async {
        let verifier = FakeFocusVerifier()
        verifier.isFocusActive = true // never confirms deactivation
        let escalator = FakeShortcutEscalator()
        escalator.failFirstCount = .max // every attempt fails
        let clock = DelayRecorder()
        let service = makeService(verifier: verifier, escalator: escalator, recordedDelays: clock)

        service.deactivationRequested()
        service.registerOwnedSystemDND()

        let exhausted = await waitUntil {
            service.eventHistory.filter {
                if case .deactivationRetryScheduled = $0 { return true }
                return false
            }.count == DNDReliabilityService.deactivationRetryDelaysSeconds.count
        }
        #expect(exhausted)
        // Full backoff schedule ran: 5, 10, 20 — fake clock advanced thrice.
        #expect(clock.delays == DNDReliabilityService.deactivationRetryDelaysSeconds)
        #expect(escalator.invocations.count == DNDReliabilityService.deactivationRetryDelaysSeconds.count + 1)
        // Ownership retained — never orphaned silently.
        #expect(service.hasPendingDeactivationRelease)
        #expect(service.systemDNDOwnership == .ownedByFocally)
    }

    // MARK: call-reliability 4.2 — ownership ledger

    @Test func externalDNDIsNeverReleasedOrClaimed() async {
        let service = makeService(verifier: FakeFocusVerifier(), escalator: FakeShortcutEscalator(), recordedDelays: DelayRecorder())

        service.registerExternalSystemDND() // user's manual Focus at call start
        #expect(service.systemDNDOwnership == .external)

        service.releaseOwnedSystemDNDAfterVerifiedDeactivation()
        #expect(service.systemDNDOwnership == .external) // untouched

        service.registerOwnedSystemDND() // call flow must not claim over it
        #expect(service.systemDNDOwnership == .external)
    }

    @Test func orphanedOwnershipIsReusedNotDuplicated() async {
        let service = makeService(verifier: FakeFocusVerifier(), escalator: FakeShortcutEscalator(), recordedDelays: DelayRecorder())

        service.registerOwnedSystemDND() // previous call's release failed → retained orphan
        service.registerOwnedSystemDND() // next call start
        #expect(service.systemDNDOwnership == .ownedByFocally) // same single ownership

        service.releaseOwnedSystemDNDAfterVerifiedDeactivation()
        #expect(service.systemDNDOwnership == .none) // released exactly once
    }

    @Test func releaseIsBlockedWhileDeactivationUnverified() async {
        let verifier = FakeFocusVerifier()
        verifier.isFocusActive = true // deactivation never verifies
        let escalator = FakeShortcutEscalator()
        escalator.shouldFail = true // every release attempt fails
        let service = makeService(verifier: verifier, escalator: escalator, recordedDelays: DelayRecorder())
        service.registerOwnedSystemDND()
        service.deactivationRequested()

        let pending = await waitUntil { service.hasPendingDeactivationRelease }
        #expect(pending)

        service.releaseOwnedSystemDNDAfterVerifiedDeactivation()
        #expect(service.systemDNDOwnership == .ownedByFocally) // retained until verified
    }

    // MARK: call-reliability 4.3 — synchronous cleanup on terminate

    @Test func synchronousCleanupCompletesBeforeReturning() {
        let core = FakeDNDCore()
        core.activateDND()
        let verifier = FakeFocusVerifier()
        verifier.isFocusActive = true
        verifier.becomesInactiveAfterReads = 2 // DND drops after a couple polls
        var sleepCalls: [TimeInterval] = []
        let service = DNDReliabilityService(
            core: core,
            verifier: verifier,
            escalator: FakeShortcutEscalator(),
            cleanupPollSleep: { sleepCalls.append($0) } // no real sleeping
        )
        service.registerOwnedSystemDND()

        let verified = service.performSynchronousDeactivationCleanup(timeoutSeconds: 3)

        #expect(verified) // returned BEFORE the timeout with confirmation
        #expect(core.deactivations == 1)
        #expect(!service.hasPendingDeactivationRelease)
        #expect(service.systemDNDOwnership == .none)
    }

    @Test func synchronousCleanupTimesOutAndRetainsOwnership() {
        let core = FakeDNDCore()
        core.activateDND()
        let verifier = FakeFocusVerifier()
        verifier.isFocusActive = true // never confirms
        let service = DNDReliabilityService(
            core: core,
            verifier: verifier,
            escalator: FakeShortcutEscalator(),
            cleanupPollSleep: { _ in } // instant fake clock
        )
        service.registerOwnedSystemDND()

        let verified = service.performSynchronousDeactivationCleanup(timeoutSeconds: 0)

        #expect(!verified)
        #expect(core.deactivations == 1) // the deactivation WAS attempted
        #expect(service.hasPendingDeactivationRelease) // ownership retained for reconciliation
        #expect(service.systemDNDOwnership == .ownedByFocally)
    }
}
