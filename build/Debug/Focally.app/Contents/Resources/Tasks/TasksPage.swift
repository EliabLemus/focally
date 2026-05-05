import SwiftUI

struct TasksPage: View {
    var body: some View {
        VStack(spacing: 0) {
            TopBarView {
                Text("Task Configuration")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)
            }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Task Configuration")
                        .font(.focallyDisplay)
                        .foregroundStyle(Color.focallyOnSurface)

                    Spacer()
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.top, FocallySpacing.lg)

                Text("Manage your focus sessions and predefined activities.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOutline)
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.bottom, FocallySpacing.lg)

                ScrollView {
                    VStack(spacing: FocallySpacing.lg) {
                        HStack(alignment: .top, spacing: FocallySpacing.lg) {
                            VStack(spacing: FocallySpacing.lg) {
                                TimerSettingsCard()
                                FocusModeCard()
                            }
                            .frame(maxWidth: .infinity)

                            PredefinedTasksList()
                                .frame(maxWidth: .infinity)
                        }

                        SmartTemplatesCard()

                        TasksFooter()
                    }
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.bottom, FocallySpacing.lg)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.focallyBackground)
        }
    }
}

private struct TasksFooter: View {
    var body: some View {
        HStack {
            Text("Changes are saved automatically and applied to future focus sessions.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Spacer()
        }
        .padding(.horizontal, FocallySpacing.md)
        .padding(.vertical, FocallySpacing.sm)
    }
}
