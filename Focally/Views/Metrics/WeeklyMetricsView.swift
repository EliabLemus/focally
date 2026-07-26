import SwiftUI

struct WeeklyMetricsView: View {
    @State private var weekAnchorDate: Date = Date()
    @State private var selectedDayOfWeeks: Set<Int> = []
    @State private var showDayOfWeekFilter = false

    private var metrics: WeeklyMetrics? {
        if selectedDayOfWeeks.isEmpty {
            return FocusMetricsService.shared.getWeeklyMetrics(for: weekAnchorDate)
        }
        return FocusMetricsService.shared.getWeeklyMetrics(for: weekAnchorDate, dayOfWeeks: selectedDayOfWeeks)
    }

    private var weekRangeText: String {
        let calendar = isoCalendar
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekAnchorDate) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return "\(formatter.string(from: weekInterval.start)) – \(formatter.string(from: weekInterval.end.addingTimeInterval(-1)))"
    }

    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            // Week selector
            HStack(spacing: FocallySpacing.medium) {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Text(weekRangeText)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            Button(action: { showDayOfWeekFilter.toggle() }) {
                HStack(spacing: FocallySpacing.extraSmall) {
                    Image(systemName: selectedDayOfWeeks.isEmpty ? "calendar" : "calendar.badge.checkmark")
                        .font(.system(size: 14))
                    Text(
                        selectedDayOfWeeks.isEmpty
                            ? AppLanguage.shared.localizedString("metrics_filter_all_days")
                            : AppLanguage.shared.localizedString("metrics_filter_days")
                    )
                }
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDayOfWeekFilter) {
                DayOfWeekFilterSheet(selectedDays: $selectedDayOfWeeks)
            }

            LocalizedText("metrics_weekly_title")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            if let metrics {
                LazyVGrid(columns: [
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
                        title: "metrics_avg_focus_time",
                        value: metrics.avgDailyFocusTimeFormatted
                    )
                    MetricCard(
                        icon: "brain.head.profile.fill",
                        title: "metrics_focus_time_type",
                        value: metrics.focusTimeDurationFormatted
                    )
                    MetricCard(
                        icon: "person.2.fill",
                        title: "metrics_meeting_type",
                        value: metrics.meetingDurationFormatted
                    )
                    MetricCard(
                        icon: "tray.fill",
                        title: "metrics_inbox_type",
                        value: metrics.inboxDurationFormatted
                    )
                    MetricCard(
                        icon: "star.fill",
                        title: "metrics_custom_type",
                        value: metrics.customDurationFormatted
                    )
                }

                // Chart placeholder (v0.10.0)
                VStack(spacing: FocallySpacing.extraSmall) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.focallyOutline)

                    LocalizedText("metrics_chart_placeholder")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.medium)
                        .fill(Color.focallySurfaceContainer)
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

    private func previousWeek() {
        weekAnchorDate = isoCalendar.date(byAdding: .weekOfYear, value: -1, to: weekAnchorDate) ?? weekAnchorDate
    }

    private func nextWeek() {
        weekAnchorDate = isoCalendar.date(byAdding: .weekOfYear, value: 1, to: weekAnchorDate) ?? weekAnchorDate
    }
}
