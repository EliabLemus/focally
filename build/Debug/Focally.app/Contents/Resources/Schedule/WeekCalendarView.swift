import SwiftUI

struct WeekCalendarView: View {
    let startDate: Date
    let currentWeekStart: Date

    var body: some View {
        ScrollView {
            LazyVGrid(columns: calendarColumns, spacing: 0) {
                // Time column
                TimeColumn()

                // Day columns
                ForEach(daysInWeek, id: \.self) { day in
                    DayColumn(date: day, isCurrent: isCurrentDay(day))
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var calendarColumns: [GridItem] {
        let columns: [GridItem] = [
            GridItem(.fixed(60), spacing: 0),
            GridItem(.flexible())
        ]
        return Array(repeating: columns[1], count: 7)
    }

    private var daysInWeek: [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfMonth, for: startDate) else {
            return []
        }

        var days: [Date] = []
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: weekStart.start) {
                days.append(day)
            }
        }
        return days
    }

    private func isCurrentDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
}

struct TimeColumn: View {
    var body: some View {
        ForEach(8...13, id: \.self) { hour in
            VStack(alignment: .leading, spacing: 0) {
                Text("\(hour):00")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.focallyOutline)
                    .frame(width: 60, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)
                Divider()
                    .frame(height: 1)
                    .overlay(Color.focallyOutline.opacity(0.1))
            }
            .frame(height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.focallyOutline.opacity(0.03))
                    .frame(height: 1)
            )
        }
    }
}

struct DayColumn: View {
    let date: Date
    let isCurrent: Bool

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.weekdayFormatter.string(from: date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.focallyOutline)
                    .tracking(1.5)
                    .padding(.leading, 12)
                    .frame(height: 48, alignment: .leading)

                if isCurrent {
                    Rectangle()
                        .fill(Color.focallyPrimary.opacity(0.05))
                        .frame(height: 48)
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.focallyPrimary : Color.focallyOnSurface)
                    .frame(height: 48, alignment: .leading)
                    .padding(.leading, 12)
            }

            // Time slots
            ForEach(8...13, id: \.self) { hour in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(hour):00")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.focallyOutline.opacity(0.5))
                        .frame(width: 60, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.vertical, 4)

                    Divider()
                        .frame(height: 1)
                        .overlay(Color.focallyOutline.opacity(0.03))
                }
                .frame(height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.focallyOutline.opacity(0.03))
                        .frame(height: 1)
                )
            }
        }
    }
}
