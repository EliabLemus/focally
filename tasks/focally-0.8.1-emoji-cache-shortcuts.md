# Task: Emoji Cache + Global Keyboard Shortcuts for Focally v0.8.1

## TWO INDEPENDENT FEATURES — implement both

## Feature 1: Persistent Emoji Cache

### Goal
Cache Slack custom emoji images to disk so they don't need to be re-downloaded from Slack every time the app launches. Load from cache if available, fall back to network.

### Context
- `SlackService` has `workspaceEmojiImageURLs: [String: String]` (shortcode → image URL)
- `EmojiView` uses `AsyncImage` which downloads every time
- The app already has `Focally/Views/Shared/EmojiView.swift`

### Requirements

**A. Cache Service — Create `Focally/Services/EmojiCacheService.swift`**

```swift
import SwiftUI
import os.log

@Observable
final class EmojiCacheService {
    static let shared = EmojiCacheService()
    private let logger = Logger(subsystem: "app.focally.mac", category: "EmojiCache")
    
    private let cacheDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Focally/EmojiCache", isDirectory: true)
    }()
    
    /// Cached emojis: ":shortcode:" -> local file URL
    private(set) var cachedEmojis: [String: URL] = [:]
    
    init() {
        ensureCacheDirectory()
        loadCachedEmojis()
    }
    
    /// Load previously cached emoji file URLs into memory
    private func loadCachedEmojis() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }
        
        cachedEmojis = files.reduce(into: [:]) { partialResult, url in
            // File name is the shortcode with colons encoded (e.g., ":custom_emoji:.png")
            let fileName = url.deletingPathExtension().lastPathComponent
            partialResult[fileName] = url
        }
        logger.info("Loaded \(cachedEmojis.count) cached emojis from disk")
    }
    
    /// Get cached emoji image, or download and cache it
    func emoji(for shortcode: String, remoteURL: URL?) async -> URL? {
        // Check cache first
        if let cached = cachedEmojis[shortcode] {
            if FileManager.default.fileExists(atPath: cached.path) {
                return cached
            }
        }
        
        // Download if remote URL available
        guard let remoteURL else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("Failed to download emoji \(shortcode): bad response")
                return nil
            }
            
            // Determine extension from content type or URL
            let ext = remoteURL.pathExtension.isEmpty ? "png" : remoteURL.pathExtension
            // Encode colons in filename: ":emoji_name:" -> ":emoji_name:.png"
            let safeFileName = shortcode.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? shortcode
            let localURL = cacheDirectory.appendingPathComponent("\(safeFileName).\(ext)")
            
            try data.write(to: localURL)
            cachedEmojis[shortcode] = localURL
            logger.info("Cached emoji \(shortcode) to disk")
            return localURL
        } catch {
            logger.error("Failed to download emoji \(shortcode): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear the entire cache
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        ensureCacheDirectory()
        cachedEmojis = [:]
        logger.info("Emoji cache cleared")
    }
    
    private func ensureCacheDirectory() {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
```

**B. Update `EmojiView.swift` to use cache**

Replace the current `AsyncImage` approach:
- Add `@Environment(SlackService.self) private var slackService` OR accept `SlackService` as parameter
- Add `@State private var EmojiCacheService = EmojiCacheService.shared`
- In `body`, use `.task` to call `EmojiCacheService.shared.emoji(for:shortcode, remoteURL:)` 
- Show `Image(nsImage:)` for cached/downloaded emojis instead of `AsyncImage`
- Keep `AsyncImage` only as fallback while loading

Actually, simpler approach: add a `CachedEmojiImage` helper:
```swift
struct CachedEmojiImage: View {
    let shortcode: String
    let remoteURL: URL?
    
    @State private var localURL: URL?
    
    var body: some View {
        Group {
            if let localURL, let nsImage = NSImage(contentsOf: localURL) {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(width: 34, height: 34)
                    .task {
                        localURL = await EmojiCacheService.shared.emoji(for: shortcode, remoteURL: remoteURL)
                    }
            }
        }
    }
}
```

Then `EmojiView` uses `CachedEmojiImage` for custom emojis and `Text` for standard unicode emojis.

**C. On app launch, pre-cache the emoji URLs**
In `OnItFocusApp.applicationDidFinishLaunching`, after the SlackService is set up, trigger a background cache warm-up for all workspace emojis.

### Feature 2: Global Keyboard Shortcuts

### Goal
Add global keyboard shortcuts so users can start/pause/end focus sessions from anywhere on macOS, without clicking the menu bar.

### Context
- AppIntents (`StartFocusAppIntent`, `EndFocusAppIntent`) already exist in `FocusIntegrationService.swift` — they work with Siri/Shortcuts app
- `FocusTimerService` has `startSession(mode:)`, `pauseSession()`, `resumeSession()`, `stopSession()`
- Users assign shortcuts in **System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts** (macOS built-in)
- BUT we should also offer **in-app configurable global shortcuts** using `CGEvent` hotkeys or `NSEvent.addGlobalMonitorForEvents`
- The simpler and more reliable approach: use the **App Shortcuts** system (Siri Shortcuts) which macOS already supports with customizable keyboard shortcuts. The user goes to System Settings → Keyboard → App Shortcuts → Focally → assign keys.

### Requirements

Since AppIntents already exist (`StartFocusAppIntent`, `EndFocusAppIntent`), the shortcuts are already available in macOS. We just need to:

**A. Add a Pause/Resume AppIntent — Create in `FocusIntegrationService.swift`**

```swift
@available(macOS 14.0, *)
struct PauseFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Focus"
    static var description = IntentDescription("Pauses the current Focally focus session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            FocusTimerService.shared.pauseSession()
        }
        return .result(dialog: "Focus paused.")
    }
}

@available(macOS 14.0, *)
struct ResumeFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Focus"
    static var description = IntentDescription("Resumes the paused Focally focus session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            FocusTimerService.shared.resumeSession()
        }
        return .result(dialog: "Focus resumed.")
    }
}
```

**B. Update `FocallyAppShortcutsProvider` to include Pause and Resume**

Add the two new AppShortcuts.

**C. Add a settings section to guide users**

In `GeneralSettingsView.swift`, add a section below "Show timer in Menu Bar" that links to System Settings:

```swift
// Section: Keyboard Shortcuts
settingsRow(icon: "keyboard", label: "View keyboard shortcuts") {
    // Open System Settings → Keyboard → App Shortcuts
    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?KeyboardShortcuts") {
        NSWorkspace.shared.open(url)
    }
}
```

This should be a row with a chevron/disclosure indicator that opens System Preferences to the App Shortcuts page. Make it look like a navigation link.

**D. Show available shortcuts in the General Settings**

Add an informational card/section showing the available shortcuts:
- "Start Focus" — assign in System Settings
- "Pause Focus" — assign in System Settings
- "Resume Focus" — assign in System Settings
- "End Focus" — assign in System Settings

This helps users discover the feature.

### Files to modify/create
1. **NEW** `Focally/Services/EmojiCacheService.swift`
2. **MODIFY** `Focally/Views/Shared/EmojiView.swift` — use CachedEmojiImage
3. **MODIFY** `Focally/Services/FocusIntegrationService.swift` — add Pause/Resume intents, update AppShortcutsProvider
4. **MODIFY** `Focally/Views/Settings/GeneralSettingsView.swift` — add keyboard shortcuts section with link to System Settings
5. **MODIFY** `Focally/OnItFocusApp.swift` — add EmojiCacheService environment, warm up cache on launch
6. **MODIFY** `Focally.xcodeproj/project.pbxproj` — add EmojiCacheService.swift

### Testing
- All existing unit tests must pass: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests`
- Release build must succeed: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- Do NOT run the app (no GUI testing needed)

### DO NOT
- Don't add any external dependencies
- Don't modify FocusMode defaults or SlackService emoji fetching logic
- Don't remove existing sound preview functionality
- Don't touch SoundPlayerService or DNDService internals
- Don't use `NSEvent.addGlobalMonitorForEvents` (the AppIntents approach is cleaner and works with macOS accessibility)
- Don't modify the timer logic
