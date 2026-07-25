import SwiftUI

struct ActiveFocusView: View {
    @Environment(FocusTimerService.self) private var timerService
    @Environment(DNDService.self) private var dndService
    @Environment(SlackService.self) private var slackService

    @State private var showFinishConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statusStrip

                    VStack(spacing: 24) {
                        focusHero
                            .frame(minHeight: geometry.size.height > 780 ? 420 : 360)

                        TimerControlsView(
                            onPause: { timerService.togglePause() },
                            onFinish: { showFinishConfirmation = true }
                        )

                        supportCards(for: geometry.size.width)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focallyBackground)
        .sheet(isPresented: $showFinishConfirmation) {
            finishConfirmationSheet
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            statusPill(
                title: timerService.isPaused ? AppLanguage.shared.localizedString("focus_paused") : AppLanguage.shared.localizedString("focus_in_focus"),
                icon: timerService.isPaused ? "pause.fill" : "bolt.fill",
                tint: timerService.isPaused ? Color.focallySecondary : Color.focallyPrimary
            )

            statusPill(
                title: dndService.isDNDActive ? AppLanguage.shared.localizedString("focus_dnd_on") : AppLanguage.shared.localizedString("focus_dnd_off"),
                icon: dndService.isDNDActive ? "moon.fill" : "moon",
                tint: dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant
            )

            Spacer()

            Text(nextBreakSummary)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
    }

    private var focusHero: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text(timerService.phaseName.uppercased())
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyPrimary)

                EmojiView(
                    timerService.currentEmoji,
                    customEmojiImageURLs: slackService.workspaceEmojiImageURLs,
                    workspaceEmojiCodes: slackService.workspaceEmojiCodes,
                    font: .system(size: 42),
                    dimension: 42
                )

                Text(timerService.currentActivity)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .foregroundStyle(Color.focallyOnSurface)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 760)

                Text(timerService.isPaused
                     ? AppLanguage.shared.localizedString("focus_paused_message")
                     : AppLanguage.shared.localizedString("focus_active_message"))
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            VStack(spacing: 14) {
                Text(timerService.remainingTimeString)
                    .font(.system(size: 148, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.focallyOnSurface)
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: timerService.remainingSeconds)

                VStack(spacing: 8) {
                    ProgressView(value: timerService.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.focallyPrimary)
                        .frame(maxWidth: 420)

                    HStack(spacing: 18) {
                        heroMeta(title: AppLanguage.shared.localizedString("focus_elapsed"), value: elapsedTimeString)
                        heroMeta(title: AppLanguage.shared.localizedString("focus_mode_label"), value: timerService.currentMode?.name ?? "Focus")
                        heroMeta(title: AppLanguage.shared.localizedString("focus_next"), value: nextPhaseLabel)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(heroBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.focallyOutline, lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func supportCards(for width: CGFloat) -> some View {
        Group {
            if width >= 980 {
                HStack(alignment: .top, spacing: 14) {
                    sessionProgressCard
                    EstimatedTimeCard()
                    focusModeCard
                }
            } else {
                VStack(spacing: 14) {
                    sessionProgressCard
                    EstimatedTimeCard()
                    focusModeCard
                }
            }
        }
    }

    private var sessionProgressCard: some View {
        SupportCard(
            title: AppLanguage.shared.localizedString("focus_session_cadence"),
            icon: "waveform.path.ecg",
            tint: Color.focallyPrimary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(
                    title: AppLanguage.shared.localizedString("focus_current_block"),
                    value: timerService.currentMode?.enablePomodoro == true ? String(format: AppLanguage.shared.localizedString("focus_pomodoro_round"), timerService.currentRound + 1, timerService.pomodoroRounds) : AppLanguage.shared.localizedString("focus_single_session")
                )
                supportMetric(title: AppLanguage.shared.localizedString("focus_break_length"), value: "\(timerService.shortBreakDurationMinutes)m")
                supportMetric(title: AppLanguage.shared.localizedString("focus_pomodoro"), value: timerService.currentMode?.enablePomodoro == true ? AppLanguage.shared.localizedString("focus_pomodoro_enabled") : AppLanguage.shared.localizedString("focus_pomodoro_off"))
            }
        }
    }

    private var focusModeCard: some View {
        SupportCard(
            title: AppLanguage.shared.localizedString("focus_mode_title"),
            icon: dndService.isDNDActive ? "moon.fill" : "moon",
            tint: dndService.isDNDActive ? Color.focallyPrimary : Color.focallySecondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(title: AppLanguage.shared.localizedString("focus_system_status"), value: dndService.isDNDActive ? AppLanguage.shared.localizedString("focus_dnd_active") : AppLanguage.shared.localizedString("focus_dnd_inactive"))
                supportMetric(title: AppLanguage.shared.localizedString("focus_slack_status"), value: timerService.currentStatusText)
                supportMetric(title: AppLanguage.shared.localizedString("focus_when_ends"), value: nextBreakSummary)
            }
        }
    }

    private var finishConfirmationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.focallyError)

            LocalizedText("focus_finish_title")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            LocalizedText("focus_finish_detail")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("general_cancel") {
                    showFinishConfirmation = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("focus_finish_button") {
                    timerService.resetToIdle()
                    showFinishConfirmation = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.focallyError)
            }
        }
        .padding(32)
    }

    private func statusPill(title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurface)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }

    private func heroMeta(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
            Text(value)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
        }
        .frame(minWidth: 110)
    }

    private func supportMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
            Text(value)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 28)
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
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.focallyPrimary.opacity(timerService.isPaused ? 0.08 : 0.16))
                        .frame(width: 320, height: 320)
                        .blur(radius: 40)
                        .offset(x: -180, y: -70)

                    Circle()
                        .fill(Color.focallySecondary.opacity(0.12))
                        .frame(width: 260, height: 260)
                        .blur(radius: 34)
                        .offset(x: 220, y: 120)
                }
            }
    }

    private var elapsedTimeString: String {
        let elapsedSeconds = max((timerService.durationMinutes * 60) - timerService.remainingSeconds, 0)
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var nextBreakSummary: String {
        if timerService.isBreak {
            return AppLanguage.shared.localizedString("focus_break_resumes")
        }
        if timerService.currentMode?.enablePomodoro != true {
            return AppLanguage.shared.localizedString("focus_session_ends_zero")
        }
        if timerService.currentRound + 1 >= timerService.pomodoroRounds {
            return AppLanguage.shared.localizedString("focus_session_ends_round")
        }
        return String(format: AppLanguage.shared.localizedString("focus_break_next"), timerService.shortBreakDurationMinutes)
    }

    private var nextPhaseLabel: String {
        if timerService.isBreak {
            return AppLanguage.shared.localizedString("focus_next_phase_focus")
        }
        if timerService.currentMode?.enablePomodoro != true || timerService.currentRound + 1 >= timerService.pomodoroRounds {
            return AppLanguage.shared.localizedString("focus_next_phase_finish")
        }
        return AppLanguage.shared.localizedString("focus_next_phase_break")
    }
}

struct SupportCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let content: Content

    init(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.focallyOutline, lineWidth: 0.75)
        }
    }
}
