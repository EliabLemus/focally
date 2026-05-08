import SwiftUI

struct IdleDashboardView: View {
    @EnvironmentObject private var timerService: FocusTimerService
    @EnvironmentObject private var dndService: DNDService
    @EnvironmentObject private var predefinedTaskStore: PredefinedTaskStore
    @EnvironmentObject private var slackService: SlackService

    @State private var taskInput: String = ""
    @State private var selectedEmoji: String = "🎯"
    @State private var selectedDuration: Int = 25

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FocallySpacing.lg) {
                    headerRow

                    if geometry.size.width >= 920 {
                        HStack(alignment: .top, spacing: FocallySpacing.md) {
                            heroCard
                                .frame(maxWidth: .infinity, minHeight: 360)

                            VStack(spacing: FocallySpacing.md) {
                                UpNextCard()
                                FocusStatusCard()
                            }
                            .frame(width: min(340, geometry.size.width * 0.32))
                        }
                    } else {
                        VStack(spacing: FocallySpacing.md) {
                            heroCard
                            UpNextCard()
                            FocusStatusCard()
                        }
                    }

                    TodayFlowCard()
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.top, FocallySpacing.lg)
                .padding(.bottom, FocallySpacing.lg)
            }
        }
        .background(Color.focallyBackground)
        .onAppear(perform: syncFromService)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOCUS HOME")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyPrimary)

            Text("Start the next block without digging through settings.")
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Pick the task, pick the status, choose the time, and go.")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NEXT SESSION")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)

                    Text("Custom focus block")
                        .font(.system(size: 30, weight: .semibold, design: .default))
                        .foregroundStyle(Color.focallyOnSurface)
                        .lineLimit(2)

                    Text("This starts with your chosen duration and the same quiet-mode automation the timer uses everywhere else.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                statusBadge(title: focusBadgeTitle, systemImage: focusBadgeIcon)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    CompactStatusEmojiButton(selection: $selectedEmoji, options: FocusStatusOption.common)

                    TextField("What are you focusing on?", text: $taskInput)
                        .textFieldStyle(.roundedBorder)
                }

                Text(slackStatusSummary)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                DurationControl(minutes: $selectedDuration, range: 5...180, step: 5)
            }

            HStack(spacing: 12) {
                metricPill(systemImage: "timer", title: "Work", value: "\(selectedDuration)m")
                metricPill(systemImage: "cup.and.saucer.fill", title: "Break", value: "\(timerService.shortBreakDurationMinutes)m")
                metricPill(systemImage: "repeat", title: "Cycle", value: "\(timerService.roundsUntilLongBreak) rounds")
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: startSession) {
                        Label("Start focus session", systemImage: "play.fill")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.focallyPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start focus session")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-start breaks")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                        Text(timerService.isAutoStartEnabled ? "Enabled" : "Manual")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: 148, minHeight: 52, alignment: .leading)
                    .background(Color.focallySurfaceContainerLowest.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                pomodoroCard

                if !predefinedTaskStore.tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or launch a saved preset")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                            ForEach(predefinedTaskStore.tasks.prefix(4)) { task in
                                PredefinedTaskQuickButton(task: task) {
                                    start(task: task)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.focallyCardBorder.opacity(0.9), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        Color.focallySurfaceContainerHigh,
                        Color.focallySurfaceContainerLow,
                        Color.focallySurfaceContainerLowest
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.focallyPrimary.opacity(0.12))
                    .frame(width: 240, height: 240)
                    .blur(radius: 24)
                    .offset(x: 50, y: -70)
            }
    }

    private func statusBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurface)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.focallySurfaceContainerLowest.opacity(0.82))
            .clipShape(Capsule())
    }

    private func metricPill(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.focallyPrimary)
                .frame(width: 28, height: 28)
                .background(Color.focallyPrimary.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                Text(value)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.focallySurfaceContainerLowest.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func syncFromService() {
        if taskInput.isEmpty {
            taskInput = timerService.currentActivity
        }
        selectedEmoji = timerService.currentEmoji
        selectedDuration = timerService.workDurationMinutes
        slackService.refreshEmojiCatalogIfPossible()
    }

    private func startSession() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = trimmed.isEmpty ? "Focus Session" : trimmed
        timerService.updateWorkDuration(minutes: selectedDuration)
        timerService.startWorkSession(activity: activity, emoji: selectedEmoji, durationMinutes: selectedDuration)
    }

    private func start(task: PredefinedTask) {
        timerService.updateWorkDuration(minutes: task.durationMinutes)
        timerService.startWorkSession(activity: task.name, emoji: task.emoji, durationMinutes: task.durationMinutes)
    }

    private func startPomodoro() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = trimmed.isEmpty ? "Pomodoro" : trimmed
        timerService.startPomodoroSession(activity: activity, emoji: selectedEmoji)
    }

    private var pomodoroCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pomodoro")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                Text("Classic 25 · 5 · 15 cadence with 4 rounds. Quick Session stays free-form.")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            Button(action: startPomodoro) {
                Label("Start Pomodoro", systemImage: "timer")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.focallySurfaceContainerLowest.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var focusBadgeTitle: String {
        if timerService.isPaused {
            return "Notifications live"
        }
        return dndService.isDNDActive ? "Focus active" : "Focus ready"
    }

    private var focusBadgeIcon: String {
        if timerService.isPaused {
            return "bell.badge"
        }
        return dndService.isDNDActive ? "moon.fill" : "sparkles"
    }

    private var slackStatusSummary: String {
        CompactStatusEmojiButton.isSlackShortcode(selectedEmoji)
            ? "Slack status will use \(selectedEmoji)."
            : "Slack status will use \(selectedEmoji)."
    }
}

private extension IdleDashboardView {
    struct UpNextCard: View {
        @EnvironmentObject var timerService: FocusTimerService

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Session rhythm", subtitle: "What happens after you press start")

                VStack(spacing: 10) {
                    UpNextItem(
                        icon: "play.circle.fill",
                        tint: Color.focallyPrimary,
                        name: "Focus block",
                        detail: "\(timerService.workDurationMinutes) minutes"
                    )

                    UpNextItem(
                        icon: "cup.and.saucer.fill",
                        tint: Color.focallySecondary,
                        name: "Short reset",
                        detail: "\(timerService.shortBreakDurationMinutes) minutes"
                    )

                    UpNextItem(
                        icon: "figure.mind.and.body",
                        tint: Color.focallyTertiary,
                        name: "Long break cadence",
                        detail: "Every \(timerService.roundsUntilLongBreak) rounds"
                    )
                }
            }
            .padding(22)
            .cardSurface()
        }
    }

    struct UpNextItem: View {
        let icon: String
        let tint: Color
        let name: String
        let detail: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                    Text(detail)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()
            }
        }
    }

    struct FocusStatusCard: View {
        @EnvironmentObject var timerService: FocusTimerService
        @EnvironmentObject var dndService: DNDService

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Focus status", subtitle: "System behavior for the next block")

                VStack(spacing: 12) {
                    statusRow(
                        title: "Do Not Disturb",
                        value: timerService.isPaused ? "Paused, notifications can come through" : (dndService.isDNDActive ? "Currently on" : "Will activate on start"),
                        icon: timerService.isPaused ? "bell.badge" : (dndService.isDNDActive ? "moon.fill" : "moon.zzz.fill")
                    )

                    statusRow(
                        title: "Break handoff",
                        value: timerService.isAutoStartEnabled ? "Automatic" : "Manual confirmation",
                        icon: timerService.isAutoStartEnabled ? "arrow.triangle.2.circlepath" : "hand.tap"
                    )

                    statusRow(
                        title: "Saved activity",
                        value: timerService.currentActivity.isEmpty ? "Default focus session" : timerService.currentActivity,
                        icon: "list.bullet.rectangle.portrait"
                    )
                }
            }
            .padding(22)
            .cardSurface()
        }

        private func statusRow(title: String, value: String, icon: String) -> some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.focallyPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.focallyPrimary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                    Text(value)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    struct TodayFlowCard: View {
        @EnvironmentObject var timerService: FocusTimerService

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Today’s flow", subtitle: "A sober summary of your configured cadence")

                HStack(spacing: 14) {
                    summaryColumn(title: "Deep work", value: "\(timerService.workDurationMinutes)m", detail: "per round")
                    summaryColumn(title: "Short break", value: "\(timerService.shortBreakDurationMinutes)m", detail: "between rounds")
                    summaryColumn(title: "Long break", value: "\(timerService.longBreakDurationMinutes)m", detail: "after \(timerService.roundsUntilLongBreak) rounds")
                }

                Divider()
                    .overlay(Color.focallyCardBorder)

                Text(timerService.isAutoStartEnabled
                     ? "Breaks restart automatically, so the flow stays uninterrupted until you finish the session."
                     : "Breaks wait for manual confirmation, which keeps the rhythm explicit and easier to control.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .cardSurface()
        }

        private func summaryColumn(title: String, value: String, detail: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.focallyOnSurface)
                Text(detail)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct SectionHeader: View {
        let title: String
        let subtitle: String

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)
                Text(subtitle)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
        }
    }
}

private extension View {
    func cardSurface() -> some View {
        self
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.focallyCardBorder, lineWidth: 0.75)
            }
    }
}

