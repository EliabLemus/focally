import SwiftUI

struct ActiveFocusView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService

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
                        .environmentObject(timerService)

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
                title: timerService.isPaused ? "Paused" : "In focus",
                icon: timerService.isPaused ? "pause.fill" : "bolt.fill",
                tint: timerService.isPaused ? Color.focallySecondary : Color.focallyPrimary
            )

            statusPill(
                title: dndService.isDNDActive ? "Do Not Disturb on" : "Do Not Disturb off",
                icon: dndService.isDNDActive ? "moon.fill" : "moon.slash.fill",
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

                Text(timerService.currentActivity)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .foregroundStyle(Color.focallyOnSurface)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: 760)

                Text(timerService.isPaused
                     ? "Your session is paused. Notifications can come in again until you resume."
                     : "Stay with the current block. The timer, controls, and next milestone are all here.")
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
                        heroMeta(title: "Elapsed", value: elapsedTimeString)
                        heroMeta(title: "Current round", value: "\(timerService.currentRound + 1) / \(timerService.roundsUntilLongBreak)")
                        heroMeta(title: "Next", value: nextPhaseLabel)
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
                .stroke(Color.focallyCardBorder, lineWidth: 0.75)
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
            title: "Session cadence",
            icon: "waveform.path.ecg",
            tint: Color.focallyPrimary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(title: "Current block", value: "Round \(timerService.currentRound + 1)")
                supportMetric(title: "Long break cadence", value: "Every \(timerService.roundsUntilLongBreak) rounds")
                supportMetric(title: "Auto-start breaks", value: timerService.isAutoStartEnabled ? "Enabled" : "Manual")
            }
        }
    }

    private var focusModeCard: some View {
        SupportCard(
            title: "Focus mode",
            icon: dndService.isDNDActive ? "moon.fill" : "moon.slash.fill",
            tint: dndService.isDNDActive ? Color.focallyPrimary : Color.focallySecondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(title: "System status", value: dndService.isDNDActive ? "Do Not Disturb is active" : "Do Not Disturb is off")
                supportMetric(title: "Session state", value: timerService.isPaused ? "Paused · notifications are back" : "Running")
                supportMetric(title: "When this ends", value: nextBreakSummary)
            }
        }
    }

    private var finishConfirmationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.focallyError)

            Text("Finish Focus Session?")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            Text("This will stop the timer and end the current focus session")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showFinishConfirmation = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Finish") {
                    timerService.resetToIdle()
                    dndService.deactivateDND()
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
        let elapsedSeconds = max((timerService.workDurationMinutes * 60) - timerService.remainingSeconds, 0)
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var nextBreakSummary: String {
        if timerService.currentRound + 1 >= timerService.roundsUntilLongBreak {
            return "Long break next · \(timerService.longBreakDurationMinutes)m"
        }

        return "Short break next · \(timerService.shortBreakDurationMinutes)m"
    }

    private var nextPhaseLabel: String {
        if timerService.currentRound + 1 >= timerService.roundsUntilLongBreak {
            return "Long break"
        }

        return "Short break"
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
                .stroke(Color.focallyCardBorder, lineWidth: 0.75)
        }
    }
}
