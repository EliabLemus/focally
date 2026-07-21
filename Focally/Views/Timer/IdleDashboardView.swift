import SwiftUI

struct IdleDashboardView: View {
    @Environment(FocusModeStore.self) private var focusModeStore
    @Environment(FocusTimerService.self) private var timerService
    @Environment(SlackService.self) private var slackService

    @State private var editingMode: FocusMode?
    @State private var isAddingMode = false

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

                    addModeButton
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
            FocusModeEditSheet(mode: mode, onSave: { updatedMode in
                focusModeStore.update(updatedMode)
            }, onDelete: {
                focusModeStore.delete(mode)
                editingMode = nil
            })
            .environment(slackService)
        }
        .sheet(isPresented: $isAddingMode) {
            FocusModeEditSheet(mode: FocusMode(id: UUID(), name: "", emoji: ":rocket:", statusText: "", durationMinutes: 25, enableDND: true, enablePomodoro: false, pomodoroWorkMinutes: 25, pomodoroBreakMinutes: 5, pomodoroRounds: 1), onSave: { newMode in
                focusModeStore.add(newMode)
            })
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

    private var addModeButton: some View {
        Button(action: { isAddingMode = true }) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.focallyPrimary.opacity(0.7))

                Text("Add Mode")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyPrimary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Color.focallyOutline.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}
