import Foundation

/// 1 Hz timer anchored to the wall-clock second with a sane tolerance.
///
/// Replaces bare `Timer.scheduledTimer(withTimeInterval: 1, repeats: true)` calls:
/// the first fire lands on the next integral wall-clock second and subsequent
/// fires carry `tolerance = 0.1`, letting the system coalesce wakeups instead of
/// demanding exact 1 Hz CPU wakeups. UI stays correct because remaining time is
/// derived from the clock (`derivedRemaining(at:)`), not from tick counts.
@MainActor
final class SecondAnchoredTimer {
    private var timer: Timer?
    var isRunning: Bool { timer != nil }

    func start(_ tick: @escaping @MainActor () -> Void) {
        stop()
        // Anchor: first fire at the next integral wall-clock second.
        let now = Date()
        let fraction = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0)
        let anchor = now.addingTimeInterval(max(1.0 - fraction, 0.05))
        let t = Timer(fire: anchor, interval: 1.0, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
