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
                LocalizedText("metrics_daily_title")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .help(AppLanguage.shared.localizedString("metrics_prev_day"))

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
                .help(AppLanguage.shared.localizedString("metrics_next_day"))
            }

            if let metrics {
                // Summary cards
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
                        title: "metrics_total_focus_time",
                        value: metrics.totalFocusTimeFormatted
                    )
                }

                FocusTypeBreakdownGrid(
                    focusTimeDuration: metrics.focusTimeDuration,
                    meetingDuration: metrics.meetingDuration,
                    inboxDuration: metrics.inboxDuration,
                    customDuration: metrics.customDuration,
                    customTypeDurations: metrics.customTypeDurations,
                    calendarVideoCallDuration: metrics.calendarVideoCallDuration
                )
            } else {
                // Empty state
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

    // MARK: - Date Navigation

    private func changeDate(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }
}

// MARK: - Focus Type Breakdown

struct FocusTypeBreakdownGrid: View {
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    let customTypeDurations: [UUID: TimeInterval]
    let calendarVideoCallDuration: TimeInterval

    private let columns = [
        GridItem(.flexible(), spacing: FocallySpacing.medium),
        GridItem(.flexible(), spacing: FocallySpacing.medium),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            LocalizedText("metrics_built_in_types")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            LazyVGrid(columns: columns, spacing: FocallySpacing.medium) {
                durationCard(icon: "brain.head.profile.fill", title: "focus_mode_type_focus_time", duration: focusTimeDuration)
                durationCard(icon: "person.2.fill", title: "focus_mode_type_meeting", duration: meetingDuration)
                durationCard(icon: "tray.fill", title: "focus_mode_type_inbox", duration: inboxDuration)
                durationCard(icon: "star.fill", title: "focus_mode_type_custom", duration: customDuration)
            }

            if !customTypeDurations.isEmpty {
                LocalizedText("metrics_my_types")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                LazyVGrid(columns: columns, spacing: FocallySpacing.medium) {
                    ForEach(FocusTypesService.shared.customTypes) { type in
                        let duration = customTypeDurations[type.id, default: 0]
                        if duration > 0 {
                            MetricCard(
                                icon: "tag.fill",
                                title: "\(type.emoji) \(type.name)",
                                value: DailyMetrics.formatDuration(duration),
                                isLocalizedTitle: false
                            )
                        }
                    }
                }
            }

            if calendarVideoCallDuration > 0 {
                LocalizedText("calendar_video_calls")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                MetricCard(
                    icon: "video.fill",
                    title: "calendar_video_call_label",
                    value: DailyMetrics.formatDuration(calendarVideoCallDuration)
                )
            }
        }
    }

    private func durationCard(icon: String, title: String, duration: TimeInterval) -> some View {
        MetricCard(
            icon: icon,
            title: title,
            value: DailyMetrics.formatDuration(duration)
        )
    }
}

// MARK: - MetricCard (shared component)

struct MetricCard: View {
    @Environment(AppLanguage.self) private var appLanguage

    let icon: String
    let title: String
    let value: String
    var isLocalizedTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.extraSmall) {
            HStack(spacing: FocallySpacing.extraSmall) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.focallyTertiary)

                Text(isLocalizedTitle ? appLanguage.localizedString(title) : title)
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
