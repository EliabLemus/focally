import SwiftUI

struct FocusMenuView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var calendarService: GoogleCalendarService
    @State private var showActivityInput = false
    @State private var hasPredefinedTasks = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if showActivityInput {
                    ActivityInputView { activity, emoji, duration in
                        timerService.startWorkSession(activity: activity, emoji: emoji, durationMinutes: duration)
                        dndService.activateDND()
                        showActivityInput = false
                    } onCancel: {
                        showActivityInput = false
                    }
                } else if timerService.pomodoroState == .idle {
                    idleView
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
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .onAppear(perform: loadPredefinedTasksState)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text(timerService.stateIcon)
                    .font(.system(size: 48))

                Text(timerService.phaseName)
                    .font(.headline)

                if !timerService.currentActivity.isEmpty {
                    Text("\(timerService.currentEmoji) \(timerService.currentActivity)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(stateCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 10) {
                Button(action: {
                    timerService.startWorkSession(
                        activity: "Focus Session",
                        emoji: "🍅",
                        durationMinutes: timerService.workDurationMinutes
                    )
                    dndService.activateDND()
                }) {
                    HStack {
                        Text("🍅 Quick Start · \(timerService.workDurationMinutes)m")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color.orange.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.28), lineWidth: 1)
                )

                Button(action: {
                    showActivityInput = true
                }) {
                    HStack {
                        Text("✏️ Custom Session")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if hasPredefinedTasks {
                    Button(action: {
                        showActivityInput = true
                    }) {
                        HStack {
                            Text("📚 Start with Saved Task")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    // MARK: - Active State

    private var activeView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text(timerService.stateIcon)
                    .font(.system(size: 40))

                Text(timerService.remainingTimeString)
                    .font(.system(size: 72, weight: .light, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                VStack(spacing: 4) {
                    Text(timerService.phaseName)
                        .font(.headline)

                    Text(roundStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !timerService.currentActivity.isEmpty {
                    Text("\(timerService.currentEmoji) \(timerService.currentActivity)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(stateCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.10))

                        RoundedRectangle(cornerRadius: 5)
                            .fill(progressColor)
                            .frame(width: max(geometry.size.width * timerService.progress, timerService.progress > 0 ? 10 : 0))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(timerService.phaseName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(timerService.progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)

            HStack(spacing: 10) {
                if timerService.isPaused {
                    controlButton("Resume", systemImage: "play.fill", tint: .green, prominent: true) {
                        timerService.resumeSession()
                    }
                } else {
                    controlButton("Pause", systemImage: "pause.fill", tint: .primary, prominent: false) {
                        timerService.pauseSession()
                    }
                }

                if timerService.isBreak {
                    controlButton("Skip", systemImage: "forward.fill", tint: .blue, prominent: false) {
                        timerService.skipToNextPhase()
                    }
                }

                controlButton("Stop", systemImage: "stop.fill", tint: .red, prominent: false) {
                    timerService.resetToIdle()
                    dndService.deactivateDND()
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

private extension FocusMenuView {
    var progressColor: Color {
        if timerService.pomodoroState == .idle {
            return .gray
        }
        if timerService.isWork {
            return .green
        }
        return timerService.isLongBreak ? .purple : .blue
    }

    var stateCardBackground: Color {
        progressColor.opacity(timerService.pomodoroState == .idle ? 0.08 : 0.12)
    }

    var roundStatusText: String {
        let visibleRound = timerService.isWork
            ? min(timerService.currentRound + 1, timerService.roundsUntilLongBreak)
            : max(timerService.currentRound, 1)

        if timerService.isBreak {
            return "Round \(visibleRound) · \(timerService.phaseName)"
        }

        return "Round \(visibleRound) / \(timerService.roundsUntilLongBreak)"
    }

    func loadPredefinedTasksState() {
        guard let data = UserDefaults.standard.data(forKey: PredefinedTask.defaultsKey),
              let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) else {
            hasPredefinedTasks = false
            return
        }

        hasPredefinedTasks = !tasks.isEmpty
    }

    @ViewBuilder
    func controlButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if prominent {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .tint(tint)
        .controlSize(.large)
    }
}
