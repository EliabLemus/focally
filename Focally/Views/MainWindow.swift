import SwiftUI

struct MainWindow: View {
    @AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system
    @State private var selectedTab: FocallyTab = .timer

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab)

            VStack(spacing: 0) {
                TopBarView {
                    Text(selectedTab.rawValue)
                        .font(.focallyH2)
                        .foregroundStyle(Color.focallyOnSurface)
                } rightContent: {
                    if selectedTab != .settings {
                        Button(action: openSettingsTab) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.focallySurfaceContainer)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Settings")
                    }
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.focallyBackground)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNavigateToSettings)) { _ in
            selectedTab = .settings
        }
        .preferredColorScheme(selectedTheme.preferredColorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .timer:
            TimerPage()
        case .tasks:
            TasksPage()
        case .settings:
            SettingsPage()
        case .schedule, .analytics:
            TimerPage()
        }
    }

    private func openSettingsTab() {
        selectedTab = .settings
    }
}
