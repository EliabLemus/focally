import SwiftUI
import Foundation

struct CalendarMeetingCard: View {
    let meeting: CalendarMeeting
    let isActive: Bool

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: meeting.startTime)) - \(formatter.string(from: meeting.endTime))"
    }

    var body: some View {
        HStack(spacing: FocallySpacing.small) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.focallyPrimary : Color.focallyTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                    .lineLimit(1)

                Text(timeRange)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            if meeting.hasVideoCall {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.focallySecondary)
            }
        }
        .padding(FocallySpacing.small)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.small)
                .fill(isActive ? Color.focallyPrimaryContainer : Color.focallySurfaceContainerLow)
        )
    }
}
