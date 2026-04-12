import SwiftUI

enum FocusTimerAccessibilityID {
    enum SettingsPopover {
        static let root = "settingsPopover.root"
        static let taskNameField = "settingsPopover.taskNameField"
        static let minutesField = "settingsPopover.minutesField"
        static let secondsField = "settingsPopover.secondsField"
        static let historyButton = "settingsPopover.historyButton"
        static let mainButton = "settingsPopover.mainButton"
        static let resetButton = "settingsPopover.resetButton"
        static let validationError = "settingsPopover.validationError"
    }

    enum StatusBar {
        static let button = "statusBar.button"
        static let popover = "statusBar.popover"
    }
}

/// 设置弹窗视图
struct SettingsPopover: View {
    private enum InputField: Hashable {
        case taskName
        case minutes
        case seconds
    }

    /// 倒计时管理器
    @ObservedObject var focusTimerManager: FocusTimerManager

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

    /// 设置面板统计数据快照，避免每次重绘都查询数据库
    @State private var dashboardStats = FocusStatistics()

    @State private var isStartingFocusTimer = false
    @FocusState private var focusedField: InputField?
    var body: some View {
        if showHistoryState, let historyManager = focusTimerManager.focusHistoryManager {
            HistoryView(historyManager: historyManager, showHistory: $showHistoryState)
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
        .frame(width: 280, height: 300)
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.root)
        .onAppear {
            syncFromState()
            refreshStatistics()
            restoreInputFocus(to: .minutes)
        }
        .onChange(of: focusTimerManager.state.status) { oldStatus, newStatus in
            isStartingFocusTimer = false
            syncFromState()
            refreshStatistics()
            restoreInputFocusIfNeeded(from: oldStatus, to: newStatus)
        }
        .onChange(of: showHistoryState) { _, isShowingHistory in
            if !isShowingHistory {
                refreshStatistics()
            }
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
                .focused($focusedField, equals: .taskName)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.taskNameField)
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
                    .disabled(isTimeInputLocked)
                    .focused($focusedField, equals: .minutes)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.minutesField)
                    .onChange(of: minutes) { _, newValue in
                        minutes = sanitizeNumericInput(newValue, maxLength: 3)
                    }

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
                    .disabled(isTimeInputLocked)
                    .focused($focusedField, equals: .seconds)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.secondsField)
                    .onChange(of: seconds) { _, newValue in
                        seconds = sanitizeNumericInput(newValue, maxLength: 2, upperBound: 59)
                    }
            }
            .opacity(isTimeInputLocked ? 0.5 : 1.0)

            // 错误提示
            if showError {
                Text("请输入有效时间")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.validationError)
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
            .disabled(focusTimerManager.focusHistoryManager == nil)
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.historyButton)
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
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.mainButton)

            // Reset 按钮
            Button(action: resetFocusTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!focusTimerManager.state.canReset)
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.resetButton)
        }
    }

    // MARK: - 计算属性

    /// 今日时长
    private var todayDuration: String {
        FocusStatistics.formatDuration(dashboardStats.todayTotal)
    }

    /// 本周时长
    private var weekDuration: String {
        FocusStatistics.formatDuration(dashboardStats.weekTotal)
    }

    private var isTimeInputLocked: Bool {
        isStartingFocusTimer || focusTimerManager.state.isEditingLocked
    }

    /// 主按钮标题
    private var mainButtonTitle: String {
        switch focusTimerManager.state.status {
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
        switch focusTimerManager.state.status {
        case .idle, .finished:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.circle.fill"
        }
    }

    // MARK: - 私有方法

    /// 开始倒计时
    private func startFocusTimer() {
        guard let duration = validatedDuration() else {
            showError = true
            return
        }

        isStartingFocusTimer = true
        focusedField = nil

        // 启动倒计时，传入任务名称
        focusTimerManager.startFocusTimer(duration: duration, taskName: taskName)

        // 清除错误提示
        showError = false
    }

    /// 主按钮动作
    private func mainButtonAction() {
        switch focusTimerManager.state.status {
        case .idle, .finished:
            // 开始新倒计时
            startFocusTimer()
        case .running:
            focusTimerManager.pauseFocusTimer()
        case .paused:
            resumeFocusTimer()
        }
    }

    /// 重置倒计时
    private func resetFocusTimer() {
        focusTimerManager.resetFocusTimer()
        syncFromState()
        refreshStatistics()
    }

    private func refreshStatistics() {
        dashboardStats = focusTimerManager.focusHistoryManager?.getDashboardStatistics() ?? FocusStatistics()
    }

    private func syncFromState() {
        showError = false

        if !focusTimerManager.state.taskName.isEmpty {
            taskName = focusTimerManager.state.taskName
        }

        if focusTimerManager.state.status == .paused,
           let remainingTime = focusTimerManager.state.remainingTime {
            setTimeFields(from: remainingTime)
        } else if let lastDuration = focusTimerManager.state.lastDuration {
            setTimeFields(from: lastDuration)
        }
    }

    private func resumeFocusTimer() {
        guard let duration = validatedDuration() else {
            showError = true
            return
        }

        focusTimerManager.updatePausedRemainingTime(duration: duration)
        focusTimerManager.resumeFocusTimer()
        showError = false
    }

    private func setTimeFields(from duration: TimeInterval) {
        let clampedDuration = max(0, Int(duration.rounded(.down)))
        let totalMinutes = clampedDuration / 60
        let remainingSeconds = clampedDuration % 60

        minutes = String(totalMinutes)
        seconds = String(format: "%02d", remainingSeconds)
    }

    private func sanitizeNumericInput(_ value: String, maxLength: Int, upperBound: Int? = nil) -> String {
        FocusTimerDurationParser.sanitizeNumericInput(value, maxLength: maxLength, upperBound: upperBound)
    }

    private func validatedDuration() -> TimeInterval? {
        FocusTimerDurationParser.parse(minutes: minutes, seconds: seconds)
    }

    private func restoreInputFocusIfNeeded(from oldStatus: FocusTimerStatus, to newStatus: FocusTimerStatus) {
        guard !showHistoryState,
              newStatus != .running,
              oldStatus == .running || oldStatus == .paused || oldStatus == .finished else { return }
        restoreInputFocus(to: .minutes)
    }

    private func restoreInputFocus(to field: InputField) {
        DispatchQueue.main.async {
            focusedField = field
        }
    }
}

/// 预览
struct SettingsPopover_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPopover(focusTimerManager: FocusTimerManager())
    }
}
