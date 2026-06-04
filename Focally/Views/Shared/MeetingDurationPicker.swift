import SwiftUI

struct MeetingDurationPicker: View {
    @Binding var selectedDuration: Int
    let availableDurations: [Int]
    let onDurationSelected: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.small) {
            Text("Meeting Duration")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Picker("Meeting Duration", selection: $selectedDuration) {
                ForEach(availableDurations, id: \.self) { minutes in
                    Text(durationLabel(for: minutes))
                        .tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Meeting Duration")
            .onChange(of: selectedDuration) { _, newValue in
                onDurationSelected(newValue)
            }
        }
        .padding(FocallySpacing.medium)
        .background(Color.focallySurfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.medium))
    }

    private func durationLabel(for minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }
}

#Preview {
    MeetingDurationPicker(
        selectedDuration: .constant(30),
        availableDurations: PredefinedTask.meetingDurations,
        onDurationSelected: { _ in }
    )
    .padding()
    .background(Color.focallySurface)
}
