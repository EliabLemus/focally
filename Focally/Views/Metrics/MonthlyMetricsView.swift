import SwiftUI

struct MonthlyMetricsView: View {
    @State private var selectedMonth: Date = Date()

    private var metrics: MonthlyMetrics? {
        FocusMetricsService.shared.getMonthlyMetrics(for: selectedMonth)
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: selectedMonth)
    }

    /// True if selectedMonth is in the same month as today (disables next button).
    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            // Month navigation with prev/next chevrons
            HStack(spacing: FocallySpacing.medium) {
                LocalizedText("metrics_monthly_title")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .help(AppLanguage.shared.localizedString("metrics_prev_month"))

                Text(monthText)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                    .frame(minWidth: 120)

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .help(AppLanguage.shared.localizedString("metrics_next_month"))
            }

            if let metrics {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: FocallySpacing.medium),
                    GridItem(.flexible(), spacing: FocallySpacing.medium),
                    GridItem(.flexible(), spacing: FocallySpacing.medium),
                ], spacing: FocallySpacing.medium) {
                    MetricCard(
                        icon: "checkmark.circle.fill",
                        title: "metrics_pomodoros_completed",
                        value: "\(metrics.pomodorosCompleted)"
                    )
                    MetricCard(
                        icon: "person.2.fill",
                        title: "metrics_meeting_time",
                        value: metrics.meetingTimeFormatted
                    )
                    MetricCard(
                        icon: "brain.head.profile.fill",
                        title: "metrics_total_focus_time",
                        value: metrics.totalFocusTimeFormatted
                    )
                }

                // Export CSV placeholder (v0.10.0)
                HStack(spacing: FocallySpacing.small) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOutline)

                    LocalizedText("metrics_export_csv")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.vertical, FocallySpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.small)
                        .stroke(Color.focallyOutlineVariant, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            } else {
                VStack(spacing: FocallySpacing.medium) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.focallyOutline)

                    LocalizedText("metrics_no_data")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    /// Shifts selectedMonth by the given number of months (negative for previous, positive for next).
    private func changeMonth(by months: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: months, to: selectedMonth) {
            // Don't allow navigating past the current month
            if months > 0, calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) == false,
               newDate > Date() {
                return
            }
            selectedMonth = newDate
        }
    }
}
