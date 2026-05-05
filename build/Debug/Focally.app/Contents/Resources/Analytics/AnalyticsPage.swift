import SwiftUI
import Charts

struct AnalyticsPage: View {
    @State private var selectedRangeIndex: Int = 0
    @StateObject private var analyticsService = AnalyticsService()
    @State private var showingExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // TopBar
            TopBarView {
                Text("Focus Analytics")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)
            }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Focus Analytics")
                        .font(.focallyDisplay)
                        .foregroundStyle(Color.focallyOnSurface)

                    Spacer()

                    // Time range toggle
                    FocallySegmentedControl(selection: $selectedRangeIndex, options: ["Weekly", "Monthly"])
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.top, FocallySpacing.lg)

                Text("Detailed insights into your deep work performance.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOutline)
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.bottom, FocallySpacing.lg)

                ScrollView {
                    VStack(spacing: FocallySpacing.lg) {
                        // Row 1: Focus Score + Avg Session Depth
                        HStack(alignment: .top, spacing: FocallySpacing.gutter) {
                            FocusScoreCard(scoreData: analyticsService.focusScore, score: analyticsService.focusScore.value)
                                .frame(maxWidth: .infinity)

                            AvgSessionDepthCard(hours: analyticsService.avgSessionDepth.hours, minutes: analyticsService.avgSessionDepth.minutes)
                                .frame(maxWidth: .infinity)
                        }

                        // Row 2: Focus Trend + Allocation
                        HStack(alignment: .top, spacing: FocallySpacing.gutter) {
                            FocusTrendChart(data: analyticsService.trendData)
                                .frame(maxWidth: .infinity)

                            FocusAllocationCard(allocation: analyticsService.categories)
                                .frame(maxWidth: .infinity)
                        }

                        // Row 3: Recent Sessions
                        RecentSessionsList(sessions: analyticsService.recentSessions, onExportTap: { showingExportSheet = true })
                    }
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.bottom, FocallySpacing.lg)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.focallyBackground)
            .sheet(isPresented: $showingExportSheet) {
                VStack(spacing: 16) {
                    Text("Export Data")
                        .font(.focallyH1)
                    Text("Coming soon — CSV export will be available in a future update.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                        .multilineTextAlignment(.center)
                    Button("Close") { showingExportSheet = false }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.focallyPrimary)
                }
                .padding(FocallySpacing.xl)
                .frame(width: 400)
            }
        }
    }
}

// MARK: - Avg Session Depth Card

private struct AvgSessionDepthCard: View {
    let hours: Int
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.focallyTertiaryContainer.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.focallyTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AVG. SESSION DEPTH")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                        .tracking(1.5)

                    Text("\(hours)h \(minutes)m")
                        .font(.focallyH2)
                        .foregroundStyle(Color.focallyOnSurface)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.focallySurfaceContainerLow)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.focallyTertiary)
                        .frame(width: geometry.size.width * 0.75, height: 4)
                }
            }
            .frame(height: 4)

            Text("30 mins longer than baseline")
                .font(.focallyMicro)
                .foregroundStyle(Color.focallyOutline.opacity(0.7))
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
    }
}
