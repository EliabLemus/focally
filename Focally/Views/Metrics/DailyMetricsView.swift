import SwiftUI

struct DailyMetricsView: View {
    @State private var selectedDate: Date = Date()

    private var metrics: DailyMetrics? {
        FocusMetricsService.shared.getDailyMetrics(for: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            // Date navigation with prev/next chevrons
            HStack(spacing: FocallySpacing.medium) {
                Text("metrics_daily_title")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .help(String(localized: "metrics_prev_day"))

                Text(selectedDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                    .frame(minWidth: 120)

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .disabled(Calendar.current.isDateInToday(selectedDate) || Calendar.current.isDate(selectedDate, inSameDayAs: Date()))
                .help(String(localized: "metrics_next_day"))
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

    // MARK: - Date Navigation

    private func changeDate(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
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
