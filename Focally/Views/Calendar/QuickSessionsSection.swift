import SwiftUI

struct QuickSessionsSection: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var timerService: FocusTimerService

    @State private var taskInput = ""
    @State private var selectedEmoji = "🎯"
    @State private var selectedDuration = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 10) {
                if calendarService.isEnabled {
                    CalendarStatusCard()
                }

                if !timerService.hasSession {
                    quickStartControls
                }
            }
        }
        .padding(14)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear(perform: syncFromService)
    }

    private var sectionHeader: some View {
        Text("Quick sessions")
            .font(.focallyBodyBold)
            .foregroundStyle(Color.focallyOnSurface)
    }

    private var quickStartControls: some View {
        VStack(spacing: 10) {
            emojiSelector
            taskNameInput
            slackStatusPreview

            DurationControl(minutes: $selectedDuration, range: 5...180, step: 5)
                .padding(.horizontal, 2)

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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .onSubmit(startSession)
            .accessibilityLabel("Quick session name")
    }

    private var slackStatusPreview: some View {
        Text("Slack status: \(selectedEmoji)")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.focallyOnSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Slack status preview \(selectedEmoji)")
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: startSession) {
                HStack {
                    Label("Start focus", systemImage: "play.fill")
                        .font(.focallyBodyBold)
                    Spacer()
                    Text("\(selectedDuration)m")
                        .font(.focallyCaption)
                }
                .foregroundStyle(Color.focallyOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.focallySecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start focus session")
            .accessibilityHint("Starts a quick focus session for \(selectedDuration) minutes")

            Button(action: startPomodoro) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Pomodoro")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurface)
                    Text("25 · 5 cadence, 4 rounds")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.focallySurfaceContainerLowest.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Pomodoro")
            .accessibilityHint("Starts a Pomodoro session using the selected emoji")
        }
    }

    private var borderColor: Color {
        Color.focallyCardBorder.opacity(0.5)
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
        let activity = trimmed.isEmpty ? "Focus Session" : trimmed
        timerService.updateWorkDuration(minutes: selectedDuration)
        timerService.startWorkSession(activity: activity, emoji: selectedEmoji, durationMinutes: selectedDuration)
        taskInput = ""
    }

    private func startPomodoro() {
        let trimmed = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = trimmed.isEmpty ? "Pomodoro" : trimmed
        timerService.startPomodoroSession(activity: activity, emoji: selectedEmoji)
        taskInput = ""
    }
}
