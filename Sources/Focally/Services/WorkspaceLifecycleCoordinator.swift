import Foundation

@MainActor
final class WorkspaceLifecycleCoordinator {
    private let notificationCenter: NotificationCenter
    private let willSleepName: Notification.Name
    private let didWakeName: Notification.Name
    private let willSleep: @MainActor () -> Void
    private let didWake: @MainActor () -> Void
    private var observers: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter,
        willSleepName: Notification.Name,
        didWakeName: Notification.Name,
        willSleep: @escaping @MainActor () -> Void,
        didWake: @escaping @MainActor () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.willSleepName = willSleepName
        self.didWakeName = didWakeName
        self.willSleep = willSleep
        self.didWake = didWake
    }

    func start() {
        guard observers.isEmpty else { return }
        observers = [
            notificationCenter.addObserver(forName: willSleepName, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.willSleep() }
            },
            notificationCenter.addObserver(forName: didWakeName, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.didWake() }
            }
        ]
    }

    func stop() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }
}
