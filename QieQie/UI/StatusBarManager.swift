import AppKit
import Combine
import SwiftUI

/// 菜单栏管理器
/// 核心职责：
/// 1. 创建和管理 NSStatusItem
/// 2. 更新菜单栏标题
/// 3. 处理菜单点击事件
/// 4. 显示设置 Popover
@MainActor
final class StatusBarManager: NSObject, NSPopoverDelegate {
    // NSStatusBarButton 自带左右留白，这里只补少量余量避免文字贴边。
    private let titlePadding: CGFloat = 0
    private let titleFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)

    /// 状态栏项
    private var statusItem: NSStatusItem?

    /// Popover
    private var popover: NSPopover?

    /// 统计窗口
    private var statisticsWindowController: StatisticsWindowController?

    /// 倒计时管理器
    private let focusTimerManager: FocusTimerManager

    /// Combine 订阅
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init(focusTimerManager: FocusTimerManager) {
        self.focusTimerManager = focusTimerManager
        super.init()
        setupStatusBar()
        observeStateChanges()
    }

    deinit {
        // 清理状态栏项
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    // MARK: - 设置

    /// 创建状态栏项
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 设置点击事件
        if let button = statusItem?.button {
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityIdentifier(FocusTimerAccessibilityID.StatusBar.button)
        }

        updateTitle()
    }

    /// 状态栏按钮点击事件
    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        // 右键点击显示菜单
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            // 左键点击显示 Popover
            toggleSettingsPopover()
        }
    }

    /// 显示右键菜单
    private func showMenu() {
        guard let statusItem = statusItem else { return }

        let menu = NSMenu()

        // Quit 菜单项
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // 临时显示菜单
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// 订阅状态变化
    private func observeStateChanges() {
        focusTimerManager.$state
            // `@Published` emits from `willSet`, so using the emitted state avoids
            // reading a stale pre-update value from `focusTimerManager.state`.
            .sink { [weak self] state in
                self?.updateTitle(for: state)
                self?.restorePopoverFocusIfNeeded(for: state)
            }
            .store(in: &cancellables)
    }

    // MARK: - 更新菜单栏标题

    /// 更新菜单栏标题
    private func updateTitle(for state: FocusTimerState? = nil) {
        guard let statusItem, let button = statusItem.button else { return }
        let state = state ?? focusTimerManager.state

        switch state.status {
        case .idle:
            applyIcon(
                NSImage(systemSymbolName: "clock", accessibilityDescription: "Idle"),
                to: button,
                statusItem: statusItem
            )
        case .running, .paused:
            applyFixedWidthTitle(
                FocusDisplayFormatter.countdown(state.remainingTime),
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
        button.title = title
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: titleAttributes(for: state)
        )
    }

    private func clearButtonTitle(on button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
    }

    private func reservedTitleWidth(for state: FocusTimerState) -> CGFloat {
        let widestTitle = measuredWidth(for: countdownReferenceTitle(for: state))
        return widestTitle + titlePadding
    }

    // 用本次倒计时的初始展示文本作为宽度基准，避免剩余时间跨位数时抖动。
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

    private func titleAttributes(for state: FocusTimerState) -> [NSAttributedString.Key: Any] {
        [
            .font: titleFont,
            .foregroundColor: Self.countdownColor(for: state.currentPhase)
        ]
    }

    static func countdownColor(for phase: FocusTimerPhase) -> NSColor {
        switch phase {
        case .focus:
            return .labelColor
        case .shortBreak, .longBreak:
            return .systemGreen
        }
    }

    private func restorePopoverFocusIfNeeded(for state: FocusTimerState) {
        guard state.status != .running, isSettingsPopoverShown else { return }

        focusSettingsPopoverIfNeeded()
    }

    // MARK: - 菜单操作

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

    /// 退出应用
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}

@MainActor
private final class StatisticsWindowController: NSWindowController {
    init(historyManager: FocusHistoryManager) {
        let hostingController = NSHostingController(
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
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.close()
    }
}
