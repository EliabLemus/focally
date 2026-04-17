import SwiftUI

struct FocusMenuView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @State private var showActivityInput = false

    var body: some View {
        VStack {
            if timerService.isActive {
                activeView
            } else if showActivityInput {
                ActivityInputView { activity, emoji, duration in
                    timerService.startActivity(activity, emoji: emoji, durationMinutes: duration)
                    dndService.activateDND()
                    showActivityInput = false
                } onCancel: {
                    showActivityInput = false
                }
            } else {
                idleView
            }
        }
        .frame(width: 300)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Focally")
                .font(.headline)

            Text("Ready to focus")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showActivityInput = true
            } label: {
                Label("Start Focus Session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(20)
    }

    // MARK: - Active State

    private var activeView: some View {
        VStack(spacing: 16) {
            Text(timerService.currentEmoji)
                .font(.system(size: 36))

            Text(timerService.currentActivity)
                .font(.headline)
                .lineLimit(1)

            Text(timerService.remainingTimeString)
                .font(.system(size: 48, design: .monospaced))
                .fontWeight(.bold)

            ProgressView(value: timerService.progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button {
                    timerService.extendFiveMinutes()
                } label: {
                    Label("+5 min", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    timerService.cancelSession()
                    dndService.deactivateDND()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(20)
    }
}
