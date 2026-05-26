import SwiftUI

public struct FocusStatusOption: Identifiable, Hashable {
    let emoji: String
    let label: String
    let shortcode: String?

    public var id: String { shortcode ?? emoji }

    static let common: [FocusStatusOption] = [
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

struct TaskColorOption: Identifiable, Hashable {
    let name: String
    let backgroundHex: String
    let foregroundHex: String

    var id: String { backgroundHex + foregroundHex }

    static let all: [TaskColorOption] = [
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

public struct CompactStatusEmojiButton: View {
    @Binding var selection: String
    let options: [FocusStatusOption]

    @EnvironmentObject private var slackService: SlackService
    @State private var isPopoverPresented = false

    /// Determina si el emoji actual tiene problemas de validación
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
                    .stroke(hasValidationError ? Color.focallyError : Color.focallyOutline, lineWidth: hasValidationError ? 1.5 : 0.75)
            }
        }
        .buttonStyle(.plain)
        .help("Click to change status emoji")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            EmojiSelectionPopover(selection: $selection, options: options)
                .environmentObject(slackService)
        }
    }

    static func isSlackShortcode(_ value: String) -> Bool {
        value.hasPrefix(":") && value.hasSuffix(":") && value.count > 2
    }
}

private struct EmojiSelectionPopover: View {
    @Binding var selection: String
    let options: [FocusStatusOption]

    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var usageTracker: EmojiUsageTracker

    @State private var draftValue: String = ""

    /// Emojis recientes basados en uso
    private var recentCodes: [String] {
        let workspaceEmojis = slackService.isConnected ? slackService.workspaceEmojiCodes : nil
        return usageTracker.getRecentEmojis(forWorkspace: workspaceEmojis)
    }

    /// Emojis del workspace filtrados por búsqueda
    private var workspaceCodes: [String] {
        let query = draftValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return Array(slackService.workspaceEmojiCodes.prefix(12)) }
        return slackService.workspaceEmojiCodes
            .filter { $0.lowercased().contains(query) }
            .prefix(12)
            .map { $0 }
    }

    /// Determina si mostrar sección de workspace
    private var showWorkspaceSection: Bool {
        slackService.isConnected && !slackService.workspaceEmojiCodes.isEmpty
    }

    public var body: some View {
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

            // SECCIÓN 1: Recientes (prioridad)
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

            // SECCIÓN 2: Workspace (solo si Slack está configurado y hay búsqueda o hay recientes vacíos)
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

            // SECCIÓN 3: Common (menor prioridad cuando Slack está configurado)
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

    /// Botón simple para mostrar un emoji (shortcode o unicode)
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

        // Si es texto alfanumérico, convertir a shortcode
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

public struct DurationControl: View {
    @Binding var minutes: Int
    var range: ClosedRange<Int> = 5...180
    var step: Int = 5

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

public struct PredefinedTaskQuickButton: View {
    let task: PredefinedTask
    let action: () -> Void
    @State private var isHovering = false

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

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.focallyPrimary)
                    .opacity(isHovering ? 1 : 0)
                    .offset(x: isHovering ? 0 : -4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLowest.opacity(isHovering ? 0.9 : 0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? Color.focallyPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
