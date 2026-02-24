import SwiftUI

/// 设置弹窗视图
struct SettingsPopover: View {
    /// 倒计时管理器
    @ObservedObject var countdownManager: CountdownManager

    /// 表示模式（用于关闭 Popover）
    @Environment(\.presentationMode) var presentationMode

    /// 分钟输入
    @State private var minutes: String = "25"

    /// 秒数输入
    @State private var seconds: String = "00"

    /// 输入错误提示
    @State private var showError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 时间输入区域（常驻显示）
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    TextField("25", text: $minutes)
                        .textFieldStyle(.plain)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .disabled(countdownManager.state.status == .running || countdownManager.state.status == .paused)

                    Text(":")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("00", text: $seconds)
                        .textFieldStyle(.plain)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .disabled(countdownManager.state.status == .running || countdownManager.state.status == .paused)
                }
                .opacity(countdownManager.state.status == .running || countdownManager.state.status == .paused ? 0.5 : 1.0)

                // 错误提示
                if showError {
                    Text("Please enter valid time")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)

            Spacer()

            // 控制按钮区域（常驻显示）
            HStack(spacing: 10) {
                // Start/Pause/Resume 按钮（左侧）
                Button(action: mainButtonAction) {
                    HStack(spacing: 6) {
                        Image(systemName: mainButtonIcon)
                        Text(mainButtonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Reset 按钮（右侧）
                Button(action: resetCountdown) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(countdownManager.state.status == .idle)
            }
        }
        .padding(24)
        .frame(width: 260, height: 180)
        .onAppear {
            // 重置错误状态
            showError = false
        }
    }

    // MARK: - 计算属性

    /// 主按钮标题
    private var mainButtonTitle: String {
        switch countdownManager.state.status {
        case .idle:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Start"
        }
    }

    /// 主按钮图标
    private var mainButtonIcon: String {
        switch countdownManager.state.status {
        case .idle, .finished:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.circle.fill"
        }
    }

    /// 显示的时间文本
    private var displayTime: String {
        switch countdownManager.state.status {
        case .idle:
            return "--:--"
        case .running, .paused:
            if let remaining = countdownManager.state.remainingTime {
                return formatTime(remaining)
            }
            return "--:--"
        case .finished:
            return "Done!"
        }
    }

    // MARK: - 私有方法

    /// 格式化时间
    private func formatTime(_ interval: TimeInterval) -> String {
        let time = Int(interval)
        let hours = time / 3600
        let minutes = (time % 3600) / 60
        let seconds = time % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// 开始倒计时
    private func startCountdown() {
        // 解析输入
        guard let min = Int(minutes),
              let sec = Int(seconds),
              min >= 0,
              sec >= 0,
              min * 60 + sec > 0 else {
            showError = true
            return
        }

        let duration = TimeInterval(min * 60 + sec)

        // 启动倒计时
        countdownManager.startCountdown(duration: duration)

        // 清除错误提示
        showError = false
    }

    /// 主按钮动作
    private func mainButtonAction() {
        switch countdownManager.state.status {
        case .idle, .finished:
            // 开始新倒计时
            startCountdown()
        case .running:
            // 暂停倒计时
            countdownManager.pauseCountdown()
        case .paused:
            // 恢复倒计时
            countdownManager.resumeCountdown()
        }
    }

    /// 重置倒计时
    private func resetCountdown() {
        countdownManager.resetCountdown()
    }
}

/// 预览
struct SettingsPopover_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPopover(countdownManager: CountdownManager())
    }
}
