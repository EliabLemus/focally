import SwiftUI

struct TimerControlsView: View {
    @Environment(FocusTimerService.self) private var timerService
    @Environment(\.colorScheme) var colorScheme

    let onPause: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Pause Button
            Button(action: {
                if timerService.isPaused {
                    timerService.resumeSession()
                } else {
                    timerService.pauseSession()
                }
            }) {
                Circle()
                    .fill(Color.focallySecondaryFixed)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: timerService.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(timerService.isPaused ? AppLanguage.shared.localizedString("timer_resume_session") : AppLanguage.shared.localizedString("timer_pause_session"))
            .accessibilityHint(timerService.isPaused ? AppLanguage.shared.localizedString("timer_resume_hint") : AppLanguage.shared.localizedString("timer_pause_hint"))

            // Finish Button
            Button(action: onFinish) {
                Circle()
                    .fill(colorScheme == .dark ? Color.focallyError.opacity(0.2) : Color.focallyError.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.focallyError)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("timer_finish_session")
            .accessibilityHint("timer_finish_hint")
            .help("timer_finish_session")
        }
        .padding(.horizontal, 40)
    }
}
