import SwiftUI

struct FocallyFocusScoreCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Left: Score info
            VStack(alignment: .leading, spacing: 4) {
                Text("FOCUS SCORE")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyPrimary)
                    .textCase(.uppercase)
                    .tracking(1)

                Text("94")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(Color.focallyOnSurface)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                    Text("+2.3% vs last week")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyTertiary)
                }

                Text("High focus efficiency with minimal distractions")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Spacer()

            // Right: Score ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.focallySurfaceContainer, lineWidth: 12)

                // Progress circle
                Circle()
                    .trim(from: 0, to: 0.94)
                    .stroke(
                        Color.focallyPrimary,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: 0.94)

                // Center icon
                Image(systemName: "bolt.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.focallyPrimary)
            }
            .frame(width: 80, height: 80)
        }
        .padding(16)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 0.5)
        }
    }

    private var borderColor: Color {
        Color.focallyCardBorder
    }
}
