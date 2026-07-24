import SwiftUI

// MARK: - MetricsSubpage

enum MetricsSubpage: CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { localizationKey }

    var localizationKey: String {
        switch self {
        case .daily: return "metrics_daily_title"
        case .weekly: return "metrics_weekly_title"
        case .monthly: return "metrics_monthly_title"
        }
    }

    var localizedLabel: String {
        String(localized: LocalizedStringResource(stringLiteral: localizationKey))
    }

    var icon: String {
        switch self {
        case .daily: return "calendar.day.timeline.left"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        }
    }
}

// MARK: - MetricsPage

struct MetricsPage: View {
    @State private var selectedSubpage: MetricsSubpage = .daily

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(MetricsSubpage.allCases) { subpage in
                    Button(action: {
                        selectedSubpage = subpage
                    }) {
                        HStack(spacing: FocallySpacing.small) {
                            Image(systemName: subpage.icon)
                                .font(.system(size: 13))
                                .frame(width: 18)

                            Text(subpage.localizedLabel)
                                .font(selectedSubpage == subpage ? .focallyBodyBold : .focallyBody)
                        }
                        .foregroundStyle(selectedSubpage == subpage ? Color.focallyOnSurface : Color.focallyOutline)
                        .padding(.horizontal, FocallySpacing.small)
                        .padding(.vertical, FocallySpacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.small)
                                .fill(selectedSubpage == subpage ? Color.focallySurfaceContainerHigh : Color.clear)
                        )
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(FocallySpacing.small)
            .frame(width: 160)
            .background(Color.focallySurfaceContainerLow)

            // Content
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("metrics_tab")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                    Text("›")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                    Text(selectedSubpage.localizedLabel)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .padding(.horizontal, FocallySpacing.large)
                .padding(.top, FocallySpacing.medium)
                .padding(.bottom, FocallySpacing.small)

                ScrollView {
                    subpageContent
                        .padding(.horizontal, FocallySpacing.large)
                        .padding(.bottom, FocallySpacing.large)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.focallyBackground)
        }
    }

    @ViewBuilder
    private var subpageContent: some View {
        switch selectedSubpage {
        case .daily:
            DailyMetricsView()
        case .weekly:
            WeeklyMetricsView()
        case .monthly:
            MonthlyMetricsView()
        }
    }
}
