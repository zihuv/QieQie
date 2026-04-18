import SwiftUI

enum FocusPanelSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 14
    static let xxl: CGFloat = 16
}

enum FocusPanelCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
    static let large: CGFloat = 12
}

enum FocusPanelControl {
    static let compactRowHeight: CGFloat = 30
    static let fieldHeight: CGFloat = 34
    static let numericFieldWidth: CGFloat = 64
    static let unitLabelWidth: CGFloat = 24
    static let pickerWidth: CGFloat = 104
    static let pickerPopoverWidth: CGFloat = 188
}

enum FocusPanelColor {
    static let groupFill = Color(nsColor: NSColor.controlBackgroundColor).opacity(0.18)
    static let groupStroke = Color(nsColor: NSColor.separatorColor).opacity(0.14)
    static let fieldFill = Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3)
    static let fieldStroke = Color(nsColor: NSColor.separatorColor).opacity(0.16)
    static let rowFill = Color.primary.opacity(0.04)
    static let selectionFill = Color.accentColor.opacity(0.09)
    static let selectionStroke = Color.accentColor.opacity(0.14)
    static let tagFill = Color.accentColor.opacity(0.08)
    static let tagStroke = Color.accentColor.opacity(0.14)
    static let timelineNodeStroke = Color.accentColor.opacity(0.14)
    static let timelineConnector = Color.accentColor.opacity(0.18)

    static func chartColor(for index: Int) -> Color {
        let opacities: [Double] = [0.9, 0.72, 0.56, 0.42, 0.3, 0.2]
        return Color.accentColor.opacity(opacities[index % opacities.count])
    }
}

enum FocusPanelNSColor {
    static let rowFill = NSColor.labelColor.withAlphaComponent(0.04)
    static let selectionFill = NSColor.controlAccentColor.withAlphaComponent(0.09)
    static let selectionStroke = NSColor.controlAccentColor.withAlphaComponent(0.14)
}

enum FocusPanelChrome {
    static let surfaceCornerRadius = FocusPanelCornerRadius.large
    static let sectionCornerRadius = FocusPanelCornerRadius.large
    static let surfaceFill = FocusPanelColor.groupFill
    static let surfaceStroke = FocusPanelColor.groupStroke
    static let compactPadding = FocusPanelSpacing.lg
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
    static let heroMetric = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let chartValue = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let entryTitle = Font.system(size: 12, weight: .semibold)
    static let dateLabel = Font.system(size: 11, weight: .semibold)
}
