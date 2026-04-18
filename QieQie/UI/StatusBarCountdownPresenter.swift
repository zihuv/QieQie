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
            if state.currentPhase == .focus {
                applyIcon(
                    NSImage(systemSymbolName: "clock", accessibilityDescription: "Idle"),
                    to: button,
                    statusItem: statusItem
                )
            } else {
                applyRenderedCountdownImage(
                    FocusDisplayFormatter.countdown(state.phaseDuration),
                    to: button,
                    statusItem: statusItem,
                    state: state
                )
            }
        case .running, .paused:
            let title = FocusDisplayFormatter.countdown(state.remainingTime)
            if state.currentPhase == .focus {
                applyFixedWidthTitle(
                    title,
                    to: button,
                    statusItem: statusItem,
                    state: state
                )
            } else {
                applyRenderedCountdownImage(
                    title,
                    to: button,
                    statusItem: statusItem,
                    state: state
                )
            }
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

    private func applyRenderedCountdownImage(
        _ title: String,
        to button: NSStatusBarButton,
        statusItem: NSStatusItem,
        state: FocusTimerState
    ) {
        let image = makeCountdownImage(
            title: title,
            color: StatusBarCountdownStyle.countdownTintColor(for: state.currentPhase) ?? .labelColor
        )
        button.title = title
        button.attributedTitle = NSAttributedString(string: "")
        button.image = image
        button.image?.isTemplate = false
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        statusItem.length = reservedTitleWidth(for: state)
    }

    private func setButtonTitle(_ title: String, on button: NSStatusBarButton, state: FocusTimerState) {
        let textColor = StatusBarCountdownStyle.countdownTintColor(for: state.currentPhase)
        var attributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        if let textColor {
            attributes[.foregroundColor] = textColor
        }
        button.title = title
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: attributes
        )
        button.contentTintColor = textColor
    }

    private func makeCountdownImage(title: String, color: NSColor) -> NSImage {
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: titleFont,
                .foregroundColor: color
            ]
        )
        let size = attributedTitle.size()
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixelWidth = max(1, Int(ceil(size.width * scale)))
        let pixelHeight = max(1, Int(ceil(size.height * scale)))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let rep else {
            return NSImage(size: size)
        }

        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        attributedTitle.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private func clearButtonTitle(on button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.contentTintColor = nil
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
