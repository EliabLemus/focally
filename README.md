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

Or [download the latest DMG](https://github.com/EliabLemus/focally/releases).

## How it works

| Step | What happens |
|------|-------------|
| **Start** | Pick an activity + duration → timer begins |
| **Focus** | DND activates, Slack status updates |
| **Finish** | Bell rings, notification fires, DND deactivates |

### Controls

- **Left-click** the menu bar icon → focus panel
- **Right-click** → context menu (settings, quit)

### Settings

- **Timer** — durations, alert sound, repeat count
- **Tasks** — predefined activities for quick start
- **Connections** — Slack, Calendar, n8n *(coming soon)*
- **Secrets** — tokens stored in macOS Keychain

## Permissions

| Permission | Why |
|---|---|
| Accessibility | Toggle Do Not Disturb |
| Notifications | Session end alerts |

System Settings → Privacy & Security → Accessibility → Add Focally

## Roadmap

- ✅ **v0.1.0** — MVP: menu bar, timer, DND
- ✅ **v0.2.0** — Slack status integration
- 🔜 **v0.3.0** — Google Calendar read
- 📋 **v0.4.0** — Focus Planner (calendar write)
- 📋 **v0.5.0** — n8n WebSocket sync
- 📋 **v0.6.0** — Polish: history, shortcuts, auto-start

## Tech

SwiftUI · NSStatusBar · macOS 14+ · XcodeGen · GitHub Actions · Homebrew tap

## Contributing

Pull requests welcome. Fork → branch → PR.

## License

[MIT](LICENSE)

---
<div align="center">
Made with ⏳ by <a href="https://github.com/EliabLemus">EliabLemus</a>
</div>
