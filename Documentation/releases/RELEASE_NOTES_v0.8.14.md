# v0.8.14 — macOS Calendar Integration

## What's New

Calendar events now sync with your Slack status and DND automatically — no OAuth required.

### Features
- 🗓️ **macOS Calendar Integration** — Detects active meetings from your Calendar app (via EventKit)
- 🔗 **Slack Status Auto-Update** — Shows "In a meeting" or "In meeting: [Title]" during meetings
- 🎬 **Smart DND for Video Calls** — Activates Do Not Disturb only for meetings with video calls
- ⚙️ **Toggle Controls** — Choose whether to show meeting title in Slack, enable DND for calls
- 🔐 **Simple Permissions** — One macOS permission dialog, no Client ID / Secret setup
- 🔄 **30-Second Polling** — Checks for active meetings every 30 seconds
- ✅ **Multi-Calendar Support** — Works with Google, iCloud, Outlook (all calendars in macOS Calendar)

### Removed
- ❌ Google Calendar OAuth (Client ID / Secret removed)
- ❌ Google Cloud Console setup requirement
- ❌ GoogleCalendarService (+Auth, +API, +Events, +Formatters, GoogleCalendarModels)

### Setup
1. Right-click Focally → Settings → Integrations → Calendar → Toggle ON
2. macOS popup: "Focally wants to access your calendars" → Click "Allow"
3. Configure toggles:
   - Show meeting title in Slack (shows specific meeting name vs generic "In a meeting")
   - Enable DND for calls (activates DND only for video calls)

### Technical Details
- **Framework:** EventKit (macOS native)
- **Permission:** NSCalendarsFullAccessUsageDescription
- **Polling Interval:** 30 seconds
- **Video Call Detection:** meet.google.com links, event.location, event.url, event.hasAttendees
- **Service:** CalendarSlackIntegrationService (new)
- **Persistence:** UserDefaults (calendarEnabled, calendarShowMeetingTitle, calendarDndForMeetings)