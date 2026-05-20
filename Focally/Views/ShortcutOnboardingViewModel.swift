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
            return "Quiet Mode, Automatically"
        case .installation:
            return "Shortcut Backup"
        case .verification:
            return "Verify Your Setup"
        case .completion:
            return "Setup Complete"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let’s turn on quiet mode the easy way."
        case .explanation:
            return "Focally turns on Do Not Disturb directly by default. The bundled shortcut backup only exists if Apple needs the visual Add step."
        case .installation:
            return "Focally can stage its bundled signed Focus shortcut files for you, then Apple asks for one visual Add confirmation per file."
        case .verification:
            return "We’ll confirm direct quiet mode and optionally check whether the shortcut backup was added after that visual step."
        case .completion:
            return "You’re ready to use direct Do Not Disturb now, with the shortcut backup available whenever you finish Apple’s one-time Add step."
        }
    }
}

// MARK: - Onboarding ViewModel

@MainActor
final class ShortcutOnboardingViewModel: ObservableObject {
    private let logger = Logger.uiLogger
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
        isPreparingIntegration = false
        logger.info("Prepared focus integration")
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

        focusIntegrationService.runNativeShortcutTest(.start)
        let startSucceeded = focusIntegrationService.lastError == nil && focusIntegrationService.isFocusActive

        focusIntegrationService.runNativeShortcutTest(.end)
        let endSucceeded = focusIntegrationService.lastError == nil && !focusIntegrationService.isFocusActive

        managedShortcutsService.refreshInstallationState()
        let managedInstalled = managedShortcutsService.allManagedShortcutsInstalled

        verificationResults["Direct DND On"] = startSucceeded
        verificationResults["Direct DND Off"] = endSucceeded
        verificationResults["Shortcut Backup Added"] = managedInstalled
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
        Logger.uiLogger.info("Onboarding reset - will show on next launch")
    }
}
