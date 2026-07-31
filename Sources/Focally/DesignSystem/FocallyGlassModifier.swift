import SwiftUI

// MARK: - Glass Effect Modifier

/// Glass modifier based on Stitch Design System specs
///
/// Light theme: rgba(255,255,255,0.85) + blur 30px + inset border white/40
/// Dark theme: rgba(28,28,30,0.7) + blur 20px + border white/8
struct FocallyGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let style: GlassStyle

    enum GlassStyle {
        case popover
        case card
        case dropdown
    }

    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(glassBorder)
            .modifier(glassShadowModifier)
    }

    // MARK: - Background

    private var glassBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(red: 0.11, green: 0.11, blue: 0.12, opacity: 0.7)  // rgba(28,28,30,0.7)
                    .background(.ultraThinMaterial)
            } else {
                Color.white.opacity(0.85)
                    .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Border

    @ViewBuilder
    private var glassBorder: some View {
        if style == .card || style == .dropdown {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                    lineWidth: 0.5
                )
        }
    }

    // MARK: - Shadow

    private var glassShadowModifier: some ViewModifier {
        switch style {
        case .popover:
            // Spec: 0 10px 30px rgba(0,0,0,0.1)
            return ShadowModifier(
                color: .black.opacity(0.1),
                radius: 30,
                x: 0,
                y: 10
            )
        case .card:
            // No shadow in dark mode, subtle in light
            return ShadowModifier(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 2,
                x: 0,
                y: 1
            )
        case .dropdown:
            // Popover-style shadow for dropdowns
            return ShadowModifier(
                color: .black.opacity(0.1),
                radius: 30,
                x: 0,
                y: 10
            )
        }
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

// MARK: - Convenience Extensions

extension View {
    /// Apply glass effect with standard card styling
    func focallyGlassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(FocallyGlassModifier(cornerRadius: cornerRadius, style: .card))
    }

    /// Apply glass effect for popovers and modals
    func focallyGlassPopover(cornerRadius: CGFloat = 12) -> some View {
        modifier(FocallyGlassModifier(cornerRadius: cornerRadius, style: .popover))
    }

    /// Apply glass effect for dropdowns and menus
    func focallyGlassDropdown(cornerRadius: CGFloat = 12) -> some View {
        modifier(FocallyGlassModifier(cornerRadius: cornerRadius, style: .dropdown))
    }
}