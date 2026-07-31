import Foundation
import SwiftUI

struct EstimatedTimeCard: View {
    @Environment(FocusTimerService.self) private var timerService

    var body: some View {
        SupportCard(
            title: AppLanguage.shared.localizedString("estimated_end_title"),
            icon: "clock.badge.checkmark",
            tint: Color.focallySecondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                supportMetric(title: AppLanguage.shared.localizedString("estimated_finish_time"), value: estimatedEndTimeString)
                supportMetric(title: AppLanguage.shared.localizedString("estimated_time_remaining"), value: timerService.remainingMinutesString)
                supportMetric(title: AppLanguage.shared.localizedString("estimated_current_phase"), value: timerService.phaseName)
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
        return endDate.formatted(date: Date.FormatStyle.DateStyle.omitted, time: Date.FormatStyle.TimeStyle.shortened)
    }
}
