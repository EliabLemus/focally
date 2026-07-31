# v0.2.0 — Slack Status Integration

## What's New

Your team now knows when you're focused — automatically.

### Features
- 🔗 **Slack Status Sync** — Status updates automatically when you start/end a focus session
- 📝 **Activity + Emoji** — Your focus activity and emoji appear in Slack (e.g., "📝 Writing report")
- ⏱ **Auto-expiration** — Slack status clears when your focus session ends
- 🔑 **Secure Token Storage** — Slack token stored in macOS Keychain (never in plain text)
- ⚙️ **Settings → Connections** — Configure Slack token, toggle on/off, test connection
- 🔄 **Independent Toggle** — Enable/disable Slack without affecting DND or timer

### Setup
1. Create a Slack App at api.slack.com
2. Add `users.profile:write` scope (User OAuth)
3. Install to workspace, copy `xoxp-` token
4. Right-click OnItFocus → Settings → Connections → Slack → paste token
5. Click "Test Connection" → ✅
