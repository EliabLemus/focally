import SwiftUI

struct TimerPage: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var predefinedTaskStore: PredefinedTaskStore

    var body: some View {
        Group {
            if timerService.hasSession && timerService.isWork {
                ActiveFocusView()
                    .environmentObject(timerService)
                    .environmentObject(dndService)
            } else {
                IdleDashboardView()
                    .environmentObject(timerService)
                    .environmentObject(dndService)
                    .environmentObject(predefinedTaskStore)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
