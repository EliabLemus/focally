import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: FocallyTab

    var body: some View {
        VStack(spacing: 0) {
            // Logo area
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

            // Navigation items
            VStack(spacing: 2) {
                ForEach(FocallyTab.allCases) { tab in
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

            VStack(alignment: .leading, spacing: FocallySpacing.sm) {
                Text("Daily Streak")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                HStack {
                    Text("12 Days")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.focallyOnSurface)

                    Spacer()

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }
            }
            .padding(FocallySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.lg)
                    .fill(Color.focallySurfaceContainerLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: FocallyRadius.lg)
                            .stroke(Color.focallyCardBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, FocallySpacing.sm)
            .padding(.bottom, FocallySpacing.sm)

            // Profile card
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.focallyPrimaryContainer)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("E")
                            .font(.focallyBodyBold)
                            .foregroundStyle(.white)
                    )

                Text("Eliab")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()
            }
            .padding(FocallySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.lg)
                    .fill(Color.focallySurfaceContainerLow)
                    .overlay(
                        RoundedRectangle(cornerRadius: FocallyRadius.lg)
                            .stroke(Color.focallyCardBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, FocallySpacing.sm)
            .padding(.bottom, FocallySpacing.md)
        }
        .frame(width: 260)
        .background(Color.focallySurfaceContainerLow.opacity(0.8).ignoresSafeArea())
        .overlay(
            Rectangle()
                .frame(width: 0.5)
                .foregroundStyle(Color.focallyCardBorder),
            alignment: .trailing
        )
    }
}
