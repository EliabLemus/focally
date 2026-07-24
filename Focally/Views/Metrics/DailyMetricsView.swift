import SwiftUI

struct DailyMetricsView: View {
    @State private var selectedDate: Date = Date()

    private var metrics: DailyMetrics? {
        FocusMetricsService.shared.getDailyMetrics(for: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            // Date picker
            HStack(spacing: FocallySpacing.medium) {
                Text("metrics_daily_title")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .labelsHidden()
                    .environment(\.locale, Locale.current)
            }

            if let metrics {
                // Summary cards
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
            } else {
                // Empty state
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

// MARK: - MetricCard (shared component)

struct MetricCard: View {
    let icon: String
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.extraSmall) {
            HStack(spacing: FocallySpacing.extraSmall) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.focallyTertiary)

                Text(title)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Text(value)
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)
        }
        .padding(FocallySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.medium)
                .fill(Color.focallySurfaceContainer)
        )
    }
}
