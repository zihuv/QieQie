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
final class StatusBarManager {
    private let finishedTitle = "Done"
    // NSStatusBarButton 自带左右留白，这里只补少量余量避免文字贴边。
    private let titlePadding: CGFloat = 0
    private let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    ]

    /// 状态栏项
    private var statusItem: NSStatusItem?

    /// Popover
    private var popover: NSPopover?

    /// 倒计时管理器
    private let focusTimerManager: FocusTimerManager

    /// Combine 订阅
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init(focusTimerManager: FocusTimerManager) {
        self.focusTimerManager = focusTimerManager
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
            showSettings()
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
                FocusDisplayFormatter.countdown(state.remainingTime ?? 0),
                to: button,
                statusItem: statusItem,
                state: state
            )
        case .finished:
            applyFixedWidthTitle(
                finishedTitle,
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
        setButtonTitle(title, on: button)
        statusItem.length = reservedTitleWidth(for: state)
    }

    private func setButtonTitle(_ title: String, on button: NSStatusBarButton) {
        button.title = title
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: titleAttributes
        )
    }

    private func clearButtonTitle(on button: NSStatusBarButton) {
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
    }

    private func reservedTitleWidth(for state: FocusTimerState) -> CGFloat {
        let widestTitle = [finishedTitle, countdownReferenceTitle(for: state)]
            .map(measuredWidth(for:))
            .max() ?? 0
        return widestTitle + titlePadding
    }

    // 用本次倒计时的初始展示文本作为宽度基准，避免剩余时间跨位数时抖动。
    private func countdownReferenceTitle(for state: FocusTimerState) -> String {
        guard let lastDuration = state.lastDuration else {
            return "00:00"
        }

        return FocusDisplayFormatter.countdown(lastDuration)
    }

    private func measuredWidth(for title: String) -> CGFloat {
        ceil(
            NSAttributedString(
                string: title,
                attributes: titleAttributes
            ).size().width
        )
    }

    private func restorePopoverFocusIfNeeded(for state: FocusTimerState) {
        guard state.status != .running,
              let popover,
              popover.isShown else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - 菜单操作

    /// 显示设置 Popover
    @objc private func showSettings() {
        // 如果 Popover 已经显示，关闭它
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
            return
        }

        // 创建新的 Popover
        let newPopover = NSPopover()
        newPopover.contentSize = NSSize(width: 320, height: 400)
        newPopover.behavior = .transient
        newPopover.contentViewController = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: focusTimerManager)
        )

        // 显示 Popover
        if let button = statusItem?.button {
            newPopover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )

            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                newPopover.contentViewController?.view.window?.makeKey()
            }
        }

        popover = newPopover
    }

    /// 退出应用
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
