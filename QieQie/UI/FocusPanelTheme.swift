import SwiftUI

enum FocusPanelChrome {
    static let surfaceCornerRadius: CGFloat = 14
    static let sectionCornerRadius: CGFloat = 12
    static let surfaceFill = Color(nsColor: NSColor.controlBackgroundColor).opacity(0.42)
    static let surfaceStroke = Color(nsColor: NSColor.separatorColor).opacity(0.18)
    static let compactPadding: CGFloat = 12
}

enum FocusPanelLayout {
    static let unifiedPanelSize = CGSize(width: 220, height: 280)
}

enum FocusPanelTypography {
    static let headerBackIcon = Font.system(size: 11, weight: .semibold)
    static let headerBackLabel = Font.system(size: 12, weight: .medium)
    static let headerTitle = Font.system(size: 15, weight: .semibold)
    static let sectionTitle = Font.system(size: 13, weight: .semibold)
    static let bodyLabel = Font.system(size: 12, weight: .medium)
    static let supportingText = Font.system(size: 11, weight: .medium)
    static let controlIcon = Font.system(size: 13, weight: .medium)
    static let timerValue = Font.system(size: 16, weight: .semibold)
    static let cardValue = Font.system(size: 15, weight: .semibold)
    static let metricValue = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let entryTitle = Font.system(size: 12, weight: .semibold)
    static let dateLabel = Font.system(size: 11, weight: .semibold)
}

extension View {
    func focusPanelSurface(cornerRadius: CGFloat = FocusPanelChrome.surfaceCornerRadius) -> some View {
        background(FocusPanelChrome.surfaceFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FocusPanelChrome.surfaceStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
