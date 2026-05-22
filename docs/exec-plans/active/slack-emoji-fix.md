# Spec: Slack Emoji Fix + Preview with Images

## Summary
Fix Bug #3 (emoji mismatch hardcoded) + Add image preview for Slack emoji catalog

## Context
User reported 3 bugs with Slack integration:
1. ✅ FIXED: No emoji catalog dropdown (fixed by adding emoji:read scope)
2. ❌ PENDING: Notifications not muted (DND bug)
3. ❌ PENDING: Emoji mismatch (🧠 in Focally → 🎯 in Slack)

User wants:
- Fix Bug #3 (hardcoded emoji in FocusIntegrationService)
- Preview emoji IMAGES in catalog (currently only names)

## Technical Implementation

### 1. Fix Bug #3 - Emoji Mismatch

**File:** `Focally/Services/FocusIntegrationService.swift`

**Problem:** Lines 120, 213 hardcode emoji 🎯

**Current code:**
```swift
slackService.setSlackFocusStatus(text: "In focus", emoji: "🎯")
```

**Fix:** Use emoji from current task or saved emoji

```swift
// Get emoji from current task or fallback to saved emoji
let emoji = currentTask?.emoji ?? slackService.savedStatusEmoji()
slackService.setSlackFocusStatus(text: "In focus", emoji: emoji)
```

**Note:** Need to add access to `currentTask` in FocusIntegrationService or pass it as parameter.

---

### 2. Add Image Preview for Slack Emojis

**Files:**
- `Focally/Services/SlackService.swift` - Add emoji URLs
- `Focally/Views/Settings/IntegrationsSettingsView.swift` - Show images in UI

**Implementation Steps:**

#### Step 1: Update SlackService.swift

**Create new struct for emoji with URL:**
```swift
struct SlackEmoji: Identifiable, Codable {
    let id = UUID()
    let shortcode: String        // :brain:
    let name: String             // brain
    let imageURL: String?        // https://emoji.slack-edge.com/... (custom) or nil (standard)
    let isStandard: Bool         // true if standard Slack emoji, false if custom
}
```

**Add published property:**
```swift
@Published var workspaceEmojis: [SlackEmoji] = []
```

**Update refreshEmojiCatalogIfPossible:**

```swift
// After parsing emojiMap from Slack API (line 366):
guard let emojiMap = json["emoji"] as? [String: String] else { ... }

let emojis = emojiMap.keys.map { name -> SlackEmoji in
    let value = emojiMap[name]!
    let isAlias = value.starts(with: "alias:")
    let imageURL: String? = isAlias ? nil : value

    return SlackEmoji(
        shortcode: ":\(name):",
        name: name,
        imageURL: imageURL,
        isStandard: isAlias
    )
}.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

DispatchQueue.main.async {
    self.workspaceEmojis = emojis
    self.workspaceEmojiCodes = emojis.map { $0.shortcode }
    self.connectionError = nil
    self.logger.info("Loaded \(emojis.count) Slack workspace emojis successfully")
}
```

**Keep backward compatibility:**
```swift
@Published var workspaceEmojiCodes: [String] = [] // Keep for existing code
@Published var workspaceEmojis: [SlackEmoji] = [] // NEW with URLs
```

---

#### Step 2: Update IntegrationsSettingsView.swift

**Add emoji preview grid:**

```swift
// Replace lines 62-78 with emoji preview:
if slackService.workspaceEmojis.isEmpty {
    Text("Slack emoji catalog: Loading...")
        .font(.focallyCaption)
        .foregroundStyle(Color.focallyOnSurfaceVariant)
} else {
    VStack(alignment: .leading, spacing: FocallySpacing.medium) {
        HStack(spacing: FocallySpacing.extraSmall) {
            Text("Slack emoji catalog: \(slackService.workspaceEmojis.count) emojis loaded")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyTertiary)
            Button("Reload") {
                slackService.refreshEmojiCatalogIfPossible()
            }
            .font(.focallyCaption)
            .buttonStyle(.plain)
            .foregroundStyle(Color.focallyPrimary)
        }

        // Emoji preview grid
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: FocallySpacing.small) {
                ForEach(slackService.workspaceEmojis.prefix(48)) { emoji in
                    EmojiPreviewCell(emoji: emoji)
                }
            }
        }
        .frame(height: 200)
    }
}
```

**Create EmojiPreviewCell view:**

```swift
struct EmojiPreviewCell: View {
    let emoji: SlackEmoji

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let imageURL = emoji.imageURL,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 32, height: 32)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        case .failure:
                            Text(emoji.shortcode)
                                .font(.title3)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.focallySurfaceVariant)
                    .cornerRadius(8)
                } else {
                    // Standard emoji - render unicode directly
                    Text(emoji.name)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.focallySurfaceVariant)
                        .cornerRadius(8)
                }
            }
            .onTapGesture {
                // Copy shortcode to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(emoji.shortcode, forType: .string)
            }

            Text(emoji.name)
                .font(.caption2)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .lineLimit(1)
        }
        .padding(4)
    }
}
```

---

## Testing

### Manual Test 1: Emoji Mismatch Fix
1. Open Focally
2. Configure custom task with emoji 🧠
3. Start focus session
4. Check Slack status - should show 🧠, not 🎯

### Manual Test 2: Emoji Preview
1. Open Focally → Settings → Integrations → Slack
2. Verify emoji catalog loads
3. Should see emoji images (not just names)
4. Click on emoji - should copy shortcode to clipboard
5. Scroll to see more emojis (limit to 48, or add load more button)

---

## Files to Modify

1. `Focally/Services/SlackService.swift`
   - Add `SlackEmoji` struct
   - Add `@Published var workspaceEmojis: [SlackEmoji]`
   - Update `refreshEmojiCatalogIfPossible` to parse URLs

2. `Focally/Services/FocusIntegrationService.swift`
   - Fix lines 120, 213 to use emoji from task/saved

3. `Focally/Views/Settings/IntegrationsSettingsView.swift`
   - Replace emoji catalog text with preview grid
   - Add `EmojiPreviewCell` view

---

## Backward Compatibility

✅ Keep `workspaceEmojiCodes: [String]` for existing code
✅ Add `workspaceEmojis: [SlackEmoji]` as new feature
✅ Old code using `workspaceEmojiCodes` continues to work

---

## Priority

HIGH - User requested and simple implementation

---

## Success Criteria

- [ ] Fix Bug #3: User's emoji 🧠 appears in Slack (not 🎯)
- [ ] Emoji catalog shows IMAGES (not just names)
- [ ] Clicking emoji copies shortcode to clipboard
- [ ] Build succeeds
- [ ] No SwiftLint violations (or fix them)