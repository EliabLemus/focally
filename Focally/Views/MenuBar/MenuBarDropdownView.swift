import SwiftUI

struct MenuBarDropdownView: View {
    @Environment(FocusModeStore.self) private var focusModeStore
    @Environment(FocusTimerService.self) private var timerService
    @Environment(DNDService.self) private var dndService
    @Environment(SlackService.self) private var slackService
    @Environment(CalendarSlackIntegrationService.self) private var calendarService
    @Environment(\.colorScheme) private var colorScheme

    var onAddMode: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            ScrollView {
                VStack(spacing: 14) {
                    if timerService.hasSession {
                        activeSessionCard
                    } else {
                        quickStartSection
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            footerStatus
        }
        .frame(width: 340)
        .background(backgroundMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 30, y: 10)
        .onAppear {
            slackService.refreshEmojiCatalogIfPossible()
            calendarService.startIfEnabled()
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Focus")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Start")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            ForEach(focusModeStore.modes) { mode in
                Button(action: { timerService.startSession(mode: mode) }) {
                    HStack(spacing: 12) {
                        EmojiView(
                            mode.emoji,
                            customEmojiImageURLs: slackService.workspaceEmojiImageURLs,
                            workspaceEmojiCodes: slackService.workspaceEmojiCodes,
                            font: .system(size: 22),
                            dimension: 22
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.name)
                                .font(.focallyBodyBold)
                                .foregroundStyle(Color.focallyOnSurface)
                            Text("\(mode.durationMinutes) min")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }

                        Spacer()

                        if mode.enableDND {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(Color.focallyPrimary)
                        }
                    }
                    .padding(12)
                    .background(Color.focallySurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if let onAddMode {
                Button(action: onAddMode) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                        Text("Add Mode")
                            .font(.focallyBody)
                    }
                    .foregroundStyle(Color.focallyPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.focallySurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeSessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EmojiView(
                    timerService.currentEmoji,
                    customEmojiImageURLs: slackService.workspaceEmojiImageURLs,
                    workspaceEmojiCodes: slackService.workspaceEmojiCodes,
                    font: .system(size: 20),
                    dimension: 20
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(timerService.currentActivity)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text(timerService.isPaused ? "Paused" : timerService.phaseName)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
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

            ProgressView(value: timerService.progress)
                .progressViewStyle(.linear)
                .tint(Color.focallyPrimary)

            Text(dndService.isDNDActive ? "Do Not Disturb is active" : "Do Not Disturb is off")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
        .padding(12)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.focallyOutline, lineWidth: 0.5)
        }
        .padding(.horizontal, 4)
    }

    private var footerStatus: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Label(slackService.isEnabled ? "Slack ready" : "Slack off", systemImage: "message.fill")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                Spacer()

                Label(dndService.isDNDActive ? "DND Active" : "DND Off", systemImage: "moon.fill")
                    .font(.focallyCaption)
                    .foregroundStyle(dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var backgroundMaterial: some View {
        Group {
            if colorScheme == .dark {
                Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.3))
            } else {
                Rectangle().fill(.ultraThinMaterial).overlay(Color.white.opacity(0.2))
            }
        }
    }
}
