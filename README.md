<div align="center">

# ⏳ Focally

**Focus sessions, managed.**

A minimal macOS menu bar app that handles Do Not Disturb, Slack status, and timer — so you can focus on what matters.

[![Build](https://github.com/EliabLemus/focally/actions/workflows/release.yml/badge.svg)](https://github.com/EliabLemus/focally/actions)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://github.com/EliabLemus/focally)
[![Version](https://img.shields.io/badge/version-0.7.15-green)](https://github.com/EliabLemus/focally/releases)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

## Why Focally?

We looked at every focus app out there. None did what we needed:

- **Timing apps** (Pomodone, Session) — no DND, no Slack sync
- **Menu bar timers** (Thyme, Hour) — no status integration
- **Productivity suites** (RescueTime, Forest) — heavy, expensive, opinionated

Focally is one thing: **start a timer, get in the zone, let the app handle the rest.** No subscriptions, no bloat, no cloud dependency.

## Features

| Feature | Status |
|---------|--------|
| Focus timer (25/45/60/custom min) | ✅ |
| Direct System Do Not Disturb | ✅ |
| Apple Shortcuts integration | ✅ |
| App Intents (Start/End Focus) | ✅ |
| Slack status sync | ✅ |
| Alert sound with repeat | ✅ |
| Predefined tasks | ✅ |
| Keychain-stored secrets | ✅ |
| Google Calendar read | ✅ |
| Session history | ✅ |
| Schedule management | ✅ |
| Analytics | ✅ |
| Drag & Drop shortcut installation | ✅ |
| Onboarding wizard | ✅ |

## Install

```bash
brew tap EliabLemus/focally
brew install --cask focally
```

## Upgrade

```bash
brew update && brew upgrade --cask focally
```

[Download latest DMG](https://github.com/EliabLemus/focally/releases) · [Build from source](#build-from-source)

## How it works

| Step | What happens |
|------|-------------|
| **Start** | Pick an activity + duration → timer begins |
| **Focus** | Direct System DND activates, optional Apple Shortcuts run, Slack status updates automatically |
| **Finish** | Bell rings, notification fires, DND deactivates |

### Controls

- **Left-click** ⏳ → focus panel (start, countdown, extend, end)
- **Right-click** ⏳ → context menu (settings, quit)

## Permissions

| Permission | Why | How |
|---|---|---|
| Accessibility | Toggle Do Not Disturb | System Settings → Privacy → Accessibility → Add Focally |
| Notifications | Session alerts | System Settings → Notifications → Focally → Allow |

## Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## Tech

SwiftUI · AppKit · App Intents · NSStatusBar · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contributing

Fork → branch → PR. Keep it minimal. ✨

### Making Releases

For detailed release procedures and troubleshooting, see [docs/RELEASE_GUIDE.md](docs/RELEASE_GUIDE.md).

### Focus Integration

Focally provides two modes for focus integration:

**Direct System DND (Recommended)**
- Focally directly controls macOS Do Not Disturb
- No setup required
- Most reliable method

**Apple Shortcuts Integration**
- Focally generates test shortcuts on first launch
- Drag & drop shortcuts to Settings → Integrations
- Optional backup automation
- Full guide: [docs/FOCUS_INTEGRATION_USER_GUIDE.md](docs/FOCUS_INTEGRATION_USER_GUIDE.md)

**App Intents**
- Focally exposes "Start Focus" and "End Focus" actions
- Available in Shortcuts, Spotlight, and Siri
- No manual setup required

## License

[MIT](LICENSE)

---
<div align="center">
Made with ⏳ by <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>
