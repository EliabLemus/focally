import Foundation

// MARK: - Event Fetching

extension GoogleCalendarService {
    func fetchTodayEvents(completion: (() -> Void)? = nil) {
        Task { @MainActor [weak self] in
            defer { completion?() }
            await self?.fetchTodayEventsInternal(forceRefreshAfterUnauthorized: true)
        }
    }

    func checkConflict(during session: DateInterval) -> CalendarEvent? {
        events.first { event in
            let eventInterval = DateInterval(start: event.startTime, end: event.endTime)
            return eventInterval.intersects(session)
        }
    }

    private func fetchTodayEventsInternal(forceRefreshAfterUnauthorized: Bool) async {
        guard isEnabled, isSignedIn,
              await refreshAccessTokenIfNeeded(), let accessToken else {
            handleAuthCheckError()
            return
        }

        guard let url = buildTodayEventsURL() else {
            connectionError = "Could not build Google Calendar request"
            return
        }

        let request = buildEventsRequest(url: url, accessToken: accessToken)
        await performEventsRequest(request, forceRefreshAfterUnauthorized: forceRefreshAfterUnauthorized)
    }

    private func handleAuthCheckError() {
        if !isEnabled {
            events = []
        } else if !isSignedIn {
            connectionError = "Google Calendar not connected"
            events = []
        } else {
            connectionError = "Google Calendar authentication expired"
            events = []
        }
    }

    private func buildTodayEventsURL() -> URL? {
        var components: URLComponents? = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        )
        components?.queryItems = [
            URLQueryItem(name: "timeMin", value: Self.googleDateTimeFormatter.string(from: startOfToday)),
            URLQueryItem(name: "timeMax", value: Self.googleDateTimeFormatter.string(from: endOfToday)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]
        return components?.url
    }

    private func buildEventsRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performEventsRequest(_ request: URLRequest, forceRefreshAfterUnauthorized: Bool) async {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                connectionError = "Invalid Google Calendar response"
                return
            }

            await handleEventsResponse(
                httpResponse,
                data: data,
                forceRefreshAfterUnauthorized: forceRefreshAfterUnauthorized
            )
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private func handleEventsResponse(
        _ httpResponse: HTTPURLResponse,
        data: Data,
        forceRefreshAfterUnauthorized: Bool
    ) async {
        if httpResponse.statusCode == 401, forceRefreshAfterUnauthorized {
            let refreshed = await refreshAccessTokenIfNeeded()
            if refreshed {
                await fetchTodayEventsInternal(forceRefreshAfterUnauthorized: false)
            }
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            connectionError = "Google Calendar request failed (\(httpResponse.statusCode))"
            return
        }

        let payload = try? JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
        events = payload?.items.compactMap(Self.makeCalendarEvent(from:)) ?? []
        connectionError = nil
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var endOfToday: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? Date()
    }
}
