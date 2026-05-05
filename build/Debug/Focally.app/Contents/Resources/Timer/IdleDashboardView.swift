import SwiftUI

struct IdleDashboardView: View {
    @EnvironmentObject var timerService: FocusTimerService

    let onStartSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerRow

            // Bento Grid - Simplified
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                // Timer Display Card
                TimerDisplayCard(onStartSession: onStartSession)

                // Spacer to make it col-span-2
                Spacer()

                // Up Next Card
                UpNextCard()

                // Focus Mode Card
                FocusModeCard()
            }

            // Today's Flow Card - full width at bottom
            TodayFlowCard()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(spacing: 8) {
            Text("Focus Session")
                .font(.focallyDisplay)

            Text("Configure your next deep work block")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Timer Display Card

    struct TimerDisplayCard: View {
        @EnvironmentObject var timerService: FocusTimerService
        let onStartSession: () -> Void

        var body: some View {
            VStack(spacing: 16) {
                // Task Badge
                if !timerService.currentActivity.isEmpty {
                    Text("\(timerService.currentEmoji) \(timerService.currentActivity)")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.focallyPrimary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Countdown
                Text(configuredTimeString)
                    .font(.system(size: 120, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.focallyOnSurface)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: configuredTimeString)

                // Timer Controls
                HStack(spacing: 8) {
                    Button(action: { timerService.pauseSession() }) {
                        Text("Pause")
                            .font(.focallyBodyBold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.focallySecondaryFixed)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!timerService.hasSession)
                    .opacity(timerService.hasSession ? 1 : 0.6)

                    Button(action: onStartSession) {
                        Text("Start")
                            .font(.focallyBodyBold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.focallyPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(timerService.hasSession)
                }
            }
            .padding(20)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 0.5)
            }
        }

        private var borderColor: Color {
            Color.focallyCardBorder
        }

        private var configuredTimeString: String {
            if timerService.hasSession {
                return timerService.remainingTimeString
            }

            return String(format: "%d:00", timerService.workDurationMinutes)
        }
    }

    // MARK: - Up Next Card

    struct UpNextCard: View {
        @EnvironmentObject var timerService: FocusTimerService

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up Next")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                VStack(spacing: 8) {
                    UpNextItem(
                        icon: "bolt.fill",
                        color: .green,
                        name: "Work Session",
                        duration: "\(timerService.workDurationMinutes)m"
                    )

                    UpNextItem(
                        icon: "cup.and.saucer.fill",
                        color: .orange,
                        name: "Short Break",
                        duration: "\(timerService.shortBreakDurationMinutes)m"
                    )
                }
            }
            .padding(20)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 0.5)
            }
        }

        private var borderColor: Color {
            Color.focallyCardBorder
        }
    }

    struct UpNextItem: View {
        let icon: String
        let color: Color
        let name: String
        let duration: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text(duration)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()
            }
        }
    }

    // MARK: - Focus Mode Card

    struct FocusModeCard: View {
        @EnvironmentObject var timerService: FocusTimerService

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.indigo)

                    if timerService.isAutoStartEnabled {
                        Text("AUTO-ENABLED")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyPrimary)
                    } else {
                        Text("MANUAL")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                    }
                }

                Text("System Focus Mode")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("DND automatically activates when session starts")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .padding(20)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 0.5)
            }
        }

        private var borderColor: Color {
            Color.focallyCardBorder
        }
    }

    // MARK: - Today's Flow Card

    struct TodayFlowCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Flow")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                // Mini Bar Chart
                HStack(spacing: 4) {
                    MiniBar(width: 16, height: 0.6)
                    MiniBar(width: 16, height: 0.8)
                    MiniBar(width: 16, height: 0.5)
                    MiniBar(width: 16, height: 0.9)
                    MiniBar(width: 16, height: 0.7)
                    MiniBar(width: 16, height: 0.4)
                    MiniBar(width: 16, height: 0.8)
                }
                .frame(height: 80)
            }
            .padding(20)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 0.5)
            }
        }

        private var borderColor: Color {
            Color.focallyCardBorder
        }
    }

    struct MiniBar: View {
        let width: CGFloat
        let height: CGFloat

        var body: some View {
            Rectangle()
                .fill(Color.blue)
                .frame(width: width, height: height * 80)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
