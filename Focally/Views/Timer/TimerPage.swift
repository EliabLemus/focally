import SwiftUI

struct TimerPage: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService

    var body: some View {
        Group {
            if timerService.hasSession && timerService.isWork {
                ActiveFocusView()
                    .environmentObject(timerService)
                    .environmentObject(dndService)
            } else {
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
                .environmentObject(timerService)
                .environmentObject(dndService)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
