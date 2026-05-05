import SwiftUI

struct TimerControlsView: View {
    @EnvironmentObject var timerService: FocusTimerService
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
            .accessibilityLabel(timerService.isPaused ? "Resume Session" : "Pause Session")
            .accessibilityHint(timerService.isPaused ? "Double tap to resume the paused session" : "Double tap to pause the current session")

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
            .accessibilityLabel("Finish Session")
            .accessibilityHint("Double tap to finish the current session")
            .help("Finish Session")
        }
        .padding(.horizontal, 40)
    }
}
