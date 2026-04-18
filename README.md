<div align="center">

# ⏳ Focally

**Focus sessions, managed.**

A minimal macOS menu bar app that handles Do Not Disturb, Slack status, and timer — so you can focus on what matters.

[![Build](https://github.com/EliabLemus/focally/actions/workflows/release.yml/badge.svg)](https://github.com/EliabLemus/focally/actions)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://github.com/EliabLemus/focally)
[![Version](https://img.shields.io/badge/version-0.2.3-green)](https://github.com/EliabLemus/focally/releases)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## Install

```bash
brew tap EliabLemus/focally
brew install --cask focally
```

[Download latest DMG](https://github.com/EliabLemus/focally/releases) · [Build from source](#build-from-source)

## How it works

| Step | What happens |
|------|-------------|
| **Start** | Pick an activity + duration → timer begins |
| **Focus** | DND activates, Slack status updates automatically |
| **Finish** | Bell rings, notification fires, DND deactivates |

### Controls

- **Left-click** ⏳ → focus panel (start, countdown, extend, end)
- **Right-click** ⏳ → context menu (settings, quit)

### Features

- ⏱️ Focus timer with customizable durations (25/45/60/custom min)
- 🔇 Automatic Do Not Disturb on session start/end
- 💬 Slack status sync — shows your current task with emoji
- 🔔 Alert sound with configurable repeat
- 📋 Predefined tasks for quick start
- 🔑 Secrets stored in macOS Keychain

### Settings

| Tab | What it does |
|-----|-------------|
| **Timer** | Durations, alert sound, repeat count |
| **Tasks** | Predefined activities with emojis |
| **Connections** | Slack workspace toggle |
| **Secrets** | Tokens and credentials (Keychain) |

## Permissions

| Permission | Why | How |
|---|---|---|
| Accessibility | Toggle Do Not Disturb | System Settings → Privacy → Accessibility → Add Focally |
| Notifications | Session alerts | System Settings → Notifications → Focally → Allow |

## Roadmap

- ✅ v0.1 — MVP: menu bar, timer, DND, settings
- ✅ v0.2 — Slack status integration
- 🔜 v0.3 — Google Calendar read
- 📋 v0.4 — Focus Planner (calendar write)
- 📋 v0.5 — n8n WebSocket sync

## Build from source

Requires Xcode 16+ and macOS 14+.

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## Tech

SwiftUI · NSStatusBar · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contributing

Fork → branch → PR. Keep it minimal. ✨

## License

[MIT](LICENSE)

---
<div align="center">
Made with ⏳ by <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>
