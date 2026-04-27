import SwiftUI

struct CalendarEventsView: View {
    @EnvironmentObject var calendarService: GoogleCalendarService

    let sessionInterval: DateInterval?
    let maxVisibleEvents: Int?

    init(sessionInterval: DateInterval? = nil, maxVisibleEvents: Int? = nil) {
        self.sessionInterval = sessionInterval
        self.maxVisibleEvents = maxVisibleEvents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today's Events", systemImage: "calendar")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button("Refresh") {
                    calendarService.fetchTodayEvents()
                }
                .buttonStyle(.link)
                .font(.caption)
                .disabled(!calendarService.isEnabled || !calendarService.isSignedIn)
            }

            if let error = calendarService.connectionError, calendarService.isEnabled {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if visibleEvents.isEmpty {
                Text("No events today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private var visibleEvents: ArraySlice<CalendarEvent> {
        let events = calendarService.events
        if let maxVisibleEvents {
            return events.prefix(maxVisibleEvents)
        }
        return ArraySlice(events)
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        let hasConflict = sessionInterval.map {
            DateInterval(start: event.startTime, end: event.endTime).intersects($0)
        } ?? false

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if hasConflict {
                Text("Conflict")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hasConflict ? Color.orange.opacity(0.08) : Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
