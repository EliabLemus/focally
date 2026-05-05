import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "focallyBackground" asset catalog color resource.
    static let focallyBackground = DeveloperToolsSupport.ColorResource(name: "focallyBackground", bundle: resourceBundle)

    /// The "focallyCardBorder" asset catalog color resource.
    static let focallyCardBorder = DeveloperToolsSupport.ColorResource(name: "focallyCardBorder", bundle: resourceBundle)

    /// The "focallyError" asset catalog color resource.
    static let focallyError = DeveloperToolsSupport.ColorResource(name: "focallyError", bundle: resourceBundle)

    /// The "focallyErrorContainer" asset catalog color resource.
    static let focallyErrorContainer = DeveloperToolsSupport.ColorResource(name: "focallyErrorContainer", bundle: resourceBundle)

    /// The "focallyInverseOnSurface" asset catalog color resource.
    static let focallyInverseOnSurface = DeveloperToolsSupport.ColorResource(name: "focallyInverseOnSurface", bundle: resourceBundle)

    /// The "focallyInversePrimary" asset catalog color resource.
    static let focallyInversePrimary = DeveloperToolsSupport.ColorResource(name: "focallyInversePrimary", bundle: resourceBundle)

    /// The "focallyInverseSurface" asset catalog color resource.
    static let focallyInverseSurface = DeveloperToolsSupport.ColorResource(name: "focallyInverseSurface", bundle: resourceBundle)

    /// The "focallyOnBackground" asset catalog color resource.
    static let focallyOnBackground = DeveloperToolsSupport.ColorResource(name: "focallyOnBackground", bundle: resourceBundle)

    /// The "focallyOnError" asset catalog color resource.
    static let focallyOnError = DeveloperToolsSupport.ColorResource(name: "focallyOnError", bundle: resourceBundle)

    /// The "focallyOnErrorContainer" asset catalog color resource.
    static let focallyOnErrorContainer = DeveloperToolsSupport.ColorResource(name: "focallyOnErrorContainer", bundle: resourceBundle)

    /// The "focallyOnPrimary" asset catalog color resource.
    static let focallyOnPrimary = DeveloperToolsSupport.ColorResource(name: "focallyOnPrimary", bundle: resourceBundle)

    /// The "focallyOnPrimaryContainer" asset catalog color resource.
    static let focallyOnPrimaryContainer = DeveloperToolsSupport.ColorResource(name: "focallyOnPrimaryContainer", bundle: resourceBundle)

    /// The "focallyOnPrimaryFixed" asset catalog color resource.
    static let focallyOnPrimaryFixed = DeveloperToolsSupport.ColorResource(name: "focallyOnPrimaryFixed", bundle: resourceBundle)

    /// The "focallyOnPrimaryFixedVariant" asset catalog color resource.
    static let focallyOnPrimaryFixedVariant = DeveloperToolsSupport.ColorResource(name: "focallyOnPrimaryFixedVariant", bundle: resourceBundle)

    /// The "focallyOnSecondary" asset catalog color resource.
    static let focallyOnSecondary = DeveloperToolsSupport.ColorResource(name: "focallyOnSecondary", bundle: resourceBundle)

    /// The "focallyOnSecondaryContainer" asset catalog color resource.
    static let focallyOnSecondaryContainer = DeveloperToolsSupport.ColorResource(name: "focallyOnSecondaryContainer", bundle: resourceBundle)

    /// The "focallyOnSecondaryFixed" asset catalog color resource.
    static let focallyOnSecondaryFixed = DeveloperToolsSupport.ColorResource(name: "focallyOnSecondaryFixed", bundle: resourceBundle)

    /// The "focallyOnSecondaryFixedVariant" asset catalog color resource.
    static let focallyOnSecondaryFixedVariant = DeveloperToolsSupport.ColorResource(name: "focallyOnSecondaryFixedVariant", bundle: resourceBundle)

    /// The "focallyOnSurface" asset catalog color resource.
    static let focallyOnSurface = DeveloperToolsSupport.ColorResource(name: "focallyOnSurface", bundle: resourceBundle)

    /// The "focallyOnSurfaceVariant" asset catalog color resource.
    static let focallyOnSurfaceVariant = DeveloperToolsSupport.ColorResource(name: "focallyOnSurfaceVariant", bundle: resourceBundle)

    /// The "focallyOnTertiary" asset catalog color resource.
    static let focallyOnTertiary = DeveloperToolsSupport.ColorResource(name: "focallyOnTertiary", bundle: resourceBundle)

    /// The "focallyOnTertiaryContainer" asset catalog color resource.
    static let focallyOnTertiaryContainer = DeveloperToolsSupport.ColorResource(name: "focallyOnTertiaryContainer", bundle: resourceBundle)

    /// The "focallyOutline" asset catalog color resource.
    static let focallyOutline = DeveloperToolsSupport.ColorResource(name: "focallyOutline", bundle: resourceBundle)

    /// The "focallyOutlineVariant" asset catalog color resource.
    static let focallyOutlineVariant = DeveloperToolsSupport.ColorResource(name: "focallyOutlineVariant", bundle: resourceBundle)

    /// The "focallyPrimary" asset catalog color resource.
    static let focallyPrimary = DeveloperToolsSupport.ColorResource(name: "focallyPrimary", bundle: resourceBundle)

    /// The "focallyPrimaryContainer" asset catalog color resource.
    static let focallyPrimaryContainer = DeveloperToolsSupport.ColorResource(name: "focallyPrimaryContainer", bundle: resourceBundle)

    /// The "focallyPrimaryFixed" asset catalog color resource.
    static let focallyPrimaryFixed = DeveloperToolsSupport.ColorResource(name: "focallyPrimaryFixed", bundle: resourceBundle)

    /// The "focallyPrimaryFixedDim" asset catalog color resource.
    static let focallyPrimaryFixedDim = DeveloperToolsSupport.ColorResource(name: "focallyPrimaryFixedDim", bundle: resourceBundle)

    /// The "focallySecondary" asset catalog color resource.
    static let focallySecondary = DeveloperToolsSupport.ColorResource(name: "focallySecondary", bundle: resourceBundle)

    /// The "focallySecondaryContainer" asset catalog color resource.
    static let focallySecondaryContainer = DeveloperToolsSupport.ColorResource(name: "focallySecondaryContainer", bundle: resourceBundle)

    /// The "focallySecondaryFixed" asset catalog color resource.
    static let focallySecondaryFixed = DeveloperToolsSupport.ColorResource(name: "focallySecondaryFixed", bundle: resourceBundle)

    /// The "focallySecondaryFixedDim" asset catalog color resource.
    static let focallySecondaryFixedDim = DeveloperToolsSupport.ColorResource(name: "focallySecondaryFixedDim", bundle: resourceBundle)

    /// The "focallySurface" asset catalog color resource.
    static let focallySurface = DeveloperToolsSupport.ColorResource(name: "focallySurface", bundle: resourceBundle)

    /// The "focallySurfaceBright" asset catalog color resource.
    static let focallySurfaceBright = DeveloperToolsSupport.ColorResource(name: "focallySurfaceBright", bundle: resourceBundle)

    /// The "focallySurfaceContainer" asset catalog color resource.
    static let focallySurfaceContainer = DeveloperToolsSupport.ColorResource(name: "focallySurfaceContainer", bundle: resourceBundle)

    /// The "focallySurfaceContainerHigh" asset catalog color resource.
    static let focallySurfaceContainerHigh = DeveloperToolsSupport.ColorResource(name: "focallySurfaceContainerHigh", bundle: resourceBundle)

    /// The "focallySurfaceContainerHighest" asset catalog color resource.
    static let focallySurfaceContainerHighest = DeveloperToolsSupport.ColorResource(name: "focallySurfaceContainerHighest", bundle: resourceBundle)

    /// The "focallySurfaceContainerLow" asset catalog color resource.
    static let focallySurfaceContainerLow = DeveloperToolsSupport.ColorResource(name: "focallySurfaceContainerLow", bundle: resourceBundle)

    /// The "focallySurfaceContainerLowest" asset catalog color resource.
    static let focallySurfaceContainerLowest = DeveloperToolsSupport.ColorResource(name: "focallySurfaceContainerLowest", bundle: resourceBundle)

    /// The "focallySurfaceDim" asset catalog color resource.
    static let focallySurfaceDim = DeveloperToolsSupport.ColorResource(name: "focallySurfaceDim", bundle: resourceBundle)

    /// The "focallySurfaceTint" asset catalog color resource.
    static let focallySurfaceTint = DeveloperToolsSupport.ColorResource(name: "focallySurfaceTint", bundle: resourceBundle)

    /// The "focallySurfaceVariant" asset catalog color resource.
    static let focallySurfaceVariant = DeveloperToolsSupport.ColorResource(name: "focallySurfaceVariant", bundle: resourceBundle)

    /// The "focallyTertiary" asset catalog color resource.
    static let focallyTertiary = DeveloperToolsSupport.ColorResource(name: "focallyTertiary", bundle: resourceBundle)

    /// The "focallyTertiaryContainer" asset catalog color resource.
    static let focallyTertiaryContainer = DeveloperToolsSupport.ColorResource(name: "focallyTertiaryContainer", bundle: resourceBundle)

    /// The "focallyTertiaryFixed" asset catalog color resource.
    static let focallyTertiaryFixed = DeveloperToolsSupport.ColorResource(name: "focallyTertiaryFixed", bundle: resourceBundle)

    /// The "focallyTertiaryFixedDim" asset catalog color resource.
    static let focallyTertiaryFixedDim = DeveloperToolsSupport.ColorResource(name: "focallyTertiaryFixedDim", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

