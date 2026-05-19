import SwiftUI

struct TopBarView<LeftContent: View, RightContent: View>: View {
    let leftContent: LeftContent
    let rightContent: RightContent

    init(
        @ViewBuilder leftContent: () -> LeftContent,
        @ViewBuilder rightContent: () -> RightContent = { EmptyView() }
    ) {
        self.leftContent = leftContent()
        self.rightContent = rightContent()
    }

    var body: some View {
        HStack(spacing: 0) {
            leftContent
                .padding(.leading, FocallySpacing.md)

            Spacer()

            rightContent
            .padding(.trailing, FocallySpacing.md)
        }
        .frame(height: 48)
        .background(Color.focallySurfaceContainerLowest.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.focallyOutline)
        }
    }
}
