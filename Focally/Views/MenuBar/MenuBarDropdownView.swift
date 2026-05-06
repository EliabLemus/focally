import SwiftUI

struct MenuBarDropdownView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var historyService: HistoryService
    @Environment(\.colorScheme) var colorScheme

    @State private var taskInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerRow

            // Content
            ScrollView {
                VStack(spacing: 12) {
                    // Task Input
                    taskInputSection

                    // Action Buttons (only when idle)
                    if !timerService.hasSession {
                        actionButtons
                    }

                    // Active Session Card (if session active)
                    if timerService.hasSession {
                        activeSessionCard
                    }

                    // Spacer for footer
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Footer Stats
            footerStats
        }
        .frame(width: 320)
        .background(backgroundMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 30, y: 10)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text("Focus")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
                .accessibilityIdentifier("headerFocusText")

            Spacer()

            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyOnSurfaceVariant.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settingsButton")

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyOnSurfaceVariant.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("moreButton")
            }
            .padding(4)
            .background(Circle().fill(Color.black.opacity(0.05)))
            .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Task Input

    private var taskInputSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 14))
                .foregroundStyle(Color.focallyOnSurfaceVariant.opacity(0.6))

            TextField("Current Task", text: $taskInput)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurface)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .accessibilityIdentifier("taskInputTextField")
                .onSubmit {
                    if !taskInput.isEmpty {
                        timerService.startWorkSession(
                            activity: taskInput,
                            emoji: "📝",
                            durationMinutes: timerService.workDurationMinutes
                        )
                        taskInput = ""
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 0.5)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Start Pomodoro Button
            Button(action: {
                let activity = taskInput.isEmpty ? "Focus Session" : taskInput
                timerService.startWorkSession(
                    activity: activity,
                    emoji: "🍅",
                    durationMinutes: timerService.workDurationMinutes
                )
                taskInput = ""
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 14))

                    Text("Start Pomodoro")
                        .font(.focallyBodyBold)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(timerService.workDurationMinutes)m")
                        .font(.focallyCaption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.focallyPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("startPomodoroButton")

            // Custom Session Button
            Button(action: {
                let activity = taskInput.isEmpty ? "Custom Session" : taskInput
                timerService.startWorkSession(
                    activity: activity,
                    emoji: "⏱️",
                    durationMinutes: 45
                )
                taskInput = ""
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 14))

                    Text("Custom Session")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSecondaryContainer)

                    Spacer()

                    Text("45m")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSecondaryContainer.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.focallySecondaryContainer)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customSessionButton")
        }
    }

    // MARK: - Active Session Card

    private var activeSessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerService.currentActivity)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                        .lineLimit(1)

                    Text(timerService.isBreak ? "Break" : "Deep Focus Mode")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    // DND Badge
                    if dndService.isDNDActive {
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

                // Pause/Resume button
                Button(action: { timerService.togglePause() }) {
                    Image(systemName: timerService.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(timerService.isPaused ? "playButton" : "pauseButton")

                // Stop button
                Button(action: { timerService.resetToIdle() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.focallyError)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stopPomodoroButton")
            }

            // Timer display
            Text(timerService.remainingTimeString)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.focallyOnSurface)
                .monospacedDigit()

            // Progress bar
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

            // Caption
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

    // MARK: - Footer Stats

    private var footerStats: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                // Daily Focus Time
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    Text("Daily: \(formatFocusTime())")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()

                // Flow State (mock — TODO: derive from HistoryService)
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyPrimary)

                    Text("85% Flow State")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

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

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
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
        return hours > 0 ? "\(hours)h \(mins)m Focus" : "\(mins)m Focus"
    }
}
