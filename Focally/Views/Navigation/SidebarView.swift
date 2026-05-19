import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: FocallyTab

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focally")
                    .font(.focallyH1)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("Deep Work")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FocallySpacing.md)
            .padding(.top, FocallySpacing.lg)
            .padding(.bottom, FocallySpacing.lg)

            Divider()
                .padding(.horizontal, FocallySpacing.sm)

            VStack(spacing: 2) {
                ForEach(FocallyTab.visibleTabs) { tab in
                    SidebarItemView(
                        icon: tab.activeIcon,
                        label: tab.rawValue,
                        isActive: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, FocallySpacing.sm)
            .padding(.top, FocallySpacing.sm)

            Spacer()
        }
        .frame(width: 260)
        .background(Color.focallySurfaceContainerLow.opacity(0.8).ignoresSafeArea())
        .overlay(
            Rectangle()
                .frame(width: 0.5)
                .foregroundStyle(Color.focallyOutline),
            alignment: .trailing
        )
    }
}
