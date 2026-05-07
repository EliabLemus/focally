import Foundation
import SwiftUI
import os.log

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case explanation = 1
    case installation = 2
    case verification = 3
    case completion = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Focally"
        case .explanation:
            return "Direct DND First"
        case .installation:
            return "Optional Managed Shortcuts"
        case .verification:
            return "Verify Your Setup"
        case .completion:
            return "Setup Complete"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's enable Focally's focus integration the honest way."
        case .explanation:
            return "Direct System DND stays the default install-and-it-just-works path. Managed shortcuts are optional if you want Apple's visible Add flow."
        case .installation:
            return "Focally can stage its bundled signed Focus shortcuts for you, but Apple still asks you to press Add once per shortcut."
        case .verification:
            return "We'll confirm direct DND and optionally check whether the managed shortcuts were imported after that Add step."
        case .completion:
            return "You're ready to use direct DND now, with managed shortcuts available whenever you've finished Apple's one-time Add flow on Focally's bundled signed files."
        }
    }
}

// MARK: - Onboarding ViewModel

@MainActor
final class ShortcutOnboardingViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "ShortcutOnboardingViewModel")
    private let focusIntegrationService: FocusIntegrationService
    let managedShortcutsService: ManagedFocusShortcutsService

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isPreparingIntegration: Bool = false
    @Published var generationError: String?
    @Published var isVerifying: Bool = false
    @Published var verificationResults: [String: Bool] = [:]
    @Published var allShortcutsVerified: Bool = false

    var onComplete: (() -> Void)?

    init(managedShortcutsService: ManagedFocusShortcutsService, focusIntegrationService: FocusIntegrationService) {
        self.managedShortcutsService = managedShortcutsService
        self.focusIntegrationService = focusIntegrationService
    }

    func nextStep() {
        guard currentStep.rawValue < OnboardingStep.allCases.count - 1 else {
            completeOnboarding()
            return
        }

        switch currentStep {
        case .explanation:
            prepareNativeIntegration()
        case .installation:
            verifySetup()
        default:
            break
        }

        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1)!
        }
    }

    func previousStep() {
        guard currentStep.rawValue > 0 else { return }

        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1)!
        }
    }

    func skipOnboarding() {
        logger.info("Onboarding skipped by user")
        completeOnboarding()
    }

    func prepareNativeIntegration() {
        isPreparingIntegration = true
        generationError = nil

        focusIntegrationService.isEnabled = true
        focusIntegrationService.mode = .directDND
        isPreparingIntegration = false
        logger.info("Prepared direct DND mode")
    }

    func prepareManagedShortcuts() {
        generationError = nil
        managedShortcutsService.prepareSignedShortcuts()

        if let error = managedShortcutsService.lastError {
            generationError = error
        }
    }

    func prepareAndOpenManagedShortcuts() {
        generationError = nil
        managedShortcutsService.prepareAndOpenForImport()

        if let error = managedShortcutsService.lastError {
            generationError = error
        }
    }

    func openManagedShortcuts() {
        generationError = nil
        managedShortcutsService.openSignedShortcutsForImport()

        if let error = managedShortcutsService.lastError {
            generationError = error
        }
    }

    func verifySetup() {
        isVerifying = true
        verificationResults = [:]
        allShortcutsVerified = false
        generationError = nil

        focusIntegrationService.mode = .directDND
        focusIntegrationService.runNativeShortcutTest(.start)
        let startSucceeded = focusIntegrationService.lastError == nil && focusIntegrationService.isFocusActive

        focusIntegrationService.runNativeShortcutTest(.end)
        let endSucceeded = focusIntegrationService.lastError == nil && !focusIntegrationService.isFocusActive

        managedShortcutsService.refreshInstallationState()
        let managedInstalled = managedShortcutsService.allManagedShortcutsInstalled

        verificationResults["Direct DND On"] = startSucceeded
        verificationResults["Direct DND Off"] = endSucceeded
        verificationResults["Managed Shortcuts Imported"] = managedInstalled
        allShortcutsVerified = startSucceeded && endSucceeded
        isVerifying = false

        if !allShortcutsVerified {
            generationError = focusIntegrationService.lastError?.localizedDescription
        }

        logger.info("Verification results: direct on=\(startSucceeded), direct off=\(endSucceeded), managed installed=\(managedInstalled)")
    }

    func retryVerification() {
        verifySetup()
    }

    func completeOnboarding() {
        logger.info("Onboarding completed")
        setOnboardingCompleted()
        onComplete?()
    }

    private func setOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "FocallyShortcutOnboardingCompleted")
    }

    static func isOnboardingCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: "FocallyShortcutOnboardingCompleted")
    }

    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "FocallyShortcutOnboardingCompleted")
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "ShortcutOnboardingViewModel")
        logger.info("Onboarding reset - will show on next launch")
    }
}
