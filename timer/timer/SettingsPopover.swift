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

    /// 任务名称输入
    @State private var taskName: String = ""

    /// 输入错误提示
    @State private var showError: Bool = false

    /// 是否显示历史记录
    @State private var showHistoryState: Bool = false

    var body: some View {
        if showHistoryState {
            HistoryView(countdownManager: countdownManager, showHistory: $showHistoryState)
        } else {
            mainContent
        }
    }

    /// 主内容视图
    private var mainContent: some View {
        VStack(spacing: 12) {
            // 任务名称输入
            taskNameSection

            // 时间输入区域
            timeInputSection

            // 统计信息
            statisticsSection

            Spacer()

            // 控制按钮区域
            controlButtonsSection
        }
        .padding(20)
        .frame(width: 260, height: 280)
        .onAppear {
            // 重置错误状态
            showError = false
            // 同步当前任务名称
            taskName = countdownManager.state.taskName
        }
    }

    /// 任务名称输入区域
    private var taskNameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("任务名称")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("输入任务名称", text: $taskName)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
    }

    /// 时间输入区域
    private var timeInputSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("25", text: $minutes)
                    .textFieldStyle(.plain)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .disabled(countdownManager.state.status == .running || countdownManager.state.status == .paused)

                Text(":")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("00", text: $seconds)
                    .textFieldStyle(.plain)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .disabled(countdownManager.state.status == .running || countdownManager.state.status == .paused)
            }
            .opacity(countdownManager.state.status == .running || countdownManager.state.status == .paused ? 0.5 : 1.0)

            // 错误提示
            if showError {
                Text("请输入有效时间")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    /// 统计信息区域
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(todayDuration)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            HStack {
                Text("本周:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(weekDuration)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Button(action: { showHistoryState = true }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("查看历史记录")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }

    /// 控制按钮区域
    private var controlButtonsSection: some View {
        HStack(spacing: 10) {
            // Start/Pause/Resume 按钮
            Button(action: mainButtonAction) {
                HStack(spacing: 4) {
                    Image(systemName: mainButtonIcon)
                    Text(mainButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Reset 按钮
            Button(action: resetCountdown) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(countdownManager.state.status == .idle)
        }
    }

    // MARK: - 计算属性

    /// 今日时长
    private var todayDuration: String {
        guard let manager = countdownManager.focusHistoryManager else { return "0分钟" }
        let stats = manager.getTodayStatistics()
        return FocusStatistics.formatDuration(stats.todayTotal)
    }

    /// 本周时长
    private var weekDuration: String {
        guard let manager = countdownManager.focusHistoryManager else { return "0分钟" }
        let stats = manager.getWeekStatistics()
        return FocusStatistics.formatDuration(stats.weekTotal)
    }

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

        // 启动倒计时，传入任务名称
        countdownManager.startCountdown(duration: duration, taskName: taskName)

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
