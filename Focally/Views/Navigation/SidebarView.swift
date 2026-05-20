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
            .padding(.horizontal, FocallySpacing.medium)
            .padding(.top, FocallySpacing.large)
            .padding(.bottom, FocallySpacing.large)

            Divider()
                .padding(.horizontal, FocallySpacing.small)

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
            .padding(.horizontal, FocallySpacing.small)
            .padding(.top, FocallySpacing.small)

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
