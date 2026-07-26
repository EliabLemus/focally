import SwiftUI

struct DayOfMonthFilterSheet: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.dismiss) private var dismiss

    private let daysInMonth = Array(1...31)

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            Text(AppLanguage.shared.localizedString("metrics_filter_days_title"))
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: FocallySpacing.small) {
                ForEach(daysInMonth, id: \.self) { day in
                    Button(action: { toggle(day) }) {
                        Text("\(day)")
                            .font(.focallyBodyBold)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                            )
                            .foregroundStyle(selectedDays.contains(day) ? .white : Color.focallyOnSurface)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { toggle(0) }) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(0) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                        )
                        .foregroundStyle(selectedDays.contains(0) ? .white : Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .help(AppLanguage.shared.localizedString("metrics_filter_last_day"))
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
        .frame(width: 420, height: 420)
        .background(Color.focallyBackground)
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}
