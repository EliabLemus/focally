import SwiftUI

struct FocusMenuView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var calendarService: GoogleCalendarService
    @State private var showActivityInput = false

    var body: some View {
        ScrollView {
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

                if calendarService.isEnabled {
                    Divider()
                        .padding(.horizontal, 20)

                    CalendarEventsView(sessionInterval: activeSessionInterval, maxVisibleEvents: 3)
                        .environmentObject(calendarService)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
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

            if timerService.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

                Button {
                    timerService.togglePause()
                } label: {
                    Label(timerService.isPaused ? "Resume" : "Pause", systemImage: timerService.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }

    private var activeSessionInterval: DateInterval? {
        guard timerService.isActive else { return nil }
        return DateInterval(start: Date(), end: Date().addingTimeInterval(TimeInterval(timerService.remainingSeconds)))
    }
}
