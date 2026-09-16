import SwiftUI

/// Confirms and starts a pomodoro session attributed to a task.
struct StartPomodoroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusTimerService.self) private var timerService

    let task: TaskItem

    var body: some View {
        VStack(spacing: FocallySpacing.medium) {
            LocalizedText("tasks_pomodoro_sheet_title")
                .font(.focallyH2)

            Text(task.sanitizedTitle)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .multilineTextAlignment(.center)

            LocalizedText("tasks_pomodoro_sheet_detail")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .multilineTextAlignment(.center)

            HStack(spacing: FocallySpacing.small) {
                Button {
                    dismiss()
                } label: {
                    LocalizedText("tasks_cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button {
                    let draft = FocusSessionDraft(mode: FocusMode.builtInModes[0], activity: task.sanitizedTitle)
                    timerService.startSession(draft: draft, taskID: task.id)
                    dismiss()
                } label: {
                    LocalizedText("tasks_start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(FocallySpacing.large)
        .frame(width: 360)
    }
}
