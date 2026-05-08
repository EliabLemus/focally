import SwiftUI

// MARK: - Shortcut Onboarding View

struct ShortcutOnboardingView: View {
    @StateObject private var viewModel: ShortcutOnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    init(managedShortcutsService: ManagedFocusShortcutsService, focusIntegrationService: FocusIntegrationService) {
        _viewModel = StateObject(wrappedValue: ShortcutOnboardingViewModel(
            managedShortcutsService: managedShortcutsService,
            focusIntegrationService: focusIntegrationService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(spacing: FocallySpacing.lg) {
                    stepIndicator
                    stepContent
                    Spacer(minLength: FocallySpacing.xl)
                }
                .padding(FocallySpacing.xl)
            }

            footerView
        }
        .frame(minWidth: 520, minHeight: 640)
        .background(Color.focallyBackground)
        .onAppear {
            viewModel.onComplete = {
                dismiss()
            }
        }
    }

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

    private var welcomeStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            heroCard(
                icon: "moon.circle.fill",
                title: "Quiet Mode On by Default",
                subtitle: "Install Focally, enable Focus Integration, and it can toggle macOS Do Not Disturb right away — no extra setup for the main path."
            )

            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                benefitItem(
                    icon: "moon.zzz.fill",
                    title: "Direct System DND",
                    description: "This is the recommended default: start a focus session and Focally turns system DND on right away."
                )

                benefitItem(
                    icon: "checkmark.circle",
                    title: "No Extra Setup For The Main Path",
                    description: "You do not need to build or edit shortcuts manually just to use Focally."
                )

                benefitItem(
                    icon: "square.and.arrow.down",
                    title: "Optional shortcut files",
                    description: "If Apple needs the visual Add step, Focally can stage its bundled signed Focus On/Off shortcuts and open them for you."
                )
            }
        }
    }

    private var explanationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            heroCard(
                icon: "bolt.badge.clock",
                title: "Quiet mode, handled automatically",
                subtitle: "Focally turns on Do Not Disturb directly. The bundled shortcut files are only there if Apple needs the visual Add step."
            )

            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                infoRow(number: "1", text: "Focally uses direct Do Not Disturb first as soon as Focus Integration is enabled.")
                infoRow(number: "2", text: "If Apple needs the visual Add step, Focally stages the bundled signed shortcut files and opens them for you.")
                infoRow(number: "3", text: "After that one visual confirmation, Focally can use the shortcut backup automatically without manual editing.")
            }
            .padding(FocallySpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(Color.focallySurfaceContainerLow)
            )
        }
    }

    private var installationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            heroCard(
                icon: "square.and.arrow.down.on.square",
                title: "Shortcut files for Apple’s Add step",
                subtitle: viewModel.managedShortcutsService.setupSummary
            )

            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                statusRow(
                    title: "Signed files ready",
                    isComplete: viewModel.managedShortcutsService.allSignedShortcutsExist,
                    detail: "Focally copies the bundled signed Focus On/Off .shortcut files into Application Support so they’re easy to open."
                )

                statusRow(
                    title: "Visual Add step done",
                    isComplete: viewModel.managedShortcutsService.allManagedShortcutsInstalled,
                    detail: "After Apple shows the Add dialog once for each shortcut and you press Add, Focally can run the backup automatically."
                )
            }
            .padding(FocallySpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(Color.focallySurfaceContainerLow)
            )

            HStack(spacing: FocallySpacing.sm) {
                Button(action: viewModel.prepareManagedShortcuts) {
                    primaryButtonLabel("Stage Files", icon: "wand.and.stars")
                }
                .buttonStyle(.plain)

                Button(action: viewModel.prepareAndOpenManagedShortcuts) {
                    secondaryButtonLabel("Stage + Open Add Screens", icon: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
            }

            messageCard(
                text: "The shortcut files stay optional. Focally never silently imports them: it stages the bundled signed files, then Apple shows the Add button once per shortcut.",
                color: Color.focallyPrimary,
                icon: "sparkles"
            )

            HStack(spacing: FocallySpacing.sm) {
                Button(action: viewModel.openManagedShortcuts) {
                    secondaryButtonLabel("Open Files", icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.managedShortcutsService.allSignedShortcutsExist)

                Button(action: viewModel.managedShortcutsService.revealSignedShortcutsInFinder) {
                    secondaryButtonLabel("Reveal In Finder", icon: "folder")
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.managedShortcutsService.allSignedShortcutsExist)
            }

            if let warning = viewModel.managedShortcutsService.lastWarning, !warning.isEmpty {
                messageCard(text: warning, color: Color.focallyPrimary, icon: "info.circle")
            }

            if let error = viewModel.generationError, !error.isEmpty {
                messageCard(text: error, color: Color.focallyError, icon: "exclamationmark.triangle.fill")
            }
        }
    }

    private var verificationStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            heroCard(
                icon: viewModel.allShortcutsVerified ? "checkmark.seal.fill" : "checkmark.shield",
                title: viewModel.allShortcutsVerified ? "Quiet mode verified" : "Verify the setup",
                subtitle: "Direct DND should pass immediately. The shortcut backup only shows ready after the visual Add step happened once per file."
            )

            VStack(alignment: .leading, spacing: FocallySpacing.sm) {
                ForEach(Array(viewModel.verificationResults.keys.sorted()), id: \.self) { key in
                    verificationResultRow(name: key, verified: viewModel.verificationResults[key] ?? false)
                }
            }
            .padding(FocallySpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(Color.focallySurfaceContainerLow)
            )

            Button(action: viewModel.retryVerification) {
                primaryButtonLabel("Run Verification Again", icon: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            if !viewModel.managedShortcutsService.allManagedShortcutsInstalled {
                messageCard(
                    text: "The shortcut backup is still optional. If you skipped the Apple Add dialogs, direct DND remains the supported default and nothing else needs to be created manually.",
                    color: Color.focallyPrimary,
                    icon: "lightbulb.fill"
                )
            }

            if let error = viewModel.generationError, !error.isEmpty {
                messageCard(text: error, color: Color.focallyError, icon: "exclamationmark.triangle.fill")
            }
        }
        .onAppear {
            if viewModel.verificationResults.isEmpty {
                viewModel.verifySetup()
            }
        }
    }

    private var completionStep: some View {
        VStack(spacing: FocallySpacing.lg) {
            heroCard(
                icon: "checkmark.seal.fill",
                title: "You’re all set",
                subtitle: "Use direct Do Not Disturb by default. The shortcut backup only matters later if you want the Apple visual Add step for the bundled files."
            )

            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                nextStepItem(step: "1", title: "Keep direct Do Not Disturb enabled", description: "That remains the fastest, recommended path.")
                nextStepItem(step: "2", title: "Only stage the shortcut backup if you need it", description: "Focally can stage its bundled signed files and open the Apple visual Add screens from Settings > Integrations.")
                nextStepItem(step: "3", title: "Press Add once, then verify", description: "After each shortcut is added in Shortcuts, use Verify to confirm Focally can run the backup automatically.")
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: FocallySpacing.md) {
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
            .disabled(viewModel.isPreparingIntegration || viewModel.isVerifying || viewModel.managedShortcutsService.isPreparing)
        }
        .padding(FocallySpacing.lg)
        .background(Color.focallySurfaceContainerLowest)
    }

    private func heroCard(icon: String, title: String, subtitle: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: FocallyRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [Color.focallyPrimary.opacity(0.2), Color.focallyTertiary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 190)

            VStack(spacing: FocallySpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 42))
                    .foregroundStyle(Color.focallyPrimary)

                Text(title)
                    .font(.focallyH1)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(subtitle)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FocallySpacing.xl)
            }
        }
    }

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

    private func infoRow(number: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        } icon: {
            Circle()
                .fill(Color.focallyPrimary)
                .frame(width: 20, height: 20)
                .overlay {
                    Text(number)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.focallyOnPrimary)
                }
        }
    }

    private func statusRow(title: String, isComplete: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: FocallySpacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.focallyPrimary : Color.focallyOutline)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(detail)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
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

            Image(systemName: verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(verified ? Color.focallyPrimary : Color.focallyError)
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

    private func messageCard(text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: FocallySpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(text)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Spacer()
        }
        .padding(FocallySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.md)
                .fill(color.opacity(0.08))
        )
    }

    private func primaryButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.focallyButton)
        }
        .foregroundStyle(Color.focallyOnPrimary)
        .padding(.horizontal, FocallySpacing.md)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.sm)
                .fill(Color.focallyPrimary)
        )
    }

    private func secondaryButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.focallyButton)
        }
        .foregroundStyle(Color.focallyOnSurface)
        .padding(.horizontal, FocallySpacing.md)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.sm)
                .fill(Color.focallySurfaceContainerHigh)
        )
    }
}

#Preview {
    ShortcutOnboardingView(
        managedShortcutsService: ManagedFocusShortcutsService.shared,
        focusIntegrationService: FocusIntegrationService.shared
    )
}
