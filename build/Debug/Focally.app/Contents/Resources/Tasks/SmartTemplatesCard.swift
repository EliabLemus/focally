import SwiftUI

struct SmartTemplatesCard: View {
    var body: some View {
        HStack(spacing: FocallySpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(Color.focallySecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Templates")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("AI can suggest task durations based on your past performance.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: {}) {
                Text("Enable AI Insights")
                    .font(.focallyButton)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.lg)
        .background(Color.focallySecondaryFixed)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .focallyCard()
    }
}
