import SwiftUI

struct FocusBlockView: View {
    let block: FocusBlock
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(block.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(block.isCurrentSession ? Color.focallyOnPrimary : Color.focallyOnSurfaceVariant)
                .lineLimit(1)

            Text(block.timeRange)
                .font(.system(size: 10))
                .foregroundStyle(block.isCurrentSession ? Color.focallyOnPrimary.opacity(0.8) : .focallyOutline)
        }
        .padding(8)
        .background(blockBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(block.borderColor, lineWidth: block.isCurrentSession ? 0 : 4)
        )
        .shadow(color: block.isCurrentSession ? .black.opacity(0.1) : .clear, radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }

    private var blockBackground: Color {
        switch block.color {
        case .primary:
            return Color.focallyPrimary.opacity(block.isCurrentSession ? 1 : 0.1)
        case .tertiary:
            return Color.focallyTertiaryContainer.opacity(0.1)
        case .secondary:
            return Color.focallySecondaryContainer.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch block.color {
        case .primary:
            return block.isCurrentSession ? .white : .focallyPrimary
        case .tertiary:
            return .focallyTertiaryContainer
        case .secondary:
            return .focallySecondaryContainer
        }
    }
}

extension FocusBlock {
    var timeRange: String {
        let calendar = Calendar.current
        let startFormatter = DateFormatter()
        startFormatter.timeStyle = .short

        let endFormatter = DateFormatter()
        endFormatter.timeStyle = .short

        let startDate = calendar.dateComponents([.hour, .minute], from: startDate)
        let endDate = calendar.dateComponents([.hour, .minute], from: endDate)

        let startHour = startDate.hour ?? 0
        let startMinute = startDate.minute ?? 0
        let endHour = endDate.hour ?? 0
        let endMinute = endDate.minute ?? 0

        return "\(startHour):\(String(format: "%02d", startMinute)) – \(endHour):\(String(format: "%02d", endMinute))"
    }
}
