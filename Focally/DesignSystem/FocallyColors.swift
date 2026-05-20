import SwiftUI

extension Color {
    // Primary
    static let focallyPrimary: Color = Color("focallyPrimary")
    static let focallyOnPrimary: Color = Color("focallyOnPrimary")
    static let focallyPrimaryContainer: Color = Color("focallyPrimaryContainer")
    static let focallyPrimaryFixed: Color = Color("focallyPrimaryFixed")
    static let focallyPrimaryFixedDim: Color = Color("focallyPrimaryFixedDim")
    static let focallyOnPrimaryFixed: Color = Color("focallyOnPrimaryFixed")
    static let focallyOnPrimaryFixedVariant: Color = Color("focallyOnPrimaryFixedVariant")
    static let focallyOnPrimaryContainer: Color = Color("focallyOnPrimaryContainer")

    // Tertiary
    static let focallyTertiary: Color = Color("focallyTertiary")
    static let focallyTertiaryContainer: Color = Color("focallyTertiaryContainer")
    static let focallyTertiaryFixed: Color = Color("focallyTertiaryFixed")
    static let focallyTertiaryFixedDim: Color = Color("focallyTertiaryFixedDim")
    static let focallyOnTertiary: Color = Color("focallyOnTertiary")
    static let focallyOnTertiaryContainer: Color = Color("focallyOnTertiaryContainer")

    // Secondary
    static let focallySecondary: Color = Color("focallySecondary")
    static let focallyOnSecondary: Color = Color("focallyOnSecondary")
    static let focallySecondaryContainer: Color = Color("focallySecondaryContainer")
    static let focallySecondaryFixed: Color = Color("focallySecondaryFixed")
    static let focallySecondaryFixedDim: Color = Color("focallySecondaryFixedDim")
    static let focallyOnSecondaryContainer: Color = Color("focallyOnSecondaryContainer")
    static let focallyOnSecondaryFixed: Color = Color("focallyOnSecondaryFixed")
    static let focallyOnSecondaryFixedVariant: Color = Color("focallyOnSecondaryFixedVariant")

    // Surface
    static let focallyOnSurface: Color = Color("focallyOnSurface")
    static let focallyOnSurfaceVariant: Color = Color("focallyOnSurfaceVariant")
    static let focallyOutline: Color = Color("focallyOutline")
    static let focallyOutlineVariant: Color = Color("focallyOutlineVariant")
    static let focallySurface: Color = Color("focallySurface")
    static let focallySurfaceBright: Color = Color("focallySurfaceBright")
    static let focallySurfaceDim: Color = Color("focallySurfaceDim")
    static let focallySurfaceContainerLowest: Color = Color("focallySurfaceContainerLowest")
    static let focallySurfaceContainerLow: Color = Color("focallySurfaceContainerLow")
    static let focallySurfaceContainer: Color = Color("focallySurfaceContainer")
    static let focallySurfaceContainerHigh: Color = Color("focallySurfaceContainerHigh")
    static let focallySurfaceContainerHighest: Color = Color("focallySurfaceContainerHighest")
    static let focallySurfaceVariant: Color = Color("focallySurfaceVariant")
    static let focallySurfaceTint: Color = Color("focallySurfaceTint")
    static let focallyBackground: Color = Color("focallyBackground")
    static let focallyOnBackground: Color = Color("focallyOnBackground")

    // Inverse
    static let focallyInverseSurface: Color = Color("focallyInverseSurface")
    static let focallyInverseOnSurface: Color = Color("focallyInverseOnSurface")
    static let focallyInversePrimary: Color = Color("focallyInversePrimary")

    // Error
    static let focallyError: Color = Color("focallyError")
    static let focallyErrorContainer: Color = Color("focallyErrorContainer")
    static let focallyOnError: Color = Color("focallyOnError")
    static let focallyOnErrorContainer: Color = Color("focallyOnErrorContainer")

    init(hex: String) {
        let hex: String = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
