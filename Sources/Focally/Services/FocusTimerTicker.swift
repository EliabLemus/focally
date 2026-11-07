import Foundation

@MainActor
protocol FocusTimerTicker: AnyObject {
    var isRunning: Bool { get }
    func start(_ tick: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class FoundationFocusTimerTicker: FocusTimerTicker {
    private var anchoredTimer = SecondAnchoredTimer()
    var isRunning: Bool { anchoredTimer.isRunning }

    func start(_ tick: @escaping @MainActor () -> Void) {
        stop()
        anchoredTimer.start(tick)
    }

    func stop() {
        anchoredTimer.stop()
    }
}
