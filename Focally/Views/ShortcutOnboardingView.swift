import SwiftUI

// MARK: - Shortcut Onboarding View

struct ShortcutOnboardingView: View {
    @StateObject private var viewModel: ShortcutOnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    init(testShortcutGenerator: TestShortcutGenerator, focusIntegrationService: FocusIntegrationService) {
        _viewModel = StateObject(wrappedValue: ShortcutOnboardingViewModel(
            testShortcutGenerator: testShortcutGenerator,
            focusIntegrationService: focusIntegrationService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            ScrollView {
                VStack(spacing: FocallySpacing.lg) {
                    // Step indicator
                    stepIndicator

                    // Step content
                    stepContent

                    Spacer(minLength: FocallySpacing.xl)
                }
                .padding(FocallySpacing.xl)
            }

            // Footer with navigation
            footerView
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color.focallyBackground)
        .onAppear {
            viewModel.onComplete = {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentStep.title)
                    .font(.focallyH1)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(viewModel.currentStep.description)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOutline)
            }

            Spacer()

            // Skip button (small)
            Button(action: viewModel.skipOnboarding) {
                Text("Skip")
                    .font(.focallyButton)
                    .foregroundStyle(Color.focallyOutline)
                    .padding(.horizontal, FocallySpacing.md)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.lg)
        .background(Color.focallySurfaceContainerLowest)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases) { step in
                Circle()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.focallyPrimary : Color.focallySurfaceContainerHigh)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.focallyPrimary, lineWidth: step.rawValue <= viewModel.currentStep.rawValue ? 0 : 1)
                    )
            }
        }
        .padding(FocallySpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.md)
                .fill(Color.focallySurfaceContainerLow)
        )
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeStep
        case .explanation:
            explanationStep
        case .installation:
            installationStep
        case .verification:
            verificationStep
        case .completion:
            completionStep
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            // Hero icon
            ZStack {
                RoundedRectangle(cornerRadius: FocallyRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color.focallyPrimary.opacity(0.2), Color.focallyTertiary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)

                VStack(spacing: FocallySpacing.md) {
                    Image(systemName: "moon.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.focallyPrimary)

                    Text("Enhance Your Focus")
                        .font(.focallyH1)
                        .foregroundStyle(Color.focallyOnSurface)
                }
            }
            .padding(FocallySpacing.xl)

            // Benefits
            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                benefitItem(
                    icon: "moon.zzz.fill",
                    title: "Automatic Focus Mode",
                    description: "Activate a macOS Focus mode when your timer starts"
                )

                benefitItem(
                    icon: "bell.slash.fill",
                    title: "Distraction-Free",
                    description: "Silence notifications and minimize interruptions"
                )

                benefitItem(
                    icon: "command.fill",
                    title: "Full Control",
                    description: "Customize shortcuts to fit your exact workflow"
                )
            }
        }
    }

    // MARK: - Explanation Step

    private var explanationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            // Illustration
            ZStack {
                RoundedRectangle(cornerRadius: FocallyRadius.lg)
                    .fill(Color.focallyPrimary.opacity(0.1))
                    .frame(height: 180)

                VStack(spacing: FocallySpacing.md) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.focallyPrimary)

                    Text("How It Works")
                        .font(.focallyH2)
                        .foregroundStyle(Color.focallyOnSurface)

                    VStack(spacing: FocallySpacing.sm) {
                        Label {
                            Text("Focally triggers a shortcut when you start a focus session")
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        } icon: {
                            Circle()
                                .fill(Color.focallyPrimary)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Text("1")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.focallyOnPrimary)
                                }
                        }

                        Label {
                            Text("The shortcut activates your chosen Focus mode")
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        } icon: {
                            Circle()
                                .fill(Color.focallyPrimary)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Text("2")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.focallyOnPrimary)
                                }
                        }

                        Label {
                            Text("When you finish, another shortcut turns it off")
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        } icon: {
                            Circle()
                                .fill(Color.focallyPrimary)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Text("3")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.focallyOnPrimary)
                                }
                        }
                    }
                }
                .padding(FocallySpacing.lg)
            }

            // Info box
            HStack(spacing: FocallySpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.focallyPrimary)

                Text("You'll install test shortcuts that can be customized later in the Shortcuts app.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .padding(FocallySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(Color.focallyPrimaryContainer.opacity(0.3))
            )
        }
    }

    // MARK: - Installation Step

    private var installationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            if viewModel.isGeneratingShortcuts {
                // Loading state
                VStack(spacing: FocallySpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.focallyPrimary)

                    Text("Generating shortcuts...")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("This should only take a few seconds.")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                }
                .frame(height: 200)
            } else if let error = viewModel.generationError {
                // Error state
                VStack(spacing: FocallySpacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.md)
                            .fill(Color.focallyErrorContainer.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.focallyError)
                    }

                    VStack(spacing: FocallySpacing.sm) {
                        Text("Failed to Generate Shortcuts")
                            .font(.focallyH2)
                            .foregroundStyle(Color.focallyError)

                        Text(error)
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: viewModel.generateShortcuts) {
                        Text("Try Again")
                            .font(.focallyButton)
                            .foregroundStyle(Color.focallyOnPrimary)
                            .padding(.horizontal, FocallySpacing.lg)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                    .fill(Color.focallyPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Success state
                VStack(spacing: FocallySpacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.md)
                            .fill(Color.focallyPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.focallyPrimary)
                    }

                    VStack(spacing: FocallySpacing.sm) {
                        Text("Shortcuts Generated Successfully!")
                            .font(.focallyH2)
                            .foregroundStyle(Color.focallyPrimary)

                        Text("Two test shortcuts have been created and are ready to use.")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }

                    // Shortcut files list
                    VStack(alignment: .leading, spacing: FocallySpacing.sm) {
                        shortcutFileRow(name: "Focally Start Focus.shortcut", icon: "play.fill")
                        shortcutFileRow(name: "Focally End Focus.shortcut", icon: "stop.fill")
                    }
                    .padding(FocallySpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: FocallyRadius.md)
                            .fill(Color.focallySurfaceContainerLow)
                    )
                }
            }
        }
    }

    // MARK: - Verification Step

    private var verificationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            if viewModel.isVerifying {
                // Verifying state
                VStack(spacing: FocallySpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.focallyPrimary)

                    Text("Verifying shortcuts...")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                }
                .frame(height: 200)
            } else {
                // Results
                VStack(spacing: FocallySpacing.lg) {
                    // Status header
                    HStack(spacing: FocallySpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: FocallyRadius.md)
                                .fill(viewModel.allShortcutsVerified ? Color.focallyPrimary.opacity(0.1) : Color.focallyError.opacity(0.1))
                                .frame(width: 50, height: 50)

                            Image(systemName: viewModel.allShortcutsVerified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(viewModel.allShortcutsVerified ? Color.focallyPrimary : Color.focallyError)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.allShortcutsVerified ? "All Shortcuts Verified" : "Verification Issues")
                                .font(.focallyH2)
                                .foregroundStyle(viewModel.allShortcutsVerified ? Color.focallyPrimary : Color.focallyTertiary)

                            Text(viewModel.allShortcutsVerified ? "Your shortcuts are working correctly." : "Some shortcuts may not be installed.")
                                .font(.focallyBody)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }

                        Spacer()
                    }

                    // Verification results
                    VStack(alignment: .leading, spacing: FocallySpacing.sm) {
                        verificationResultRow(name: "Focally Start Focus", verified: viewModel.verificationResults["Focally Start Focus"] ?? false)
                        verificationResultRow(name: "Focally End Focus", verified: viewModel.verificationResults["Focally End Focus"] ?? false)
                    }
                    .padding(FocallySpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: FocallyRadius.md)
                            .fill(Color.focallySurfaceContainerLow)
                    )

                    // Helper text
                    if !viewModel.allShortcutsVerified {
                        HStack(spacing: FocallySpacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.focallyPrimary)

                            Text("You can retry verification or continue anyway. The shortcuts may still work.")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Completion Step

    private var completionStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            // Success celebration
            ZStack {
                RoundedRectangle(cornerRadius: FocallyRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color.focallyPrimary.opacity(0.2), Color.focallyTertiary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)

                VStack(spacing: FocallySpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.focallyPrimary)

                    Text("You're All Set!")
                        .font(.focallyH1)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("Your shortcuts are installed and ready to use.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
            }

            // Next steps
            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                Text("What's Next?")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                nextStepItem(
                    step: "1",
                    title: "Enable Focus Integration",
                    description: "Go to Settings > Integrations and turn on Focus Integration"
                )

                nextStepItem(
                    step: "2",
                    title: "Choose Your Mode",
                    description: "Select 'Shortcuts' mode to use your new shortcuts"
                )

                nextStepItem(
                    step: "3",
                    title: "Start a Focus Session",
                    description: "Test it out by starting your first session!"
                )

                nextStepItem(
                    step: "4",
                    title: "Customize Shortcuts (Optional)",
                    description: "Edit the shortcuts in the Shortcuts app to add custom actions"
                )
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: FocallySpacing.md) {
            // Previous button
            if viewModel.currentStep.rawValue > 0 {
                Button(action: viewModel.previousStep) {
                    Text("Back")
                        .font(.focallyButton)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .padding(.horizontal, FocallySpacing.lg)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                .fill(Color.focallySurfaceContainerHigh)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Next button
            let isLastStep = viewModel.currentStep.rawValue == OnboardingStep.allCases.count - 1

            Button(action: viewModel.nextStep) {
                Text(isLastStep ? "Finish" : "Continue")
                    .font(.focallyButton)
                    .foregroundStyle(Color.focallyOnPrimary)
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                            .fill(Color.focallyPrimary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isGeneratingShortcuts || viewModel.isVerifying)
        }
        .padding(FocallySpacing.lg)
        .background(Color.focallySurfaceContainerLowest)
    }

    // MARK: - Helper Views

    private func benefitItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: FocallySpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                    .fill(Color.focallyPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.focallyPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(description)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
        }
    }

    private func shortcutFileRow(name: String, icon: String) -> some View {
        HStack(spacing: FocallySpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.focallyPrimary)
                .frame(width: 20)

            Text(name)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.focallyPrimary)
        }
    }

    private func verificationResultRow(name: String, verified: Bool) -> some View {
        HStack(spacing: FocallySpacing.sm) {
            Circle()
                .fill(verified ? Color.focallyPrimary : Color.focallyOutline)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Spacer()

            if verified {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyPrimary)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyError)
            }
        }
    }

    private func nextStepItem(step: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: FocallySpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.focallyPrimary)
                    .frame(width: 24, height: 24)

                Text(step)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.focallyOnPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(description)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ShortcutOnboardingView(
        testShortcutGenerator: TestShortcutGenerator(),
        focusIntegrationService: FocusIntegrationService()
    )
}
