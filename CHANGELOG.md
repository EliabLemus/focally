# Changelog

All notable changes to Focally will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.13.0] - 2026-11-06

### Fixed
- 🎛️ **DND que sí funciona en macOS moderno** — la activación usa el shortcut firmado como vía primaria en macOS 14+ (la escritura legacy de preferencias que el sistema ignora quedó como fallback ≤13) y la verificación ya no se auto-valida leyendo lo que ella misma escribió.
- 💾 **Errores de persistencia visibles** — fallos de E/S se registran y un JSON corrupto se pone en cuarentena (`.corrupt-<timestamp>`) y se regenera, en lugar de fallar silenciosamente en cada lanzamiento.

### Changed
- ⚡ **Ticker de UI eficiente** — timer de 1 Hz anclado al segundo de pared con `tolerance` (mejor batería), valor derivado del reloj (título correcto al despertar del sleep en el primer tick) y re-dibujo solo cuando el texto cambia.
- 📅 **Sincronización de calendario con debounce** — ráfagas de cambios del calendario coalescen en un solo refetch (~2s).
- 🏗️ **SlackService en capas** — refactor interno con rate limiting por método (respeta `Retry-After` en todas las rutas, protege el token de bloqueos por 429) y Keychain con update-or-add. Sin cambios visibles.

## [0.12.0] - 2026-11-06

### Added
- 📞 **Custom call emojis** — per-client Slack emoji overrides in Call Detection Settings (picker with workspace emoji search) plus an override for Unknown Client calls.
- 🌐 **Arc support** — Google Meet calls in Arc now resolve to `:google-meet:` instead of falling back to `:phone:`.

## [0.11.1] - 2026-11-06

### Fixed
- 📞 **Call detection on macOS 15.x** — attribution now uses the documented `kAudioHardwarePropertyProcessObjectList` ('prs#') API (the legacy 'pobj' selector does not exist in the SDK and fails on macOS 15), reads bundle IDs directly from CoreAudio, and retries transient coreaudiod errors.
- 📞 **Attribution fallback** — if process attribution fails while a mic device is actively capturing, the call is still detected as an Unknown Client (`:phone:`) instead of being silently missed.
- 📅 **Calendar permission nag** — calendar access is only requested when calendar→Slack sync is enabled; permission-loss alerts no longer flag the disabled calendar integration.

### Changed
- 🔄 **Discreet Update Availability** — Updates now appear only in Settings → About, without dashboard, menu bar, or native notification alerts.

## [0.11.0] - 2026-11-06

### Added
- 📞 **Call Detection** — Event-driven mic/camera monitoring (no polling): joining any call (Google Meet in Chrome, Slack, Zoom, Teams and more) automatically pauses your focus/Pomodoro, sets Slack status with a per-client emoji (default `In a Call - Powered by Focally`), and enables Do Not Disturb. Everything restores on hang-up.
- ⚙️ **Calls Settings Panel** — Toggle Slack status during calls, customize the status message (256-char limit), toggle DND and session pause per call.
- 🛡️ **DND Reliability Layers** — Legacy write → verify via Control Center → at-most-once escalation through the signed generic Focus-by-Name shortcut; Focally's own notifications go passive during calls.
- 📅 **Calendar → Slack Sync now off by default** — with one-time migration for existing installs; re-enable it in Settings → Integrations. Real call activity now drives presence instead.

## [0.9.2] - 2026-07-24

### Fixed
- 📊 **Metrics Recording** — Added `recordMetricsOnCompletion()` to `resetToIdle()` (Finish Session button now records)
- 📍 **Menu Bar Layout** — Increased emoji gap 3→6px, dynamic emoji measuring (no more overlap with pause control)
- 🔲 **Focus Mode Icons Clipped** — Fixed `EmojiView` frame constraints (`minWidth/minHeight` + `.fixedSize()`)
- 🌐 **Missing Localization** — Fixed `"metrics_tab"` → `"tab_metrics"` in Metrics title
- 📅 **Monthly Metrics Picker** — Added prev/next month navigation (prev/next chevrons, month label)
- 😊 **Emoji Rendering** — `.fixedSize()` on all emoji Text views, dynamic width measuring
- 🌐 **Language Picker Crash** — Added `.environment(appLanguage)` to MainWindow (fixed missing environment object fatal error)

### Localization Keys Added (EN/ES/PT)
- `metrics_prev_month`
- `metrics_next_month`

### Technical
- 🏗️ **Build** — Version bump to 0.9.2 (build 72)
- 🐛 **Debug** — Added debug prints in metrics recording flow
- ✅ **Tests** — All 47 tests passing

## [0.9.1] - 2026-07-24

### Fixed
- 🐛 **Critical SF Symbol Crash** — Replaced `moon.slash.fill` (iOS-only) → `moon` in ActiveFocusView (2 locations)
- 📊 **Metrics Threshold** — Record sessions >= 5s (was 30s), now captures 2-minute sessions
- 🌐 **Missing Localization** — Fixed `edit_mode_title` interpolation bug (raw key display)
- 📝 **Missing Title Field** — Added TextField for Focus Mode name in edit sheet
- ⏱️ **Duration Control UX** — Improved Stepper (1-600 range, localized format)
- 📅 **Calendar Control UX** — Custom date picker with prev/next chevrons
- 📍 **Menu Bar Layout** — Fixed emoji overlapping text (spacing: 1 → 2)
- 🔄 **Break Label Conditional** — Only visible when Pomodoro is enabled

### Localization Keys Added (EN/ES/PT)
- `edit_mode_name`, `edit_mode_name_placeholder`
- `edit_mode_duration_value`
- `metrics_prev_day`, `metrics_next_day`

### Technical
- 🏗️ **Build** — Version bump to 0.9.1 (build 71)
- ✅ **Tests** — All 47 tests passing

## [0.9.0] - 2026-07-24

### Added
- 🌍 **Multi-language Support** (EN/ES/PT) — Full localization for UI, settings, and notifications
- 🔔 **Permission Loss Detection** — Alert when Accessibility/Calendar/DND/Notifications permissions are lost after updates
- 🔄 **Slack Auto-Reconnection** — Automatically reconnect Slack on app launch if connection was lost
- 📜 **ScrollView in Focus Mode Edit** — Scrollable form for better UX with many Pomodoro settings
- 😊 **Visible Emoji Trigger Buttons** — Add 😊 button next to all emoji fields (Mode Emoji, Break Label, Status Message)
- 🎨 **Status Message Emoji Support** — Insert emojis into Slack status messages via picker
- 📋 **Simplified UI Hierarchy** — 2-level structure with "Basic Settings" and "Advanced Settings" sections
- 🔔 **Update Checker Service** — Check for new versions automatically and notify in About screen

### Fixed
- 🖥️ **Multi-Monitor Popover Positioning** — Force popover window to appear on monitor with Menu Bar icon
- 📝 **Window Title Cleanup** — Remove redundant "Focally Setup" text from popover title
- ⚠️ **Permission Detection Post-Update** — Detect and alert when macOS permissions are lost after app updates
- 🔌 **Slack Connection State** — Reset connection attempt flag to allow auto-reconnection on app launch

### Changed
- 🎨 **UI Layout** — Focus Mode Edit Sheet restructured from 3-level to 2-level hierarchy
- 🔧 **Settings Visibility** — Break Label always visible (was hidden in Pomodoro section)
- ⚙️ **Toggle Independence** — DND and Pomodoro toggles are now independent (no nesting)

### Technical
- 📦 **PermissionService.swift** — New service for detecting and alerting permission loss
- 🔧 **SlackService.swift** — Added `attemptAutoReconnectionIfNeeded()` method
- 🌐 **Localization** — 110+ translation keys added for EN/ES/PT
- 🏗️ **Build** — Project regen with `xcodegen` for new PermissionService.swift
- 🧪 **Tests** — All 34 tests passing

### Documentation
- 📄 **Research: Chat Platform Status Control** — Teams/Discord/Zoom API investigation for v0.9.1
- 📄 **Research: Focus Mode Edit Improvements** — UI/UX improvements documented with mockups

---

## [0.8.19] - 2026-07-24

### Fixed
- 🔔 **Permission Detection Post-Update** — Detect when Accessibility/Calendar permissions are lost after macOS updates

### Documentation
- 📄 **Release Notes** — Updated RELEASE_NOTES.md

---

## [0.8.18] - 2026-07-24

### Added
- 🔔 **Update Checker Service** — Automatically check for new GitHub releases and notify in About screen

---

## [0.8.0] - 2026-07-19

### Added
- 🔗 **Slack Status Integration** — Sync focus status with Slack profile
- 📝 **Activity + Emoji** — Display focus mode emoji and activity in Slack status
- ⏱ **Auto-expiration** — Clear Slack status when focus session ends
- 🔑 **Secure Token Storage** — Slack token stored in macOS Keychain

---

## [0.7.23] - 2026-07-17

### Added
- 📅 **Calendar Integration** — Block calendar events during focus sessions
- 🔕 **Do Not Disturb** — Enable macOS DND during focus sessions
- ⏱ **Pomodoro Timer** — Work/Break cycles with customizable durations

---

## [0.7.22] - 2026-07-15

### Added
- 🎯 **Focus Modes** — Create and manage custom focus modes
- 😊 **Emoji Support** — Custom workspace emojis via Slack
- ⚙️ **Settings Panel** — Comprehensive settings UI
- 🎨 **Theme System** — Light/Dark mode support

---

## [0.2.0] - 2026-07-10

### Added
- 🔗 **Slack Status Sync** — Initial Slack integration
- 📝 **Activity Tracking** — Log focus sessions
- 🎯 **Basic Timer** — 25-minute focus sessions
- 🔕 **DND Support** — Enable DND during focus

---

## [0.1.0] - 2026-07-01

### Added
- 🎯 **Initial Release**
- ⏱ **Basic Focus Timer**
- 🔕 **System DND Integration**
- 📊 **Session Tracking**

---

[Unreleased]: https://github.com/EliabLemus/focally/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/EliabLemus/focally/compare/v0.8.19...v0.9.0
[0.8.19]: https://github.com/EliabLemus/focally/compare/v0.8.18...v0.8.19
[0.8.18]: https://github.com/EliabLemus/focally/compare/v0.8.0...v0.8.18
[0.8.0]: https://github.com/EliabLemus/focally/compare/v0.7.23...v0.8.0
[0.7.23]: https://github.com/EliabLemus/focally/compare/v0.7.22...v0.7.23
[0.7.22]: https://github.com/EliabLemus/focally/compare/v0.7.21...v0.7.22
[0.7.21]: https://github.com/EliabLemus/focally/compare/v0.7.20...v0.7.21
[0.7.20]: https://github.com/EliabLemus/focally/compare/v0.7.19...v0.7.20
[0.7.19]: https://github.com/EliabLemus/focally/compare/v0.7.18...v0.7.19
[0.7.18]: https://github.com/EliabLemus/focally/compare/v0.7.17...v0.7.18
[0.7.17]: https://github.com/EliabLemus/focally/compare/v0.7.16...v0.7.17
[0.7.16]: https://github.com/EliabLemus/focally/compare/v0.7.15...v0.7.16
[0.7.15]: https://github.com/EliabLemus/focally/compare/v0.7.14...v0.7.15
[0.7.14]: https://github.com/EliabLemus/focally/compare/v0.7.13...v0.7.14
[0.7.13]: https://github.com/EliabLemus/focally/compare/v0.7.12...v0.7.13
[0.7.12]: https://github.com/EliabLemus/focally/compare/v0.7.11...v0.7.12
[0.7.11]: https://github.com/EliabLemus/focally/compare/v0.7.10...v0.7.11
[0.7.10]: https://github.com/EliabLemus/focally/compare/v0.7.9...v0.7.10
[0.7.9]: https://github.com/EliabLemus/focally/compare/v0.7.8...v0.7.9
[0.7.8]: https://github.com/EliabLemus/focally/compare/v0.7.7...v0.7.8
[0.7.7]: https://github.com/EliabLemus/focally/compare/v0.7.6...v0.7.7
[0.7.6]: https://github.com/EliabLemus/focally/compare/v0.7.5...v0.7.6
[0.7.5]: https://github.com/EliabLemus/focally/compare/v0.7.4...v0.7.5
[0.7.4]: https://github.com/EliabLemus/focally/compare/v0.7.3...v0.7.4
[0.7.3]: https://github.com/EliabLemus/focally/compare/v0.7.2...v0.7.3
[0.7.2]: https://github.com/EliabLemus/focally/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/EliabLemus/focally/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/EliabLemus/focally/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/EliabLemus/focally/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/EliabLemus/focally/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/EliabLemus/focally/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/EliabLemus/focally/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/EliabLemus/focally/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/EliabLemus/focally/releases/tag/v0.1.0
