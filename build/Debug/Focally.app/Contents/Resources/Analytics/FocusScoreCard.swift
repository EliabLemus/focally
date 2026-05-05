import SwiftUI

struct FocusScoreCard: View {
    let scoreData: AnalyticsService.ScoreData
    let score: Int

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS SCORE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.focallyPrimary)
                    .tracking(1.5)

                Text("\(score)")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(Color.focallyOnSurface)

                HStack(spacing: 4) {
                    if scoreData.delta > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.focallyTertiaryContainer)
                    } else if scoreData.delta < 0 {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.focallyErrorContainer)
                    }
                    Text("\(scoreData.delta > 0 ? "+" : "")\(scoreData.delta)%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(scoreData.delta > 0 ? Color.focallyTertiaryContainer : Color.focallyErrorContainer)

                    Text("vs last period")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyOutline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.focallySurfaceContainerLowest.opacity(0.5))
                .cornerRadius(6)

                Text(scoreData.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.focallyOutline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Score ring
            FocusScoreRing(score: score)
        }
        .padding(20)
        .focallyCard()
    }
}

struct FocusScoreRing: View {
    let score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.focallySurfaceContainer, lineWidth: 12)

            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(
                    Color.focallyPrimary,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: score)

            Image(systemName: "bolt.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.focallyPrimary)
        }
        .frame(width: 160, height: 160)
    }
}
