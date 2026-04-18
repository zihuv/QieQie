import SwiftUI

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
