import SwiftUI

struct SchedulePage: View {
    @StateObject private var scheduleService = ScheduleService()
    @State private var selectedViewIndex = 0
    @State private var currentWeekStart = Date()

    private let viewOptions = ["Week", "Month", "Day"]

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            TopBarView {
                Text("Focus Schedule")
                    .font(.focallyH2)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Calendar controls row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monthYearString(for: currentWeekStart))
                            .font(.focallyH2)
                            .foregroundStyle(Color.focallyOnSurface)
                        Text("Focus Schedule")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOutline)
                    }

                    Spacer()

                    // Google Calendar sync badge
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                        Text("Synced")
                            .font(.focallyCaption)
                    }
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.08))
                    )

                    // New Session button
                    FocallyPillButton(title: "New Session", icon: "plus") {
                        print("New session")
                    }

                    // History button
                    Button(action: { print("History") }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.focallySurfaceContainer)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Week navigation
                HStack(spacing: 12) {
                    Button(action: { navigateWeek(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                    }
                    .buttonStyle(.plain)

                    Button(action: { currentWeekStart = Date() }) {
                        Text("Today")
                            .font(.focallyButton)
                            .foregroundStyle(Color.focallyPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { navigateWeek(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    FocallySegmentedControl(selection: $selectedViewIndex, options: viewOptions)
                }

                // Calendar grid
                WeekCalendarView(startDate: currentWeekStart, currentWeekStart: currentWeekStart)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.focallyBackground)
        .onAppear { scheduleService.loadWeek() }
    }

    private func navigateWeek(_ direction: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: direction, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
