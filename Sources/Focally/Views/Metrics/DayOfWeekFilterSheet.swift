import SwiftUI

struct DayOfWeekFilterSheet: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.dismiss) private var dismiss

    private let weekDays: [(weekday: Int, label: String)] = [
        (1, "S"),
        (2, "M"),
        (3, "T"),
        (4, "W"),
        (5, "T"),
        (6, "F"),
        (7, "S"),
    ]

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            Text(AppLanguage.shared.localizedString("metrics_filter_days_title"))
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            HStack(spacing: FocallySpacing.medium) {
                ForEach(weekDays, id: \.weekday) { day in
                    Button(action: { toggle(day.weekday) }) {
                        Text(day.label)
                            .font(.focallyBodyBold)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day.weekday) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                            )
                            .foregroundStyle(selectedDays.contains(day.weekday) ? .white : Color.focallyOnSurface)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FocallySpacing.large)

            Button(action: { selectedDays.removeAll() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_clear"))
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .buttonStyle(.plain)
            .disabled(selectedDays.isEmpty)

            Spacer()

            Button(action: { dismiss() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_done"))
                    .font(.focallyBodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FocallySpacing.medium)
                    .background(Color.focallyPrimary)
                    .cornerRadius(FocallyRadius.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.large)
        .frame(width: 400, height: 300)
        .background(Color.focallyBackground)
    }

    private func toggle(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }
    }
}
