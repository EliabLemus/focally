import SwiftUI

struct FocusAllocationCard: View {
    let allocation: [AnalyticsService.Category]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Allocation")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.focallyOnSurface)

            ForEach(allocation) { category in
                HStack(alignment: .top, spacing: 12) {
                    // Color bar
                    Rectangle()
                        .fill(category.color)
                        .frame(width: 2, height: 32)
                        .cornerRadius(1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.focallyOnSurface)

                        Text("\(category.hours, specifier: "%.1f")h • \(category.percentage, specifier: "%.0f")%")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.focallyOutline)
                    }

                    Spacer()

                    Text("\(category.percentage, specifier: "%.0f")%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .background(Color.focallySurfaceContainerLowest.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.focallyOutline.opacity(0.1))
                )
            }
        }
        .padding(20)
        .focallyCard()
    }
}
