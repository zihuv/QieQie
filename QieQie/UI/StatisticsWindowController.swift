import AppKit
import SwiftUI

@MainActor
final class StatisticsWindowController: NSWindowController {
    private let historyManager: FocusHistoryManager
    private var hostingController: NSHostingController<HistoryView>

    init(historyManager: FocusHistoryManager) {
        self.historyManager = historyManager
        self.hostingController = NSHostingController(
            rootView: HistoryView(historyManager: historyManager)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: StatisticsWindowLayout.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "统计"
        window.contentViewController = hostingController
        window.minSize = StatisticsWindowLayout.minSize
        window.setContentSize(StatisticsWindowLayout.defaultSize)
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isShown: Bool {
        window?.isVisible == true
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let refreshedController = NSHostingController(
            rootView: HistoryView(historyManager: historyManager)
        )
        hostingController = refreshedController
        window?.contentViewController = refreshedController
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.close()
    }
}
