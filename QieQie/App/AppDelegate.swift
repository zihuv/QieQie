import AppKit
import OSLog
import SwiftUI
import SwiftData

/// 应用代理
/// 负责应用生命周期管理和初始化核心组件
class AppDelegate: NSObject, NSApplicationDelegate {
    /// 启动日志
    private let logger = Logger(subsystem: "com.zhangzefu.qieqie", category: "App")

    /// 倒计时管理器
    private var focusTimerManager: FocusTimerManager?

    /// 菜单栏管理器
    private var statusBarManager: StatusBarManager?

    /// SwiftData 模型容器
    var modelContainer: ModelContainer?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化 SwiftData 模型容器
        let focusHistoryManager: FocusHistoryManager?

        do {
            modelContainer = try ModelContainer(for: FocusSession.self, FocusTagRecord.self)
            focusHistoryManager = modelContainer.map(FocusHistoryManager.init(modelContainer:))
            focusHistoryManager?.migrateStorage(using: .standard)
        } catch {
            focusHistoryManager = nil
            logger.error("Failed to create ModelContainer: \(error.localizedDescription, privacy: .public)")
        }

        // 初始化倒计时管理器
        focusTimerManager = FocusTimerManager(focusHistoryManager: focusHistoryManager)

        // 初始化菜单栏管理器
        if let focusTimerManager = focusTimerManager {
            statusBarManager = StatusBarManager(focusTimerManager: focusTimerManager)
        }

        // 设置应用策略为辅助应用（无 Dock 图标）
        // 注意：还需要在 Info.plist 中设置 LSUIElement = true
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 不在窗口关闭时终止应用
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 不需要特殊处理
        return false
    }
}
