import SwiftUI

struct FocallyCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.focallySurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.focallyOutline, lineWidth: 0.5)
            )
            .modifier(cardShadowModifier)
    }

    private var cardShadowModifier: some ViewModifier {
        // Spec: No shadow in dark mode, use border white/8 instead
        // Light mode: subtle shadow (kept at radius 2 for cards, not popovers)
        ShadowModifier(
            color: colorScheme == .dark ? .clear : .black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Shadow Helper

private struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension View {
    func focallyCard() -> some View {
        modifier(FocallyCardModifier())
    }
}
