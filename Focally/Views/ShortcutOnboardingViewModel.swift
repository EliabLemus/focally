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
            return "Apple Shortcuts Integration"
        case .installation:
            return "Install Test Shortcuts"
        case .verification:
            return "Verify Shortcuts"
        case .completion:
            return "Setup Complete"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's set up Apple Shortcuts to enhance your focus sessions."
        case .explanation:
            return "Shortcuts let Focally control Focus modes for a more immersive experience."
        case .installation:
            return "We'll install test shortcuts that you can customize later."
        case .verification:
            return "Let's verify the shortcuts are working correctly."
        case .completion:
            return "Your shortcuts are ready to go!"
        }
    }
}

// MARK: - Onboarding ViewModel

@MainActor
class ShortcutOnboardingViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "ShortcutOnboardingViewModel")
    private let testShortcutGenerator: TestShortcutGenerator
    private let focusIntegrationService: FocusIntegrationService

    // Published state
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isGeneratingShortcuts: Bool = false
    @Published var generationError: String?
    @Published var isVerifying: Bool = false
    @Published var verificationResults: [String: Bool] = [:]
    @Published var allShortcutsVerified: Bool = false

    // Completion callback
    var onComplete: (() -> Void)?

    init(testShortcutGenerator: TestShortcutGenerator, focusIntegrationService: FocusIntegrationService) {
        self.testShortcutGenerator = testShortcutGenerator
        self.focusIntegrationService = focusIntegrationService
    }

    // MARK: - Navigation

    func nextStep() {
        guard currentStep.rawValue < OnboardingStep.allCases.count - 1 else {
            completeOnboarding()
            return
        }

        switch currentStep {
        case .installation:
            // Auto-trigger generation when moving to installation step
            generateShortcuts()
        case .verification:
            // Auto-verify when moving to verification step
            verifyShortcuts()
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

    // MARK: - Shortcuts Generation

    func generateShortcuts() {
        isGeneratingShortcuts = true
        generationError = nil

        Task { @MainActor in
            do {
                try testShortcutGenerator.generateAllTestShortcuts()
                logger.info("✅ Shortcuts generated successfully")
                isGeneratingShortcuts = false
            } catch {
                logger.error("Failed to generate shortcuts: \(error.localizedDescription, privacy: .public)")
                generationError = error.localizedDescription
                isGeneratingShortcuts = false
            }
        }
    }

    // MARK: - Shortcuts Verification

    func verifyShortcuts() {
        isVerifying = true
        verificationResults = [:]
        allShortcutsVerified = false

        Task { @MainActor in
            // Verify each shortcut
            let startShortcutVerified = await testShortcutGenerator.verifyShortcut(named: "Focally Start Focus")
            let endShortcutVerified = await testShortcutGenerator.verifyShortcut(named: "Focally End Focus")

            verificationResults["Focally Start Focus"] = startShortcutVerified
            verificationResults["Focally End Focus"] = endShortcutVerified

            allShortcutsVerified = startShortcutVerified && endShortcutVerified
            isVerifying = false

            logger.info("Verification results: Start: \(startShortcutVerified), End: \(endShortcutVerified)")
        }
    }

    func retryVerification() {
        verifyShortcuts()
    }

    // MARK: - Completion

    func completeOnboarding() {
        logger.info("Onboarding completed")
        setOnboardingCompleted()
        onComplete?()
    }

    // MARK: - UserDefaults Management

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
