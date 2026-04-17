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

extension View {
    func focusPanelSurface(cornerRadius: CGFloat = FocusPanelChrome.surfaceCornerRadius) -> some View {
        background(FocusPanelChrome.surfaceFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FocusPanelChrome.surfaceStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func focusPanelFieldSurface(cornerRadius: CGFloat = FocusPanelCornerRadius.medium) -> some View {
        background(FocusPanelColor.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FocusPanelColor.fieldStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct FocusPanelSection<Content: View>: View {
    let title: String
    let titleColor: Color
    private let content: () -> Content

    init(
        title: String,
        titleColor: Color = .secondary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.titleColor = titleColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.xs) {
            Text(title)
                .font(FocusPanelTypography.sectionTitle)
                .foregroundColor(titleColor)

            content()
        }
    }
}

struct FocusPanelGroup<Content: View>: View {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let usesSurface: Bool
    private let content: () -> Content

    init(
        horizontalPadding: CGFloat = FocusPanelSpacing.md,
        verticalPadding: CGFloat = FocusPanelSpacing.md,
        usesSurface: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.usesSurface = usesSurface
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        let group = VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)

        if usesSurface {
            group.focusPanelSurface()
        } else {
            group
        }
    }
}

struct FocusPanelFormRow<Trailing: View>: View {
    let title: String
    let labelWidth: CGFloat
    private let trailing: () -> Trailing

    init(
        title: String,
        labelWidth: CGFloat,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.labelWidth = labelWidth
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: FocusPanelSpacing.sm) {
            Text(title)
                .font(FocusPanelTypography.bodyLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(width: labelWidth, alignment: .leading)

            Spacer(minLength: FocusPanelSpacing.xxs)

            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FocusPanelSpacing.sm)
        .padding(.vertical, FocusPanelSpacing.xs)
    }
}

struct FocusPanelDivider: View {
    let leadingInset: CGFloat

    init(leadingInset: CGFloat = FocusPanelSpacing.sm) {
        self.leadingInset = leadingInset
    }

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

struct FocusSelectableRow<Content: View>: View {
    let isSelected: Bool
    private let content: () -> Content

    init(
        isSelected: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isSelected = isSelected
        self.content = content
    }

    var body: some View {
        HStack(spacing: FocusPanelSpacing.sm) {
            content()
        }
        .padding(.horizontal, FocusPanelSpacing.md)
        .frame(height: FocusPanelControl.compactRowHeight)
        .background(
            RoundedRectangle(cornerRadius: FocusPanelCornerRadius.small, style: .continuous)
                .fill(isSelected ? FocusPanelColor.selectionFill : FocusPanelColor.rowFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FocusPanelCornerRadius.small, style: .continuous)
                .stroke(isSelected ? FocusPanelColor.selectionStroke : .clear, lineWidth: 1)
        )
    }
}

struct FocusTagBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FocusPanelTypography.supportingText)
            .foregroundColor(.accentColor)
            .lineLimit(1)
            .padding(.horizontal, FocusPanelSpacing.sm)
            .padding(.vertical, 3)
            .background(FocusPanelColor.tagFill)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(FocusPanelColor.tagStroke, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }
}

struct FocusTimelineRow: View {
    let timeText: String
    let tagTitle: String
    let title: String
    let usesPlaceholderTitle: Bool
    let durationText: String
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FocusPanelSpacing.md) {
            FocusTimelineMarker(showsConnector: showsConnector)

            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text(timeText)
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                HStack(spacing: FocusPanelSpacing.xs) {
                    FocusTagBadge(title: tagTitle)

                    Text(title)
                        .font(FocusPanelTypography.entryTitle)
                        .lineLimit(1)
                        .foregroundColor(usesPlaceholderTitle ? .secondary : .primary)
                }
            }

            Spacer(minLength: FocusPanelSpacing.sm)

            Text(durationText)
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .padding(.top, 1)
        }
        .padding(.vertical, FocusPanelSpacing.xs)
    }
}

private struct FocusTimelineMarker: View {
    let showsConnector: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: FocusPanelSpacing.sm, height: FocusPanelSpacing.sm)
                .overlay(
                    Circle()
                        .stroke(FocusPanelColor.timelineNodeStroke, lineWidth: 4)
                )

            if showsConnector {
                Rectangle()
                    .fill(FocusPanelColor.timelineConnector)
                    .frame(width: 1, height: 34)
                    .padding(.top, FocusPanelSpacing.xxs)
            }
        }
        .frame(width: FocusPanelSpacing.lg, alignment: .top)
        .padding(.top, FocusPanelSpacing.xxs)
    }
}
