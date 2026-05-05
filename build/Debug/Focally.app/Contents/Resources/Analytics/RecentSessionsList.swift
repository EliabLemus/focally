import SwiftUI

struct RecentSessionsList: View {
    let sessions: [AnalyticsService.RecentSession]
    let onExportTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Recent Sessions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: onExportTap) {
                    Text("Export Data")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.focallyPrimary)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            // Session list
            ScrollView {
                VStack(spacing: 8) {
                    if sessions.isEmpty {
                        EmptyStateView(
                            icon: "timer",
                            message: "No sessions yet"
                        )
                    } else {
                        ForEach(sessions, id: \.id) { session in
                            SessionRowView(session: session)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    struct SessionRowView: View {
        let session: AnalyticsService.RecentSession

        var body: some View {
            HStack(spacing: 12) {
                // Date badge
                VStack(spacing: 0) {
                    Text(session.date.shortMonth)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.focallySurfaceContainer.opacity(0.5))
                        .cornerRadius(4)

                    Text("\(session.date.day)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 48, height: 48)

                // Session info
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.activity)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.focallyOnSurface)
                        .lineLimit(1)

                    Text("\(session.category) • \(String(format: "%dm", session.durationMinutes))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                // Duration
                Text("\(session.durationMinutes, specifier: "%.0f")m")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurface)

                // Rating
                StarRating(rating: session.rating)
            }
            .padding(12)
            .background(Color.focallySurfaceContainerLowest.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.focallyOutline.opacity(0.1))
            )
        }
    }
}

struct StarRating: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(
                        index < rating
                            ? Color.focallyPrimary
                            : Color.focallyOutline.opacity(0.3)
                    )
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Color.focallyOutline.opacity(0.3))

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.focallyOutline.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

extension Date {
    var shortMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: self)
    }

    var day: Int {
        Calendar.current.component(.day, from: self)
    }
}
