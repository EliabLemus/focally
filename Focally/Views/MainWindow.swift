import SwiftUI

struct MainWindow: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var selectedTab: FocallyTab = .timer

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedTab: $selectedTab)

            VStack(spacing: 0) {
                TopBarView {
                    Text(selectedTab.localizedLabel)
                        .font(.focallyH2)
                        .foregroundStyle(Color.focallyOnSurface)
                } rightContent: {
                    if selectedTab != .settings && selectedTab != .metrics {
                        Button(action: openSettingsTab) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.focallySurfaceContainer))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("main_open_settings")
                    }
                }

                Group {
                    switch selectedTab {
                    case .timer:
                        TimerPage()
                    case .metrics:
                        MetricsPage()
                    case .settings:
                        SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.focallyBackground)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNavigateToSettings)) { _ in
            selectedTab = .settings
        }
        .preferredColorScheme(settingsStore.appTheme.preferredColorScheme)
    }

    private func openSettingsTab() {
        selectedTab = .settings
    }
}
