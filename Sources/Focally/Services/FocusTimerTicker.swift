import Foundation

@MainActor
protocol FocusTimerTicker: AnyObject {
    var isRunning: Bool { get }
    func start(_ tick: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class FoundationFocusTimerTicker: FocusTimerTicker {
    private var timer: Timer?
    var isRunning: Bool { timer != nil }

    func start(_ tick: @escaping @MainActor () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
