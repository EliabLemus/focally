import SwiftUI

struct FocusMenuView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var calendarService: GoogleCalendarService
    @State private var showActivityInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if timerService.pomodoroState == .idle {
                    idleView
                } else if showActivityInput {
                    ActivityInputView { activity, emoji, duration in
                        timerService.startWorkSession(activity: activity, emoji: emoji, durationMinutes: duration)
                        dndService.activateDND()
                        showActivityInput = false
                    } onCancel: {
                        showActivityInput = false
                    }
                } else {
                    activeView
                }

                if calendarService.isEnabled {
                    Divider()
                        .padding(.horizontal, 20)

                    calendarSection
                }

                if calendarService.currentMeeting != nil && timerService.isWork {
                    meetingWarning
                }
            }
            .frame(width: 350)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 16) {
            Text(timerService.stateIcon)
                .font(.system(size: 48))

            Text(timerService.phaseName)
                .font(.headline)

            if !timerService.currentActivity.isEmpty {
                Text(timerService.currentActivity)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: {
                    showActivityInput = true
                }) {
                    Label("Start Focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    timerService.resetToIdle()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Active State

    private var activeView: some View {
        VStack(spacing: 16) {
            // Timer Display
            VStack(spacing: 8) {
                Text(timerService.stateIcon)
                    .font(.system(size: 40))

                Text(timerService.remainingTimeString)
                    .font(.system(size: 72, weight: .light, design: .monospaced))

                if timerService.isBreak {
                    Text(timerService.isLongBreak ? "Long Break" : "Short Break")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Focus")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                if timerService.isWork {
                    Text("Round \(timerService.currentRound) / \(timerService.roundsUntilLongBreak)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            if timerService.isWork {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * timerService.progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 8)
            }

            // Controls
            HStack(spacing: 8) {
                if timerService.isPaused {
                    Button(action: {
                        timerService.resumeSession()
                    }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        timerService.pauseSession()
                    }) {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if timerService.isBreak {
                    Button(action: {
                        timerService.skipToNextPhase()
                    }) {
                        Label("Skip", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                Text("Calendar")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                if calendarService.isSignedIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if let currentMeeting = calendarService.currentMeeting {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentMeeting.title)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text(currentMeeting.timeRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            } else {
                Text("No events today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Meeting Warning

    private var meetingWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Meeting in Progress")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("DND is automatically enabled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
        .padding(.horizontal, 20)
    }
}
