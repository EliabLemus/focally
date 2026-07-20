# Task: Slack Custom Emoji Rendering in Focally v0.8.1

## Goal
Render Slack custom emojis (workspace emojis like `:status_emoji:`) as images in the Focally UI, using URLs from the Slack emoji.list API response. Currently custom emojis show as raw shortcodes (e.g., `:status_emoji:`) instead of images.

## Context
- `SlackService.swift` already fetches `emoji.list` and stores `workspaceEmojiCodes: [String]` (just the shortcode names like `["alias_to_name", "custom_emoji", ...]`)
- The `emoji.list` API returns `[String: String]` mapping emoji names to their image URLs (e.g., `"custom_emoji" -> "https://slack-files.com/T.../custom_emoji.png"`)
- `EmojiValidator.convertShortcodeToUnicode()` only handles standard Slack shortcodes mapped to unicode. Custom emojis have NO unicode equivalent.
- `FocusMode.displayEmoji` calls `convertShortcodeToUnicode(emoji, workspaceEmojis: [])` — always passes `[]` for workspace emojis.
- Key places rendering emoji: `FocusModeCard.swift` line 13, `ActiveFocusView.swift` (menu bar), `MenuBarDropdownView.swift`, `OnItFocusApp.swift` line 230

## Requirements

### 1. SlackService — Store emoji image URLs
Add a new property:
```swift
var workspaceEmojiImageURLs: [String: String] = [:]  // ":emoji_name:" -> "https://..."
```

In `refreshEmojiCatalog()` (around line 376-392), when we have `emojiMap` from the API:
- The keys are emoji names (e.g., `"custom_emoji"`)
- The values are URLs (e.g., `"https://slack-files.com/T.../custom_emoji.png"`)
- Store as `[":\(key):": url]` so the keys match the shortcode format used elsewhere

### 2. EmojiValidator — Detect custom + return URL
Add a new static method:
```swift
public static func isCustomWorkspaceEmoji(_ shortcode: String, workspaceEmojiCodes: [String]) -> Bool {
    let trimmed = shortcode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isSlackShortcode(trimmed) else { return false }
    return workspaceEmojiCodes.contains(trimmed) && convertShortcodeToUnicode(trimmed, workspaceEmojis: []) == nil
}
```

### 3. FocusMode — Computed property for custom emoji URL
Add to `FocusMode` model (after `displayEmoji`):
```swift
/// Whether this emoji is a custom workspace emoji that needs AsyncImage rendering
var isCustomWorkspaceEmoji: Bool {
    EmojiValidator.isCustomWorkspaceEmoji(emoji, workspaceEmojiCodes: [])
}

/// URL for custom emoji image, if applicable. Requires SlackService workspaceEmojiImageURLs.
func imageURL(workspaceEmojiImageURLs: [String: String]) -> URL? {
    guard isCustomWorkspaceEmoji else { return nil }
    let urlString = workspaceEmojiImageURLs[emoji]
    return urlString.flatMap { URL(string: $0) }
}
```

### 4. UI — Create reusable EmojiView component
Create `Focally/Views/Shared/EmojiView.swift`:
```swift
import SwiftUI

struct EmojiView: View {
    let emoji: String
    let customEmojiImageURLs: [String: String]
    let font: Font
    
    init(_ emoji: String, customEmojiImageURLs: [String: String] = [:], font: Font = .system(size: 34)) {
        self.emoji = emoji
        self.customEmojiImageURLs = customEmojiImageURLs
        self.font = font
    }
    
    var body: some View {
        if let url = imageURL(customEmojiImageURLs: customEmojiImageURLs) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure:
                    Text(emoji).font(font)  // fallback to shortcode text
                case .empty:
                    ProgressView().frame(width: font == .system(size: 34) ? 34 : 20, height: font == .system(size: 34) ? 34 : 20)
                @unknown default:
                    Text(emoji).font(font)
                }
            }
            .frame(width: 34, height: 34)
        } else {
            Text(EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: []) ?? emoji)
                .font(font)
        }
    }
    
    private func imageURL(customEmojiImageURLs: [String: String]) -> URL? {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmojiValidator.isCustomWorkspaceEmoji(trimmed, workspaceEmojiCodes: []) else { return nil }
        let urlString = customEmojiImageURLs[trimmed]
        return urlString.flatMap { URL(string: $0) }
    }
}
```

### 5. Wire SlackService into UI components
In views that render emojis, pass `slackService.workspaceEmojiImageURLs` to EmojiView:

- **FocusModeCard.swift** (line 13): Replace `Text(mode.displayEmoji).font(.system(size: 34))` with `EmojiView(mode.emoji, customEmojiImageURLs: slackService.workspaceEmojiImageURLs, font: .system(size: 34))`. Add `@Environment(SlackService.self) private var slackService` if not present.
- **ActiveFocusView.swift**: Same pattern — replace emoji Text with EmojiView where the emoji is shown during active session.
- **MenuBarDropdownView.swift**: Same — replace emoji Text with EmojiView in the dropdown header.
- **OnItFocusApp.swift** (line 230): For menu bar title, custom emojis in menu bar titles are problematic. Keep using `convertShortcodeToUnicode` here — fallback to shortcode text if custom (menu bar doesn't support images). Log a warning if custom emoji is used in menu bar title.

### 6. IdleDashboardView — Ensure emoji catalog is loaded
Already calls `slackService.refreshEmojiCatalogIfPossible()` in `onAppear` (line 31). Good.

### 7. FocusModeEditSheet — Show preview of custom emoji
In the emoji TextField, add a small preview below it using EmojiView so the user sees the actual image when typing a custom shortcode.

## Important Notes
- `EmojiValidator` is inside `SlackService.swift` (line 740). Keep it there.
- `SlackService` is `@MainActor @Observable`. `workspaceEmojiImageURLs` will auto-trigger view updates.
- Slack emoji URLs are typically `https://...slack-files.com/...` or `https://...emoji.slack-edge.com/...` — both HTTPS, AsyncImage handles them fine.
- Don't add `@Environment(SlackService.self)` to `FocusMode` model — it's a plain struct. Pass the URLs as a parameter instead.
- The `isCustomWorkspaceEmoji` function checks that it IS a valid slack shortcode AND is in the workspace list AND has no unicode conversion. Standard shortcodes like `:brain:` will still render as unicode.
- Keep `displayEmoji` as-is for backwards compatibility (used in non-UI contexts like logging).

## Files to modify
- `Focally/Services/SlackService.swift` — add `workspaceEmojiImageURLs`, store URLs from API, add `isCustomWorkspaceEmoji` to EmojiValidator
- `Focally/Models/FocusMode.swift` — add `isCustomWorkspaceEmoji` computed property
- `Focally/Views/Shared/EmojiView.swift` — NEW file, reusable emoji rendering component
- `Focally/Views/Timer/FocusModeCard.swift` — use EmojiView
- `Focally/Views/Timer/ActiveFocusView.swift` — use EmojiView
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — use EmojiView
- `Focally/OnItFocusApp.swift` — keep text fallback for menu bar, add warning log for custom emojis
- `Focally/Views/Timer/FocusModeEditSheet.swift` — add emoji preview

## Testing
- All existing unit tests must pass
- Build must succeed in both Debug and Release configurations
- Run locally: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests`
- Run locally: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`

## DO NOT
- Don't add any new dependencies
- Don't change FocusMode.builtInModes defaults
- Don't modify the emoji validation logic for Slack API calls
- Don't touch SoundPlayerService or sound files
