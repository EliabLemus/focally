import SwiftUI

struct ActiveFocusView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService

    @State private var showFinishConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Center Content
            VStack(spacing: 24) {
                // Deep Work Phase Badge
                badgeRow

                // Task Name
                taskNameRow

                // Task Description
                taskDescriptionRow

                // Timer
                timerRow

                // Ambient Glow
                ambientGlow
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)

            // Controls
            TimerControlsView(
                onPause: { timerService.togglePause() },
                onFinish: {
                    showFinishConfirmation = true
                }
            )

            // Bottom Cards
            bottomCards
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focallyBackground)
        .sheet(isPresented: $showFinishConfirmation) {
            finishConfirmationSheet
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // DND Badge (shown only when session is active)
            if dndService.isDNDActive {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                    Text("DO NOT DISTURB ACTIVE")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.focallyPrimary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .animation(.easeInOut(duration: 0.3), value: dndService.isDNDActive)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Badge Row

    private var badgeRow: some View {
        HStack(spacing: 8) {
            Text("DEEP WORK PHASE")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyPrimary)
            Circle()
                .fill(Color.focallyPrimary)
                .frame(width: 8, height: 8)
                .onAppear {
                    startPulseAnimation()
                }
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: timerService.isPaused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.focallyPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Task Name

    private var taskNameRow: some View {
        VStack(spacing: 8) {
            Text(timerService.currentActivity)
                .font(.focallyDisplay)
                .foregroundStyle(Color.focallyOnSurface)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Task Description

    private var taskDescriptionRow: some View {
        Text("Stay focused and minimize distractions")
            .font(.focallyBody)
            .foregroundStyle(Color.focallyOnSurfaceVariant)
            .lineLimit(2)
            .multilineTextAlignment(.center)
    }

    // MARK: - Timer

    private var timerRow: some View {
        VStack(spacing: 8) {
            Text(timerService.remainingTimeString)
                .font(.system(size: 160, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.focallyOnSurface)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: timerService.remainingSeconds)

            Text("Session \(timerService.currentRound + 1) of \(timerService.roundsUntilLongBreak)")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        Circle()
            .fill(Color.focallyPrimary.opacity(0.05))
            .frame(width: 400, height: 400)
            .blur(radius: 100)
            .offset(y: -80)
    }

    // MARK: - Bottom Cards

    private var bottomCards: some View {
        HStack(spacing: 12) {
            focusScoreCard
                .frame(maxWidth: .infinity)
            EstimatedTimeCard()
                .frame(maxWidth: .infinity)
            EnvironmentCard()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Finish Confirmation Sheet

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

    // MARK: - Helper Methods

    private func startPulseAnimation() {
        // Animation is handled by .repeatForever on badge
    }

    private var focusScoreCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.focallyPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Score")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                Text("94%")
                    .font(.focallyH2)
            }

            Spacer()

            Text("High")
                .font(.focallyMicro)
                .foregroundStyle(Color.focallyPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.focallyPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(20)
        .background(Color.focallySurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.focallyCardBorder, lineWidth: 0.5)
        }
    }
}

struct EnvironmentCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundStyle(Color.focallySecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Environment")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("Calm")
                    .font(.focallyH2)
            }
        }
        .padding(16)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.focallyCardBorder, lineWidth: 0.5)
        }
    }
}
