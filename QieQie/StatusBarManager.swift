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
            title: "退出 QieQie",
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
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    // MARK: - 更新菜单栏标题

    /// 更新菜单栏标题
    private func updateTitle() {
        guard let button = statusItem?.button else { return }

        switch focusTimerManager.state.status {
        case .idle:
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Idle")
            button.title = ""
        case .running, .paused:
            button.image = nil
            button.title = FocusDisplayFormatter.countdown(focusTimerManager.state.remainingTime ?? 0)
        case .finished:
            button.image = nil
            button.title = "Done"
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
        }

        popover = newPopover
    }

    /// 退出应用
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
