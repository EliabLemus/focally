# Focally — Project Instructions for AI Agents

## Build & Run
```bash
xcodegen generate
xcodebuild build -project Focally.xcodeproj -scheme Focally -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Key Rules
1. **NSStatusBar** (not MenuBarExtra) — right-click support needed
2. **Settings** — NSWindow manual con NSHostingController (no SwiftUI Scene)
3. **NSMenuItem.target = self** — siempre, o las acciones no disparan
4. **Sin dependencias externas** — solo system frameworks
5. **Tokens en Keychain** — nunca UserDefaults
6. **Código en inglés, comentarios en inglés**
7. **macOS 14+ mínimo**

## Architecture
- `AppDelegate` → NSStatusItem, NSPopover, services
- `Services/` → ObservableObject (Timer, DND, Slack, etc.)
- `Views/` → SwiftUI (FocusMenuView, SettingsView)
- `Models/` → data models
- `Resources/` → audio, assets

## Communication
```swift
NotificationCenter.default.post(name: .focusSessionStarted, object: nil)
NotificationCenter.default.addObserver(self, selector: #selector(onSessionStarted), name: .focusSessionStarted, object: nil)
```

## Don't Modify Without Permission
- FocusMenuView (main panel)
- ActivityInputView
- Approved features
