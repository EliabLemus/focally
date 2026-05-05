import SwiftUI

struct DesignSystemTestView: View {
    @State private var isDarkMode = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Design System Test")
                .font(.focallyDisplay)
                .foregroundColor(.focallyOnSurface)

            Toggle("Dark Mode", isOn: $isDarkMode)

            HStack(spacing: 16) {
                Circle()
                    .fill(Color.focallyPrimary)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("P")
                            .foregroundColor(.focallyOnPrimary)
                    )
                Circle()
                    .fill(Color.focallySurfaceContainer)
                    .frame(width: 50, height: 50)
            }

            Button("Test Card") {
                // Test the card modifier
            }
            .focallyCard()
            .padding()
            .frame(maxWidth: .infinity)

            Divider()

            HStack(spacing: 8) {
                Text("Regular: Inter 13px")
                    .font(.focallyBody)
                    .foregroundColor(.focallyOnSurface)
                Text("Bold: Inter 13px")
                    .font(.focallyBodyBold)
                    .foregroundColor(.focallyPrimary)
                Text("Display: Inter 28px")
                    .font(.focallyDisplay)
                    .foregroundColor(.focallyOnSurface)
            }
        }
        .padding()
    }
}
