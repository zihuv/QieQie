import AppKit

enum StatusBarCountdownStyle {
    static func countdownTintColor(for phase: FocusTimerPhase) -> NSColor? {
        switch phase {
        case .focus:
            return nil
        case .shortBreak, .longBreak:
            return .systemGreen
        }
    }

    static func highlightedCountdownTintColor(for phase: FocusTimerPhase) -> NSColor? {
        switch phase {
        case .focus:
            return nil
        case .shortBreak, .longBreak:
            return .selectedMenuItemTextColor
        }
    }
}

final class StatusBarCountdownPresenter {
    // NSStatusBarButton 自带左右留白，这里只补少量余量避免文字贴边。
    private let titlePadding: CGFloat = 0
    private let titleFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize,
        weight: .medium
    )

    func update(
        button: NSStatusBarButton,
        statusItem: NSStatusItem,
        state: FocusTimerState
    ) {
        switch state.status {
        case .idle:
            if shouldShowIdleClockIcon(for: state) {
                applyIcon(
                    NSImage(systemSymbolName: "clock", accessibilityDescription: "Idle"),
                    to: button,
                    statusItem: statusItem
                )
            } else {
                applyFixedWidthTitle(
                    FocusDisplayFormatter.countdown(state.phaseDuration),
                    to: button,
                    statusItem: statusItem,
                    state: state
                )
            }
        case .running, .paused:
            let title = FocusDisplayFormatter.countdown(state.remainingTime)
            applyFixedWidthTitle(
                title,
                to: button,
                statusItem: statusItem,
                state: state
            )
        }
    }

    private func applyIcon(
        _ image: NSImage?,
        to button: NSStatusBarButton,
        statusItem: NSStatusItem
    ) {
        clearButtonTitle(on: button)
        button.contentTintColor = nil
        button.image = image
        button.imagePosition = .imageOnly
        statusItem.length = NSStatusItem.variableLength
    }

    private func applyFixedWidthTitle(
        _ title: String,
        to button: NSStatusBarButton,
        statusItem: NSStatusItem,
        state: FocusTimerState
    ) {
        button.image = nil
        button.imagePosition = .noImage
        setButtonTitle(title, on: button, state: state)
        statusItem.length = reservedTitleWidth(for: state)
    }

    private func setButtonTitle(_ title: String, on button: NSStatusBarButton, state: FocusTimerState) {
        let textColor = StatusBarCountdownStyle.countdownTintColor(for: state.currentPhase)
        button.title = title
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: titleAttributes(foregroundColor: textColor)
        )
        button.attributedAlternateTitle = NSAttributedString(
            string: title,
            attributes: titleAttributes(
                foregroundColor: StatusBarCountdownStyle.highlightedCountdownTintColor(for: state.currentPhase)
            )
        )
        button.contentTintColor = nil
    }

    private func clearButtonTitle(on button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.attributedAlternateTitle = NSAttributedString(string: "")
        button.contentTintColor = nil
    }

    private func titleAttributes(foregroundColor: NSColor?) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        if let foregroundColor {
            attributes[.foregroundColor] = foregroundColor
        }
        return attributes
    }

    private func shouldShowIdleClockIcon(for state: FocusTimerState) -> Bool {
        state.currentPhase == .focus && state.cycleFocusCount == 0
    }

    private func reservedTitleWidth(for state: FocusTimerState) -> CGFloat {
        let widestTitle = measuredWidth(for: countdownReferenceTitle(for: state))
        return widestTitle + titlePadding
    }

    private func countdownReferenceTitle(for state: FocusTimerState) -> String {
        FocusDisplayFormatter.countdown(state.phaseDuration)
    }

    private func measuredWidth(for title: String) -> CGFloat {
        ceil(
            NSAttributedString(
                string: title,
                attributes: [.font: titleFont]
            ).size().width
        )
    }
}
