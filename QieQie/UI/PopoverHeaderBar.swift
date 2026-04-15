import SwiftUI

enum FocusPanelChrome {
    static let surfaceCornerRadius: CGFloat = 14
    static let surfaceFill = Color(nsColor: NSColor.controlBackgroundColor).opacity(0.42)
    static let surfaceStroke = Color(nsColor: NSColor.separatorColor).opacity(0.18)
    static let compactPadding: CGFloat = 12
}

enum FocusPanelLayout {
    static let unifiedPanelSize = CGSize(width: 220, height: 280)
}

struct PopoverHeaderBar<Trailing: View>: View {
    let title: String
    let titleAccessibilityID: String?
    let backAccessibilityID: String?
    let onBack: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        titleAccessibilityID: String? = nil,
        backAccessibilityID: String? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.titleAccessibilityID = titleAccessibilityID
        self.backAccessibilityID = backAccessibilityID
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .applyAccessibilityIdentifier(backAccessibilityID)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .applyAccessibilityIdentifier(titleAccessibilityID)

            Spacer(minLength: 0)

            trailing()
        }
    }
}

extension PopoverHeaderBar where Trailing == EmptyView {
    init(
        title: String,
        titleAccessibilityID: String? = nil,
        backAccessibilityID: String? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            titleAccessibilityID: titleAccessibilityID,
            backAccessibilityID: backAccessibilityID,
            onBack: onBack
        ) {
            EmptyView()
        }
    }
}

private extension View {
    @ViewBuilder
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
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
