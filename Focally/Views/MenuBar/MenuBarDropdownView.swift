import SwiftUI

struct MenuBarDropdownView: View {
    @EnvironmentObject private var timerService: FocusTimerService
    @EnvironmentObject private var dndService: DNDService
    @EnvironmentObject private var historyService: HistoryService
    @EnvironmentObject private var predefinedTaskStore: PredefinedTaskStore
    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            ScrollView {
                VStack(spacing: 14) {
                    if timerService.hasSession {
                        activeSessionCard
                    } else {
                        quickStartSection
                        presetsSection
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            footerStats
        }
        .frame(width: 340)
        .background(backgroundMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 30, y: 10)
        .onAppear(perform: syncFromService)
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)
                Text("Start fast, stay quiet.")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var quickStartSection: some View {
        QuickSessionsSection()
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Predefined tasks")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                Spacer()
                Text("\(predefinedTaskStore.tasks.count)")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            if predefinedTaskStore.tasks.isEmpty {
                Text("Create presets from Task Configuration.")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            } else {
                VStack(spacing: 8) {
                    ForEach(predefinedTaskStore.tasks.prefix(4)) { task in
                        PredefinedTaskQuickButton(task: task) {
                            start(task: task)
                        }
                    }
                }
            }
        }
    }

    private var activeSessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerService.currentActivity)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                        .lineLimit(1)

                    Text(timerService.isPaused ? "Paused · Notifications are back" : (timerService.isBreak ? "Break" : "Deep Focus Mode"))
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    if timerService.isPaused {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.focallySecondary)
                                .frame(width: 6, height: 6)
                            Text("Notifications live")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.focallySecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.focallySecondary.opacity(0.12)))
                    } else if dndService.isDNDActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 6, height: 6)
                            Text("DND Active")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.purple)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.1)))
                    }
                }

                Spacer()

                Button(action: { timerService.togglePause() }) {
                    Image(systemName: timerService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: { timerService.resetToIdle() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.focallyError)
                }
                .buttonStyle(.plain)
            }

            Text(timerService.remainingTimeString)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.focallyOnSurface)
                .monospacedDigit()

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.focallySurfaceContainerHighest)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.focallyPrimary)
                        .frame(width: geometry.size.width * CGFloat(timerService.progress))
                }
            }
            .frame(height: 6)

            let elapsed = formatElapsed()
            let total = formatDuration(timerService.durationMinutes * 60)
            Text("\(elapsed) of \(total)")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
        .padding(12)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.focallyCardBorder, lineWidth: 0.5)
        }
        .padding(.horizontal, 4)
    }

    private var footerStats: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    Text("Today: \(formatFocusTime())")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(timerService.isPaused ? Color.focallySecondary : (dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant))

                    Text(timerService.isPaused ? "Paused · notifications live" : (dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready"))
                        .font(.focallyCaption)
                        .foregroundStyle(timerService.isPaused ? Color.focallySecondary : (dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var backgroundMaterial: some View {
        Group {
            if colorScheme == .dark {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.3))
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.white.opacity(0.2))
            }
        }
    }

    private func syncFromService() {
        slackService.refreshEmojiCatalogIfPossible()
    }

    private func start(task: PredefinedTask) {
        timerService.updateWorkDuration(minutes: task.durationMinutes)
        timerService.startWorkSession(activity: task.name, emoji: task.emoji, durationMinutes: task.durationMinutes)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatElapsed() -> String {
        let total = timerService.durationMinutes * 60
        let elapsed = total - timerService.remainingSeconds
        return formatDuration(elapsed)
    }

    private func formatFocusTime() -> String {
        let minutes = historyService.totalFocusMinutesToday()
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
}
