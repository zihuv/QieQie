import AppKit
import Combine
import SwiftUI

/// 菜单栏管理器
/// 核心职责：
/// 1. 创建和管理 NSStatusItem
/// 2. 响应菜单栏点击
/// 3. 显示设置 Popover
/// 4. 协调统计窗口
@MainActor
final class StatusBarManager: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var statisticsWindowController: StatisticsWindowController?

    private let focusTimerManager: FocusTimerManager
    private let countdownPresenter = StatusBarCountdownPresenter()
    private var cancellables = Set<AnyCancellable>()

    init(focusTimerManager: FocusTimerManager) {
        self.focusTimerManager = focusTimerManager
        super.init()
        setupStatusBar()
        observeStateChanges()
    }

    deinit {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityIdentifier(FocusTimerAccessibilityID.StatusBar.button)
        }

        updateTitle()
    }

    @objc
    private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleSettingsPopover()
        }
    }

    private func showMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func observeStateChanges() {
        focusTimerManager.$state
            .sink { [weak self] state in
                self?.updateTitle(for: state)
                self?.restorePopoverFocusIfNeeded(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateTitle(for state: FocusTimerState? = nil) {
        guard let statusItem, let button = statusItem.button else { return }
        countdownPresenter.update(
            button: button,
            statusItem: statusItem,
            state: state ?? focusTimerManager.state
        )
    }

    static func countdownTintColor(for phase: FocusTimerPhase) -> NSColor? {
        StatusBarCountdownStyle.countdownTintColor(for: phase)
    }

    private func restorePopoverFocusIfNeeded(for state: FocusTimerState) {
        guard state.status != .running, isSettingsPopoverShown else { return }
        focusSettingsPopoverIfNeeded()
    }

    var isSettingsPopoverShown: Bool {
        popover?.isShown == true
    }

    var isStatisticsWindowShown: Bool {
        statisticsWindowController?.isShown == true
    }

    func toggleSettingsPopover() {
        if isSettingsPopoverShown {
            hideSettingsPopover()
        } else {
            showSettingsPopover()
        }
    }

    func showSettingsPopover() {
        guard let button = statusItem?.button else { return }

        let popover = self.popover ?? makeSettingsPopover()
        if popover.isShown {
            focusSettingsPopoverIfNeeded()
            return
        }

        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )

        self.popover = popover
        focusSettingsPopoverIfNeeded()
    }

    func hideSettingsPopover() {
        guard let popover else { return }
        popover.performClose(nil)
        self.popover = nil
    }

    func showStatisticsWindow() {
        guard let historyManager = focusTimerManager.focusHistoryManager else { return }

        hideSettingsPopover()

        let controller: StatisticsWindowController
        if let statisticsWindowController {
            controller = statisticsWindowController
        } else {
            controller = StatisticsWindowController(historyManager: historyManager)
            statisticsWindowController = controller
        }

        controller.showWindow()
    }

    func closeStatisticsWindow() {
        statisticsWindowController?.closeWindow()
    }

    func focusSettingsPopoverIfNeeded() {
        guard let popover, popover.isShown else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.setAccessibilityIdentifier(FocusTimerAccessibilityID.StatusBar.popover)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func makeSettingsPopover() -> NSPopover {
        let newPopover = NSPopover()
        newPopover.contentSize = SettingsPopoverLayout.mainSize
        newPopover.behavior = .transient
        newPopover.delegate = self
        newPopover.contentViewController = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: focusTimerManager,
                onPreferredSizeChange: { [weak newPopover] size in
                    guard let newPopover, newPopover.contentSize != size else { return }
                    newPopover.contentSize = size
                },
                onOpenStatistics: { [weak self] in
                    self?.showStatisticsWindow()
                }
            )
        )
        return newPopover
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}
