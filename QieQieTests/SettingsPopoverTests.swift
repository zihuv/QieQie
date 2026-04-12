import AppKit
import SwiftUI
import XCTest
@testable import QieQie

@MainActor
final class SettingsPopoverTests: XCTestCase {
    func testPausedTimerKeepsInitialDurationVisibleAndFieldsDisabled() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)
        let host = NSHostingController(rootView: SettingsPopover(focusTimerManager: manager))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        manager.startFocusTimer(duration: 25 * 60, taskName: "Write")
        pumpMainRunLoop()

        clock.currentDate = clock.currentDate.addingTimeInterval(7)
        manager.pauseFocusTimer()
        pumpMainRunLoop()

        XCTAssertEqual(manager.state.remainingTime(at: clock.now()), 25 * 60 - 7)

        let minutesField = try XCTUnwrap(
            findTextField(in: host.view, placeholder: "25")
        )
        let secondsField = try XCTUnwrap(
            findTextField(in: host.view, placeholder: "00")
        )

        XCTAssertFalse(minutesField.isEnabled)
        XCTAssertFalse(secondsField.isEnabled)
        XCTAssertEqual(minutesField.stringValue, "25")
        XCTAssertEqual(secondsField.stringValue, "00")

        window.orderOut(nil)
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private func findTextField(in view: NSView, placeholder: String) -> NSTextField? {
        findTextFields(in: view).first { $0.placeholderString == placeholder }
    }

    private func findTextFields(in view: NSView) -> [NSTextField] {
        var matches: [NSTextField] = []
        if let textField = view as? NSTextField {
            matches.append(textField)
        }

        for subview in view.subviews {
            matches.append(contentsOf: findTextFields(in: subview))
        }

        return matches
    }
}

private final class ManualClock: FocusTimerClock {
    var currentDate: Date

    init(now: Date) {
        self.currentDate = now
    }

    func now() -> Date {
        currentDate
    }
}

private final class RecordingScheduledTask: FocusTimerScheduledTask {
    func cancel() {}
}

private final class RecordingTickerScheduler: FocusTimerTickerScheduling {
    func scheduleRepeating(
        interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FocusTimerScheduledTask {
        RecordingScheduledTask()
    }
}
