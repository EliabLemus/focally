import SwiftUI
import Charts

struct FocusTrendChart: View {
    let data: [AnalyticsService.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Focus Trend")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Text("This Week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.focallyOutline)
            }

            // Chart
            Chart(data) { point in
                LineMark(
                    x: .value("Day", point.label),
                    y: .value("Minutes", point.minutes)
                )
                .foregroundStyle(Color.focallyPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Day", point.label),
                    y: .value("Minutes", point.minutes)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.focallyPrimary.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.focallyOutline)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color.focallyOutline)
                }
            }
            .frame(height: 200)
            .padding(.vertical, 8)
        }
        .padding(20)
        .focallyCard()
    }
}
