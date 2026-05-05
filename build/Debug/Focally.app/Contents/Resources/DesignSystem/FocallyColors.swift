import SwiftUI

extension Color {
    // Primary
    static let focallyPrimary = Color("focallyPrimary")
    static let focallyOnPrimary = Color("focallyOnPrimary")
    static let focallyPrimaryContainer = Color("focallyPrimaryContainer")
    static let focallyPrimaryFixed = Color("focallyPrimaryFixed")
    static let focallyPrimaryFixedDim = Color("focallyPrimaryFixedDim")
    static let focallyOnPrimaryFixed = Color("focallyOnPrimaryFixed")
    static let focallyOnPrimaryFixedVariant = Color("focallyOnPrimaryFixedVariant")
    static let focallyOnPrimaryContainer = Color("focallyOnPrimaryContainer")

    // Tertiary
    static let focallyTertiary = Color("focallyTertiary")
    static let focallyTertiaryContainer = Color("focallyTertiaryContainer")
    static let focallyTertiaryFixed = Color("focallyTertiaryFixed")
    static let focallyTertiaryFixedDim = Color("focallyTertiaryFixedDim")
    static let focallyOnTertiary = Color("focallyOnTertiary")
    static let focallyOnTertiaryContainer = Color("focallyOnTertiaryContainer")

    // Secondary
    static let focallySecondary = Color("focallySecondary")
    static let focallyOnSecondary = Color("focallyOnSecondary")
    static let focallySecondaryContainer = Color("focallySecondaryContainer")
    static let focallySecondaryFixed = Color("focallySecondaryFixed")
    static let focallySecondaryFixedDim = Color("focallySecondaryFixedDim")
    static let focallyOnSecondaryContainer = Color("focallyOnSecondaryContainer")
    static let focallyOnSecondaryFixed = Color("focallyOnSecondaryFixed")
    static let focallyOnSecondaryFixedVariant = Color("focallyOnSecondaryFixedVariant")

    // Surface
    static let focallyOnSurface = Color("focallyOnSurface")
    static let focallyOnSurfaceVariant = Color("focallyOnSurfaceVariant")
    static let focallyOutline = Color("focallyOutline")
    static let focallyOutlineVariant = Color("focallyOutlineVariant")
    static let focallySurface = Color("focallySurface")
    static let focallySurfaceBright = Color("focallySurfaceBright")
    static let focallySurfaceDim = Color("focallySurfaceDim")
    static let focallySurfaceContainerLowest = Color("focallySurfaceContainerLowest")
    static let focallySurfaceContainerLow = Color("focallySurfaceContainerLow")
    static let focallySurfaceContainer = Color("focallySurfaceContainer")
    static let focallySurfaceContainerHigh = Color("focallySurfaceContainerHigh")
    static let focallySurfaceContainerHighest = Color("focallySurfaceContainerHighest")
    static let focallySurfaceVariant = Color("focallySurfaceVariant")
    static let focallySurfaceTint = Color("focallySurfaceTint")
    static let focallyBackground = Color("focallyBackground")
    static let focallyOnBackground = Color("focallyOnBackground")

    // Inverse
    static let focallyInverseSurface = Color("focallyInverseSurface")
    static let focallyInverseOnSurface = Color("focallyInverseOnSurface")
    static let focallyInversePrimary = Color("focallyInversePrimary")

    // Error
    static let focallyError = Color("focallyError")
    static let focallyErrorContainer = Color("focallyErrorContainer")
    static let focallyOnError = Color("focallyOnError")
    static let focallyOnErrorContainer = Color("focallyOnErrorContainer")

    static let focallyCardBorder = Color("focallyCardBorder")
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
