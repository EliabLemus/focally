import SwiftUI

struct QuickSessionsSection: View {
    @Environment(GoogleCalendarService.self) private var calendarService
    @Environment(FocusTimerService.self) private var timerService
    @Environment(SlackService.self) private var slackService

    @State private var taskInput = ""
    @State private var selectedEmoji = "🎯"
    @State private var selectedDuration = 25

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            sectionHeader

            VStack(spacing: FocallySpacing.small) {
                if calendarService.isEnabled {
                    CalendarStatusCard()
                }

                if !timerService.hasSession {
                    quickStartControls
                }
            }
        }
        .padding(FocallySpacing.medium)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.large))
        .onAppear(perform: syncFromService)
    }

    private var sectionHeader: some View {
        Text("Quick sessions")
            .font(.focallyBodyBold)
            .foregroundStyle(Color.focallyOnSurface)
    }

    private var quickStartControls: some View {
        VStack(spacing: FocallySpacing.small) {
            emojiSelector
            taskNameInput
            slackStatusPreview

            DurationControl(minutes: $selectedDuration, range: 5...180, step: 5)
                .padding(.horizontal, FocallySpacing.extraSmall)

            actionButtons
        }
    }

    private var emojiSelector: some View {
        CompactStatusEmojiButton(selection: $selectedEmoji, options: FocusStatusOption.common)
            .accessibilityLabel("Choose Slack status emoji")
    }

    private var taskNameInput: some View {
        TextField("What are you focusing on?", text: $taskInput)
            .font(.focallyBody)
            .foregroundStyle(Color.focallyOnSurface)
            .textFieldStyle(.plain)
            .padding(.horizontal, FocallySpacing.medium)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: FocallyRadius.medium)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .onSubmit(startSession)
            .accessibilityLabel("Quick session name")
    }

    private var slackStatusPreview: some View {
        let displayEmoji = emojiDisplayString(for: selectedEmoji)
        return Text("Slack status: \(displayEmoji)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.focallyOnSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Slack status preview \(displayEmoji)")
    }

    /// Convierte un shortcode o unicode a su representación de display
    private func emojiDisplayString(for emoji: String) -> String {
        if Self.isSlackShortcode(emoji) {
            return EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? emoji
        }
        return emoji
    }

    private static func isSlackShortcode(_ value: String) -> Bool {
        value.hasPrefix(":") && value.hasSuffix(":") && value.count > 2
    }

    private var actionButtons: some View {
        HStack(spacing: FocallySpacing.medium) {
            Button(action: startSession) {
                HStack {
                    Label("Start focus", systemImage: "play.fill")
                        .font(.focallyBodyBold)
                    Spacer()
                    Text("\(selectedDuration)m")
                        .font(.focallyCaption)
                }
                .foregroundStyle(Color.focallyOnPrimary)
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.vertical, FocallySpacing.small)
                .background(Color.focallySecondary)
                .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start focus session")
            .accessibilityHint("Starts a quick focus session for \(selectedDuration) minutes")

            Button(action: startPomodoro) {
                VStack(alignment: .leading, spacing: FocallySpacing.extraSmall) {
                    Text("Start Pomodoro")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurface)
                    Text("25 · 5 cadence, 4 rounds")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.vertical, FocallySpacing.small)
                .background(Color.focallySurfaceContainerLowest.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Pomodoro")
            .accessibilityHint("Starts a Pomodoro session using the selected emoji")
        }
    }

    private var borderColor: Color {
        Color.focallyOutline.opacity(0.5)
    }

    private var sectionBackground: Color {
        Color.focallySurfaceContainerLowest.opacity(0.65)
    }

    private func syncFromService() {
        if taskInput.isEmpty {
            taskInput = timerService.currentActivity
        }
        selectedEmoji = timerService.currentEmoji
        selectedDuration = timerService.workDurationMinutes
    }

    private func startSession() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity: String = trimmed.isEmpty ? "Focus Session" : trimmed
        timerService.updateWorkDuration(minutes: selectedDuration)
        timerService.startWorkSession(
            activity: activity,
            emoji: selectedEmoji,
            durationMinutes: selectedDuration,
            taskType: TaskType.deepWork
        )
        taskInput = ""
    }

    private func startPomodoro() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity: String = trimmed.isEmpty ? "Pomodoro" : trimmed
        timerService.startPomodoroSession(activity: activity, emoji: selectedEmoji)
        taskInput = ""
    }
}
