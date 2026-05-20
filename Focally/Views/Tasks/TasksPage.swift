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
                .padding(.horizontal, FocallySpacing.large)
                .padding(.top, FocallySpacing.large)

                Text("Manage free-form focus sessions, Pomodoro defaults, and saved activities.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOutline)
                    .padding(.horizontal, FocallySpacing.large)
                    .padding(.bottom, FocallySpacing.large)

                ScrollView {
                    VStack(spacing: FocallySpacing.large) {
                        HStack(alignment: .top, spacing: FocallySpacing.large) {
                            VStack(spacing: FocallySpacing.large) {
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
                    .padding(.horizontal, FocallySpacing.large)
                    .padding(.bottom, FocallySpacing.large)
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
        .padding(.horizontal, FocallySpacing.medium)
        .padding(.vertical, FocallySpacing.small)
    }
}
