# v0.8.17 — Comprehensive UI Hit Area Fixes

## Fixes

### Interactive Element Hit Areas
Expanded click targets across all interactive UI elements to respond to taps across entire visual component:

**Sidebar Navigation:**
- `SidebarItemView`: Hit area now spans full sidebar width (previously limited to icon+text)

**Menu Bar Dropdown:**
- `MenuBarDropdownView`: Quick start mode cards respond to taps anywhere (previously only text/icon)

**Settings Navigation:**
- `SettingsPage`: Subpage navigation tabs have full-area hitbox (previously limited to label)

**Shared Components:**
- `FocallySegmentedControl`: Segment buttons have full hit area across entire control
- `FocallyPillButton`: Pill buttons have full hit area (previously limited to padding bounds)

## Impact

All interactive elements in Focally now respond to clicks across their entire visual area, not just text/icon bounds. This significantly improves usability on touchpads and makes the UI more forgiving for mouse users.

## Technical Details

Applied `.contentShape(Rectangle())` and/or `.frame(maxWidth: .infinity)` to:
- Sidebar navigation items
- Menu bar quick start cards
- Settings subpage tabs
- Segmented control segments
- Pill buttons

Combined with existing `.buttonStyle(.plain)` to ensure consistent hit behavior across the app.