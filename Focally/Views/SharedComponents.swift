import SwiftUI

// MARK: - Focally Toggle Button

struct FocallyToggleButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .tint(Color.focallyPrimary)
            .labelsHidden()
    }
}

// MARK: - Focally Segmented Control

struct FocallySegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                Button(action: {
                    selection = index
                }) {
                    Text(options[index])
                        .font(.focallyCaption)
                        .foregroundStyle(selection == index ? Color.focallyOnSurface : Color.focallyOutline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection == index ? Color.focallySurfaceContainerHigh : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Focally Pill Button

struct FocallyPillButton: View {
    let title: String
    let icon: String?
    let isPrimary: Bool
    let action: () -> Void

    init(title: String, icon: String? = nil, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.focallyButton)
            }
            .foregroundStyle(isPrimary ? Color.focallyOnPrimary : Color.focallyOnSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPrimary ? Color.focallyPrimary : Color.focallySurfaceContainerHigh)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Color Option

public struct TaskColorOption: Identifiable, Hashable {
    public let name: String
    public let backgroundHex: String
    public let foregroundHex: String

    public var id: String { backgroundHex + foregroundHex }

    public static let all: [TaskColorOption] = [
        .init(name: "Blue", backgroundHex: "DBEAFE", foregroundHex: "1D4ED8"),
        .init(name: "Purple", backgroundHex: "F3E8FF", foregroundHex: "7E22CE"),
        .init(name: "Green", backgroundHex: "DCFCE7", foregroundHex: "15803D"),
        .init(name: "Orange", backgroundHex: "FFEDD5", foregroundHex: "EA580C"),
        .init(name: "Rose", backgroundHex: "FFE4E6", foregroundHex: "E11D48"),
        .init(name: "Amber", backgroundHex: "FEF3C7", foregroundHex: "D97706"),
        .init(name: "Cyan", backgroundHex: "CFFAFE", foregroundHex: "0891B2"),
        .init(name: "Slate", backgroundHex: "E2E8F0", foregroundHex: "334155")
    ]
}

// MARK: - Focus Status Option

public struct FocusStatusOption: Identifiable, Hashable {
    public let emoji: String
    public let label: String
    public let shortcode: String?

    public var id: String { shortcode ?? emoji }

    public static let common: [FocusStatusOption] = [
        .init(emoji: "🧠", label: "Deep work", shortcode: ":deep_work:"),
        .init(emoji: "💻", label: "Coding", shortcode: ":coding:"),
        .init(emoji: "📝", label: "Writing", shortcode: ":writing:"),
        .init(emoji: "📚", label: "Reading", shortcode: ":reading:"),
        .init(emoji: "🎯", label: "Priority", shortcode: ":priority:"),
        .init(emoji: "⚡️", label: "Sprint", shortcode: ":sprint:"),
        .init(emoji: "🔕", label: "Quiet", shortcode: ":quiet:"),
        .init(emoji: "☕️", label: "Light focus", shortcode: ":coffee:"),
        .init(emoji: "🍅", label: "Pomodoro", shortcode: ":pomodoro:")
    ]
}

// MARK: - Compact Status Emoji Button

public struct CompactStatusEmojiButton: View {
    @Binding var selection: String
    let options: [FocusStatusOption]

    @EnvironmentObject private var slackService: SlackService
    @State private var isPopoverPresented = false

    private var hasValidationError: Bool {
        slackService.isConnected && !EmojiValidator.isValidForSlack(selection, workspaceEmojis: slackService.workspaceEmojiCodes)
    }

    public var body: some View {
        Button {
            slackService.refreshEmojiCatalogIfPossible()
            isPopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Group {
                    if Self.isSlackShortcode(selection) {
                        Text(selection)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text(selection.isEmpty ? "🙂" : selection)
                            .font(.system(size: 18))
                    }
                }
                .foregroundStyle(Color.focallyOnSurface)

                if hasValidationError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.focallyError)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 54, minHeight: 40)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasValidationError ? Color.focallyError : Color.focallyCardBorder, lineWidth: hasValidationError ? 1.5 : 0.75)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            EmojiSelectionPopover(selection: $selection, options: options)
                .environmentObject(slackService)
        }
    }

    public static func isSlackShortcode(_ value: String) -> Bool {
        value.hasPrefix(":") && value.hasSuffix(":") && value.count > 2
    }
}

// MARK: - Duration Control

public struct DurationControl: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int

    public init(minutes: Binding<Int>, range: ClosedRange<Int> = 5...180, step: Int = 5) {
        self._minutes = minutes
        self.range = range
        self.step = step
    }

    public var body: some View {
        HStack(spacing: 12) {
            Stepper(value: binding, in: range, step: step) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                    Text("\(minutes) min")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                }
            }
            .labelsHidden()

            Spacer()

            HStack(spacing: 8) {
                durationButton(symbol: "minus", delta: -step)
                Text("\(minutes)m")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.focallyOnSurface)
                    .frame(minWidth: 52)
                durationButton(symbol: "plus", delta: step)
            }
        }
    }

    private var binding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { minutes = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private func durationButton(symbol: String, delta: Int) -> some View {
        Button {
            minutes = min(max(minutes + delta, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.focallyOnSurface)
                .frame(width: 28, height: 28)
                .background(Color.focallySurfaceContainerHigh)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Predefined Task Quick Button

public struct PredefinedTaskQuickButton: View {
    let task: PredefinedTask
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: task.iconBgColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                        .lineLimit(1)
                    Text("\(task.durationMinutes)m")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLowest.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emoji Selection Popover

private struct EmojiSelectionPopover: View {
    @Binding var selection: String
    let options: [FocusStatusOption]

    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var usageTracker: EmojiUsageTracker

    @State private var draftValue: String = ""

    private var recentCodes: [String] {
        let workspaceEmojis = slackService.isConnected ? slackService.workspaceEmojiCodes : nil
        return usageTracker.getRecentEmojis(forWorkspace: workspaceEmojis)
    }

    private var workspaceCodes: [String] {
        let query = draftValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return Array(slackService.workspaceEmojiCodes.prefix(12)) }
        return slackService.workspaceEmojiCodes
            .filter { $0.lowercased().contains(query) }
            .prefix(12)
            .map { $0 }
    }

    private var showWorkspaceSection: Bool {
        slackService.isConnected && !slackService.workspaceEmojiCodes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status emoji")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            TextField("Emoji or :shortcode:", text: $draftValue)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitDraft)

            Button(action: commitDraft) {
                Text("Use typed value")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .buttonStyle(.plain)

            if !recentCodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(recentCodes, id: \.self) { code in
                            emojiButton(code)
                        }
                    }
                }
            }

            if showWorkspaceSection, !workspaceCodes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Slack workspace")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(workspaceCodes, id: \.self) { code in
                            emojiButton(code)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Common")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                    ForEach(options) { option in
                        Button {
                            apply(option.shortcode ?? option.emoji)
                        } label: {
                            HStack(spacing: 8) {
                                Text(option.emoji)
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.label)
                                        .font(.system(size: 11, weight: .semibold))
                                    if let shortcode = option.shortcode {
                                        Text(shortcode)
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Self.matches(selection, against: option) ? Color.focallyPrimary.opacity(0.14) : Color.focallySurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { draftValue = selection }
    }

    private func emojiButton(_ code: String) -> some View {
        Button {
            apply(code)
        } label: {
            if Self.isSlackShortcode(code) {
                Text(code)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.focallyOnSurface)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selection == code ? Color.focallyPrimary.opacity(0.14) : Color.focallySurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text(code)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.focallyOnSurface)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(selection == code ? Color.focallyPrimary.opacity(0.14) : Color.focallySurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .buttonStyle(.plain)
    }

    private func commitDraft() {
        apply(normalizedValue(from: draftValue))
    }

    private func apply(_ value: String) {
        let normalized = normalizedValue(from: value)
        guard !normalized.isEmpty else { return }
        selection = normalized
        draftValue = normalized
        usageTracker.recordUsage(normalized)
    }

    private func normalizedValue(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return selection }

        if Self.isSlackShortcode(trimmed) {
            return trimmed
        }

        if trimmed.range(of: #"^[a-zA-Z0-9_+\- ]+$"#, options: .regularExpression) != nil {
            let slug = trimmed
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
            return ":\(slug):"
        }

        return trimmed
    }

    private static func matches(_ selection: String, against option: FocusStatusOption) -> Bool {
        selection == option.emoji || selection == option.shortcode
    }

    private static func isSlackShortcode(_ value: String) -> Bool {
        value.hasPrefix(":") && value.hasSuffix(":") && value.count > 2
    }
}
