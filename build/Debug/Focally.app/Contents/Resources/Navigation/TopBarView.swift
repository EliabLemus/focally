import SwiftUI

struct TopBarView<LeftContent: View>: View {
    let leftContent: LeftContent

    init(@ViewBuilder leftContent: () -> LeftContent) {
        self.leftContent = leftContent()
    }

    var body: some View {
        HStack(spacing: 0) {
            leftContent
                .padding(.leading, FocallySpacing.md)

            Spacer()

            HStack(spacing: 6) {
                // History button
                Button(action: {}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.focallySurfaceContainer)
                        )
                }
                .buttonStyle(.plain)

                // Settings button
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.focallySurfaceContainer)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, FocallySpacing.md)
        }
        .frame(height: 48)
        .background(Color.focallySurfaceContainerLowest.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.focallyCardBorder)
        }
    }
}
