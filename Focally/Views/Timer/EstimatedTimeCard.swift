import SwiftUI

struct EstimatedTimeCard: View {
    @EnvironmentObject var timerService: FocusTimerService

    var body: some View {
        SupportCard(
            title: "Estimated end",
            icon: "clock.badge.checkmark",
            tint: Color.focallySecondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(title: "Finish time", value: estimatedEndTimeString)
                supportMetric(title: "Time remaining", value: timerService.remainingMinutesString)
                supportMetric(title: "Current phase", value: timerService.phaseName)
            }
        }
    }

    private func supportMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
            Text(value)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
        }
    }

    private var estimatedEndTimeString: String {
        let endDate = Date().addingTimeInterval(TimeInterval(max(timerService.remainingSeconds, 0)))
        return endDate.formatted(date: .omitted, time: .shortened)
    }
}
