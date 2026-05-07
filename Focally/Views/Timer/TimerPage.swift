import SwiftUI

struct TimerPage: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService

    @State private var selectedTab: TimerTab = .timer

    enum TimerTab {
        case timer
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Content
            Group {
                if timerService.hasSession && timerService.isWork {
                    // Session Active
                    ActiveFocusView()
                        .environmentObject(timerService)
                        .environmentObject(dndService)
                } else {
                    // Session Idle
                    IdleDashboardView(
                        onStartSession: {
                            if timerService.currentActivity.isEmpty {
                                timerService.startWorkSession(
                                    activity: "Focus Session",
                                    emoji: "🍅",
                                    durationMinutes: timerService.workDurationMinutes
                                )
                            } else {
                                timerService.startWorkSession(
                                    activity: timerService.currentActivity,
                                    emoji: timerService.currentEmoji,
                                    durationMinutes: timerService.workDurationMinutes
                                )
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Settings")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .focusNavigateToSettings, object: nil)
    }
}
