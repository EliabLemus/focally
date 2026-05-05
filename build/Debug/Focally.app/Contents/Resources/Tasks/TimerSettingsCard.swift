import SwiftUI

struct TimerSettingsCard: View {
    @EnvironmentObject private var timerService: FocusTimerService
    @State private var focusDuration = "25"
    @State private var shortBreak = "5"
    @State private var longBreak = "15"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.focallyPrimary)
                Text("Timer Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)
            }

            // Timer duration inputs
            VStack(spacing: 12) {
                TimerInputRow(
                    label: "Focus Duration",
                    value: $focusDuration,
                    unit: "min",
                    defaultValue: 25,
                    onValueChange: timerService.updateWorkDuration(minutes:)
                )
                Divider()
                TimerInputRow(
                    label: "Short Break",
                    value: $shortBreak,
                    unit: "min",
                    defaultValue: 5,
                    onValueChange: timerService.updateShortBreakDuration(minutes:)
                )
                Divider()
                TimerInputRow(
                    label: "Long Break",
                    value: $longBreak,
                    unit: "min",
                    defaultValue: 15,
                    onValueChange: timerService.updateLongBreakDuration(minutes:)
                )
            }

            Spacer()

            // Auto-start breaks toggle
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallySecondary)
                Text("Auto-start Breaks")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Toggle("", isOn: autoStartBreaksBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .padding(16)
        .focallyCard()
        .onAppear(perform: syncFromService)
    }

    private var autoStartBreaksBinding: Binding<Bool> {
        Binding(
            get: { timerService.isAutoStartEnabled },
            set: { timerService.updateAutoStartEnabled($0) }
        )
    }

    private func syncFromService() {
        focusDuration = String(timerService.workDurationMinutes)
        shortBreak = String(timerService.shortBreakDurationMinutes)
        longBreak = String(timerService.longBreakDurationMinutes)
    }
}

struct TimerInputRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    let defaultValue: Int
    let onValueChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)
                Spacer()
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.focallyOutline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.focallySurfaceContainerLowest.opacity(0.5))
                    .cornerRadius(6)
            }

            TextField("0", text: $value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.focallyOnSurface)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.focallySurfaceContainerLowest.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.focallyOutline.opacity(0.2))
                )
                .multilineTextAlignment(.trailing)
                .onChange(of: value) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        value = filtered
                        return
                    }

                    guard let minutes = Int(filtered), (1...600).contains(minutes) else {
                        return
                    }

                    onValueChange(minutes)
                }
                .onSubmit {
                    commitValue()
                }
                .onDisappear {
                    commitValue()
                }
        }
    }

    private func commitValue() {
        let parsedValue = Int(value.filter(\.isNumber)) ?? defaultValue
        let clampedValue = min(max(parsedValue, 1), 600)
        value = String(clampedValue)
        onValueChange(clampedValue)
    }
}

struct FocusModeCard: View {
    var body: some View {
        VStack(spacing: 0) {
            // Gradient background
            LinearGradient(
                colors: [Color.focallyPrimary.opacity(0.8), Color.focallyPrimaryContainer.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 128)
            .cornerRadius(12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Flow Mode")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Optimized for knowledge work.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .focallyCard()
    }
}
