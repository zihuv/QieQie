import SwiftUI

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
                            .font(FocusPanelTypography.headerBackIcon)
                        Text("返回")
                            .font(FocusPanelTypography.headerBackLabel)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .applyAccessibilityIdentifier(backAccessibilityID)
            }

            Text(title)
                .font(FocusPanelTypography.headerTitle)
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
