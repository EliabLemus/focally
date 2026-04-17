# Focally ⏳

> Minimal macOS menu bar app for focus sessions. Start a timer, get in the zone, let Focally handle the rest.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green) ![Version](https://img.shields.io/badge/version-0.2.0-green)

## What it does

Focally keeps you focused by managing your availability across your tools:

1. **Start a focus session** → timer starts, Do Not Disturb activates
2. **Slack status updates** → your team knows what you're working on *(coming soon)*
3. **Google Calendar syncs** → meetings auto-trigger focus mode *(coming soon)*
4. **Focus Planner** → fills free calendar slots with focus blocks *(coming soon)*

## Install

```bash
brew tap EliabLemus/focally
brew install --cask focally
```

Or download the [latest DMG from GitHub Releases](https://github.com/EliabLemus/focally/releases).

### Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
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
4. Session ends → bell + notification + DND deactivates

### Settings (right-click → Settings)
- **Timer** — customize durations, alert sound, repeat count
- **Tasks** — predefined activities for quick start
- **Connections** — Slack, Calendar, n8n *(coming soon)*
- **Secrets** — tokens and credentials (stored in macOS Keychain)
- **Appearance** — system theme integration

## Permissions

| Permission | Why | How to enable |
|---|---|---|
| **Accessibility** | Toggle Do Not Disturb | System Settings → Privacy & Security → Accessibility → Add Focally |
| **Notifications** | Session end alerts | System Settings → Notifications → Focally → Allow |
| **Automation** | Control Focus Mode | System Settings → Privacy & Security → Automation → Focally → System Events → ✅ |

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   Focally App                     │
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
| 2 | Slack Status | Auto-update Slack status on focus start/end | ✅ v0.2.0 |
| 3 | Calendar Read | Google Calendar integration, conflict detection | 🔜 Next |
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
