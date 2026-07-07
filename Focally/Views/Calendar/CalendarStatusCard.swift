import SwiftUI

struct CalendarStatusCard: View {
    @Environment(GoogleCalendarService.self) private var calendarService
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var pulseOuterRing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusBadge
            statusDetails
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusBorderColor, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatusLabel)
        .accessibilityHint("Shows current calendar status")
        .onAppear {
            pulseOuterRing = true
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 10) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle = status.subtitle {
                    Text(subtitle)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusBadgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9999))
    }

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(status.color.opacity(pulseOuterRing ? 0.18 : 0.34), lineWidth: 1)
                        .scaleEffect(pulseOuterRing ? 1.75 : 1.1)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulseOuterRing)
                }

            if differentiateWithoutColor {
                Image(systemName: status.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(status.color)
            }
        }
        .accessibilityHidden(true)
    }

    private var statusDetails: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 24, height: 24)
                .background(status.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(status.detail)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var status: CalendarAvailabilityStatus {
        if calendarService.isEnabled && (!calendarService.isSignedIn || calendarService.connectionError != nil) {
            return .disconnected(error: calendarService.connectionError)
        }

        let now = Date()
        if let meeting = calendarService.events.first(where: { now >= $0.startTime && now < $0.endTime }) {
            return .inMeeting(meeting)
        }

        let nextMeeting = calendarService.events.first { $0.startTime > now }
        if let meeting = nextMeeting, meeting.startTime.timeIntervalSince(now) < 3600 {
            return .upNext(meeting)
        }

        return .free(nextMeeting: nextMeeting)
    }

    private var statusBadgeBackground: Color {
        status.color.opacity(0.15)
    }

    private var statusBorderColor: Color {
        status.color.opacity(0.3)
    }

    private var cardBackground: Color {
        Color.focallySurfaceContainerLow
    }

    private var accessibilityStatusLabel: String {
        ([status.title, status.subtitle, status.detail].compactMap { $0 }).joined(separator: ". ")
    }
}

private extension CalendarStatusCard {
    enum CalendarAvailabilityStatus {
        case free(nextMeeting: CalendarEvent?)
        case inMeeting(CalendarEvent)
        case upNext(CalendarEvent)
        case disconnected(error: String?)

        var color: Color {
            switch self {
            case .free:
                return Color(red: 0.13, green: 0.77, blue: 0.37)
            case .inMeeting:
                return Color(red: 0.94, green: 0.27, blue: 0.27)
            case .upNext:
                return Color(red: 0.92, green: 0.76, blue: 0.03)
            case .disconnected:
                return Color(red: 0.86, green: 0.15, blue: 0.15)
            }
        }

        var symbol: String {
            switch self {
            case .free:
                return "checkmark"
            case .inMeeting:
                return "calendar"
            case .upNext:
                return "clock"
            case .disconnected:
                return "exclamationmark.triangle"
            }
        }

        var icon: String {
            switch self {
            case .free:
                return "checkmark.circle.fill"
            case .inMeeting:
                return "calendar.badge.clock"
            case .upNext:
                return "clock.fill"
            case .disconnected:
                return "exclamationmark.triangle.fill"
            }
        }

        var title: String {
            switch self {
            case .free:
                return "Free for focus"
            case .inMeeting:
                return "In a meeting"
            case .upNext:
                return "Up next"
            case .disconnected:
                return "Calendar disconnected"
            }
        }

        var subtitle: String? {
            switch self {
            case .free:
                return nil
            case .inMeeting(let meeting), .upNext(let meeting):
                return "Google Calendar • \(Self.formatter.string(from: meeting.startTime))"
            case .disconnected:
                return "Reconnect Google Calendar to resume conflict checks"
            }
        }

        var detail: String {
            switch self {
            case .free(let nextMeeting):
                if let nextMeeting {
                    return "No conflicts until \(Self.formatter.string(from: nextMeeting.startTime))"
                }
                return "No conflicts until next event"
            case .inMeeting(let meeting):
                return "\(meeting.title) • until \(Self.formatter.string(from: meeting.endTime))"
            case .upNext(let meeting):
                return "\(meeting.title) • \(Self.formatter.string(from: meeting.startTime))"
            case .disconnected(let error):
                return error ?? "Google Calendar needs attention"
            }
        }

        private static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter
        }()
    }
}
