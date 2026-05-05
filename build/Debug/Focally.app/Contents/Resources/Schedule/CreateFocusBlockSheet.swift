import SwiftUI

struct CreateFocusBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var durationMinutes: Int = 60

    let editingBlock: FocusBlock?

    init(block: FocusBlock? = nil) {
        self.editingBlock = block
        if let block = block {
            self._title = State(initialValue: block.title)
            self._startDate = State(initialValue: block.startDate)
            self._durationMinutes = State(initialValue: Int(block.endDate.timeIntervalSince(block.startDate) / 60))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingBlock == nil ? "New Focus Block" : "Edit Focus Block")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.focallySecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Form
            Form {
                Section {
                    TextField("Task name", text: $title)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurface)

                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                } header: {
                    Text("Details")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.focallyOutline)
                }

                Section {
                    HStack {
                        Image(systemName: "hourglass")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.focallyPrimary)

                        TextField("Duration (minutes)", value: $durationMinutes, format: .number)
                            .font(.system(size: 14))
    
                    }
                } header: {
                    Text("Duration")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.focallyOutline)
                }
            }
            .formStyle(.grouped)

            Spacer()

            // Footer buttons
            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.focallyOutline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Create or update block
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.focallyOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.focallyPrimary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 400, minHeight: 500)
        .background(Color.focallySurfaceContainer)
    }
}
