import SwiftUI

struct FocusModeEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draftMode: FocusMode
    let onSave: (FocusMode) -> Void

    init(mode: FocusMode, onSave: @escaping (FocusMode) -> Void) {
        _draftMode = State(initialValue: mode)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit \(draftMode.name)")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji")
                    .font(.focallyBodyBold)
                TextField(":brain:", text: $draftMode.emoji)
                    .textFieldStyle(.roundedBorder)
                Text("Enter Slack emoji shortcode, e.g. :brain:")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status message")
                    .font(.focallyBodyBold)
                TextField("In focus mode", text: $draftMode.statusText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.focallyBodyBold)
                Stepper("\(draftMode.durationMinutes) min", value: $draftMode.durationMinutes, in: 5...120, step: 5)
            }

            Toggle("Enable Do Not Disturb in Slack and macOS", isOn: $draftMode.enableDND)
                .font(.focallyBody)

            if draftMode.enableDND {
                Toggle("Enable Pomodoro", isOn: $draftMode.enablePomodoro)
                    .font(.focallyBody)
            }

            if draftMode.enableDND && draftMode.enablePomodoro {
                DisclosureGroup("Pomodoro settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Work: \(draftMode.pomodoroWorkMinutes) min", value: $draftMode.pomodoroWorkMinutes, in: 5...120, step: 5)
                        Stepper("Break: \(draftMode.pomodoroBreakMinutes) min", value: $draftMode.pomodoroBreakMinutes, in: 1...30, step: 1)
                        Stepper("Rounds: \(draftMode.pomodoroRounds)", value: $draftMode.pomodoroRounds, in: 1...12, step: 1)
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    onSave(draftMode.sanitized())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 430)
        .background(Color.focallyBackground)
    }
}
