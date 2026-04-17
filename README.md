# OnItFocus

> Minimal macOS menu bar app for focus sessions. Start a timer, get in the zone, let OnItFocus handle the rest.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green) ![Version](https://img.shields.io/badge/version-0.1.0-green)

## What it does

OnItFocus keeps you focused by managing your availability across your tools:

1. **Start a focus session** → timer starts, Do Not Disturb activates
2. **Slack status updates** → your team knows what you're working on *(coming soon)*
3. **Google Calendar syncs** → meetings auto-trigger focus mode *(coming soon)*
4. **Focus Planner** → fills free calendar slots with focus blocks *(coming soon)*

## Install

```bash
brew tap EliabLemus/onitfocus
brew install --cask onitfocus
```

Or download the [latest DMG from GitHub Releases](https://github.com/EliabLemus/onitfocus/releases).

### Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/EliabLemus/onitfocus.git
cd onitfocus
./scripts/build-release.sh
```

## Usage

| Action | What happens |
|--------|-------------|
| **Left-click** icon | Opens focus panel (start, countdown, extend, end) |
| **Right-click** icon | Context menu (settings, quit) |

### Focus Session
1. Click ⏳ → Start Focus Session
2. Enter activity + emoji + duration
3. Start → DND activates, countdown begins
4. Session ends → beep + notification + DND deactivates

### Settings (right-click → Settings)
- **Timer** — customize durations and alert sound
- **Tasks** — predefined activities for quick start
- **Connections** — Slack, Calendar, n8n *(coming soon)*
- **Appearance** — system theme integration

## Permissions

| Permission | Why | How to enable |
|---|---|---|
| **Accessibility** | Toggle Do Not Disturb | System Settings → Privacy & Security → Accessibility → Add OnItFocus |
| **Notifications** | Session end alerts | System Settings → Notifications → OnItFocus → Allow |
| **Automation** | Control Focus Mode | System Settings → Privacy & Security → Automation → OnItFocus → System Events → ✅ |

### Troubleshooting

- **DND doesn't activate** → Check Accessibility permissions + verify Focus shortcut in Keyboard settings
- **No notification** → System Settings → Notifications → OnItFocus → Allow
- **Repeated Automation prompts** → System Settings → Privacy & Security → Automation → OnItFocus → System Events → ✅

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   OnItFocus App                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ Menu Bar │ │  Timer   │ │  Settings Panel  │  │
│  │  (NSBar) │ │ Service  │ │  (SwiftUI)       │  │
│  └────┬─────┘ └────┬─────┘ └────────┬─────────┘  │
│       │            │               │            │
│  ┌────┴────────────┴───────────────┴─────────┐   │
│  │            DND Service                     │   │
│  └────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         │                    │
    ┌────┴────┐        ┌────┴────┐
    │  Slack  │        │ Calendar │
    │   API   │        │   API    │
    └─────────┘        └────┬────┘
                           │
                      ┌────┴────┐
                      │   n8n   │
                      │WebSocket│
                      └─────────┘
```

## Roadmap

| # | Iteration | Description | Status |
|---|-----------|-------------|--------|
| 1 | MVP | Menu bar + DND + timer + settings | ✅ v0.1.0 |
| 2 | Slack Status | Auto-update Slack status on focus start/end | 🔜 Next |
| 3 | Calendar Read | Google Calendar integration, conflict detection | Planned |
| 4 | Focus Planner | Fill free calendar slots with focus blocks | Planned |
| 5 | Calendar Sync | n8n WebSocket for real-time event push | Planned |
| 6 | Polish | Session history, keyboard shortcuts, auto-start | Planned |
| 7a | Distribution | Homebrew tap, DMG, CI/CD | ✅ v0.1.0 |
| 7b | Official Cask | Submit to homebrew/homebrew-cask | Future |

## Tech Stack

- **SwiftUI** — macOS 14+ native UI
- **NSStatusBar** — Custom menu bar icon with right-click support
- **FocusFilterSet** — System Do Not Disturb control
- **XcodeGen** — Project generation from YAML
- **GitHub Actions** — Automated DMG build + Homebrew tap update

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## License

MIT
