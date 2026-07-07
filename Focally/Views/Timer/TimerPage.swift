import SwiftUI

struct TimerPage: View {
    @Environment(FocusTimerService.self) private var timerService

    var body: some View {
        Group {
            if timerService.hasSession && timerService.isWork {
                ActiveFocusView()
            } else {
                IdleDashboardView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
