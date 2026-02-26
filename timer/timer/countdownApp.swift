import SwiftUI
import SwiftData

/// 应用入口
@main
struct countdownApp: App {
    /// 应用代理
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用空的 Settings 场景来防止默认窗口创建
        // 这对于菜单栏应用很重要
        Settings {
            EmptyView()
        }
    }
}
