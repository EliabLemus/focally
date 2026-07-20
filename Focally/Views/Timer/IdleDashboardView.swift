import SwiftUI

struct IdleDashboardView: View {
    @Environment(FocusModeStore.self) private var focusModeStore
    @Environment(FocusTimerService.self) private var timerService
    @Environment(SlackService.self) private var slackService

    @State private var editingMode: FocusMode?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FocallySpacing.large) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: FocallySpacing.medium)], spacing: FocallySpacing.medium) {
                    ForEach(focusModeStore.modes) { mode in
                        FocusModeCard(
                            mode: mode,
                            onStart: { start(mode) },
                            onEdit: { editingMode = mode }
                        )
                    }
                }

                footerCard
            }
            .padding(FocallySpacing.large)
        }
        .background(Color.focallyBackground)
        .onAppear {
            slackService.refreshEmojiCatalogIfPossible()
        }
        .sheet(item: $editingMode) { mode in
            FocusModeEditSheet(mode: mode) { updatedMode in
                focusModeStore.update(updatedMode)
            }
            .environment(slackService)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOCUS MODES")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyPrimary)

            Text("Start in one click.")
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Each mode keeps its own Slack emoji, status text, duration, and optional DND automation.")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Tap any card to start immediately. Edit when you need to change the Slack shortcode, status text, duration, or Pomodoro cadence for Focus Time.")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func start(_ mode: FocusMode) {
        timerService.startSession(mode: mode)
    }
}
