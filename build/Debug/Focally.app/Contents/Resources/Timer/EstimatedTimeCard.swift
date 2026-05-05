import SwiftUI

struct EstimatedTimeCard: View {
    @Environment(\.colorScheme) var colorScheme

    private let estimatedEndTime = Date().addingTimeInterval(25 * 60)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 20))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated End")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("11:45 AM")
                    .font(.focallyH2)
            }
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
