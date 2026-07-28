import SwiftUI

struct MenuBarDropdownView: View {
    @Environment(FocusModeStore.self) private var focusModeStore
    @Environment(FocusTimerService.self) private var timerService
    @Environment(DNDService.self) private var dndService
    @Environment(SlackService.self) private var slackService
    @Environment(CalendarSlackIntegrationService.self) private var calendarService
    @Environment(UpdateCheckerService.self) private var updateChecker
    @Environment(\.colorScheme) private var colorScheme

    var onAddMode: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Update Available Badge
            if updateChecker.isNewVersionAvailable {
                Button(action: {
                    if let url = updateChecker.updateUrl {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: FocallySpacing.extraSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        LocalizedText("update_available_badge")
                            .font(.focallyBodyBold)
                        if let version = updateChecker.latestVersion {
                            Text(String(format: AppLanguage.shared.localizedString("update_version"), version))
                                .font(.focallyCaption)
                        }
                    }
                    .foregroundStyle(Color.focallyOnPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.focallyPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.small))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.top, FocallySpacing.medium)
            }

            headerRow

            ScrollView {
                VStack(spacing: 14) {
                    if let meeting = calendarService.currentMeeting {
                        VStack(alignment: .leading, spacing: 6) {
                            LocalizedText("menubar_current_meeting")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)

                            CalendarMeetingCard(meeting: meeting, isActive: true)
                        }

                        Divider()
                            .padding(.horizontal, 4)
                    }

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
            LocalizedText("menubar_focus")
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
            LocalizedText("menubar_quick_start")
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

                        if mode.enableMacOSDND {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(Color.focallyPrimary)
                        }
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                    .background(Color.focallySurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }

            if let onAddMode {
                Button(action: onAddMode) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                        LocalizedText("menubar_add_mode")
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

                    Text(timerService.isPaused ? AppLanguage.shared.localizedString("focus_paused") : timerService.phaseName)
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

            Text(dndService.isDNDActive ? AppLanguage.shared.localizedString("focus_dnd_active") : AppLanguage.shared.localizedString("focus_dnd_inactive"))
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
                Label(slackService.isEnabled ? AppLanguage.shared.localizedString("menubar_slack_ready") : AppLanguage.shared.localizedString("menubar_slack_off"), systemImage: "message.fill")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                Spacer()

                Label(dndService.isDNDActive ? AppLanguage.shared.localizedString("menubar_dnd_active") : AppLanguage.shared.localizedString("menubar_dnd_off"), systemImage: "moon.fill")
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
