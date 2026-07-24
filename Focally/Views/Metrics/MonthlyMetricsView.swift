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

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            // Month picker
            HStack(spacing: FocallySpacing.medium) {
                Text("metrics_monthly_title")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Text(monthText)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
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

                    Text("metrics_export_csv")
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

                    Text("metrics_no_data")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }

            Spacer()
        }
    }
}
