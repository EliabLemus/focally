import SwiftUI

struct FocallyCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.focallySurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.focallyCardBorder, lineWidth: 0.5)
            )
            .shadow(color: cardShadowColor, radius: 2, x: 0, y: 1)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.05)
    }
}

extension View {
    func focallyCard() -> some View {
        modifier(FocallyCardModifier())
    }
}
