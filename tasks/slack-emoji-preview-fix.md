# Spec: Fix Slack Emoji Preview in Quick Sessions

## Problem
1. **Emoji preview not rendering**: In `QuickSessionsSection.swift`, `slackStatusPreview` displays emojis verbatim without converting Slack shortcodes (e.g., `:hourglass_flowing_sand:`) to Unicode (e.g., `⏳`). The preview shows literal text instead of visual emojis.
2. **UI verification needed**: Quick Sessions UI should be reviewed for compliance with current design system (spacing tokens, radius tokens, glass effects, shadows, borders).

## Solution

### 1. Fix Emoji Preview in QuickSessionsSection.swift

**File**: `Focally/Views/Calendar/QuickSessionsSection.swift`

**Change**: Add a helper to convert shortcodes to unicode for display, similar to `emojiDisplayString(for:)` in `FocusSessionComponents.swift`.

**Implementation**:
- Add a computed property `displayEmoji` that uses `EmojiValidator.convertShortcodeToUnicode(selectedEmoji, workspaceEmojis: slackService.workspaceEmojiCodes)`
- If conversion fails, fallback to original `selectedEmoji`
- Use `displayEmoji` in `slackStatusPreview` instead of raw `selectedEmoji`

**Reference pattern**: See `EmojiSelectionPopover.emojiDisplayString(for:)` in `Focally/Views/Shared/FocusSessionComponents.swift` (lines 241-247).

### 2. Verify Quick Sessions UI Compliance

Review `QuickSessionsSection.swift` for:
- Spacing: Use `FocallySpacing` tokens (not hardcoded values). Already using some tokens, verify consistency.
- Radius: Use `FocallyRadius` tokens for corner radius (currently uses hardcoded values like 10, 12, 14).
- Colors: Use `Color.focally*` tokens from design system (already compliant).
- Glass effects: Consider if glass modifier should be applied to the section card. Currently uses `sectionBackground: Color.focallySurfaceContainerLowest.opacity(0.65)`. Review if `FocallyGlassModifier` with `.card` style is appropriate.

**Specific checks**:
- Line 27: `RoundedRectangle(cornerRadius: 14)` → should use `FocallyRadius.medium` (12) or `FocallyRadius.large` (16)? Check design system guidance.
- Line 66: `RoundedRectangle(cornerRadius: 10)` → should use `FocallyRadius.small` (8) or `FocallyRadius.medium` (12)?
- Line 95: `RoundedRectangle(cornerRadius: 12)` → should use `FocallyRadius.medium` (12) ✓
- Line 114: `RoundedRectangle(cornerRadius: 12)` → should use `FocallyRadius.medium` (12) ✓
- Padding: Line 25 uses `padding(14)`. Should use `FocallySpacing.medium` (16) for consistency.

### 3. Optional: Extract Emoji Display Helper

If emoji display logic is needed in multiple views, extract to a shared utility:
- Create `Focally/DesignSystem/EmojiDisplayHelper.swift` with `func displayEmoji(for emoji: String, workspaceEmojis: [String]) -> String`
- Use in both `QuickSessionsSection` and `FocusSessionComponents`

## Acceptance Criteria
1. ✅ Slack emoji preview in Quick Sessions displays visual Unicode emoji (e.g., `⏳`) instead of shortcode text (e.g., `:hourglass_flowing_sand:`)
2. ✅ If shortcode cannot be converted, shows the original shortcode as fallback
3. ✅ Quick Sessions UI uses design tokens consistently (spacing, radius)
4. ✅ No hardcoded spacing/radius values that should use tokens
5. ✅ Tests pass (if any exist for this view)

## Notes
- The `SlackService` is already available as an environment object in `QuickSessionsSection`
- `EmojiValidator.convertShortcodeToUnicode` already exists in `SlackService.swift`
- Focus on minimal, targeted changes to fix the preview issue