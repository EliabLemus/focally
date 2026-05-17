# SWIFT_UI_REFERENCE.md — Referencia de SwiftUI para macOS

---

## Views Principales

### WindowGroup
```swift
@main
struct FocallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### MenuBarExtra (macOS 14+)
```swift
MenuBarExtra("Focally", systemImage: "calendar") {
    MenuBarDropdownView()
}
```

---

## State Management

### @State
```swift
@State private var isEnabled = false
Toggle("Enabled", isOn: $isEnabled)
```

### @Binding
```swift
struct ChildView: View {
    @Binding var isEnabled: Bool
}

// Parent:
ChildView(isEnabled: $isEnabled)
```

### @StateObject
```swift
@StateObject private var viewModel = TimerViewModel()
```

### @ObservedObject
```swift
@ObservedObject var viewModel: TimerViewModel
```

### @EnvironmentObject
```swift
@EnvironmentObject private var calendarService: GoogleCalendarService
```

---

## Modifiers

### Layout
```swift
.padding(16)
.frame(maxWidth: .infinity)
.background(Color.focallySurfaceContainerLow)
```

### Style
```swift
.font(.focallyBody)
.foregroundStyle(Color.focallyOnSurface)
```

### Interaction
```swift
.buttonStyle(.plain)
.onTapGesture {
    // action
}
```

---

## macOS-Specific

### NO usar iOS APIs
- ❌ `.keyboardType()` — iOS only
- ❌ `.navigationTitle()` — iOS only
- ✅ `.navigationSubtitle()` — macOS only

### Menu bar
```swift
MenuBarExtra("Focally", systemImage: "calendar") {
    MenuBarDropdownView()
}
.menuBarStyle(.window)
```

### Window controls
```swift
.windowStyle(.hiddenTitleBar)
.windowToolbarStyle(.unified(showsTitle: false))
```

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios