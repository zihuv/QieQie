import Combine
import Foundation

/// 倒计时管理器
/// 核心职责：
/// 1. 维护倒计时状态（使用 endTime: Date 模型）
/// 2. 每秒触发状态更新
/// 3. 提供启动/重置倒计时的方法
@MainActor
final class FocusTimerManager: ObservableObject {
    /// 发布的倒计时状态
    @Published var state = FocusTimerState()

    /// 计时器
    private var timer: Timer?

    /// 专注历史记录管理器
    let focusHistoryManager: FocusHistoryManager?

    /// 当前进行中的会话
    private(set) var currentSession: FocusSession?

    /// 会话开始时间
    private var sessionStartTime: Date?

    /// 累计暂停时长，避免把暂停时间计入专注时长
    private var accumulatedPausedDuration: TimeInterval = 0

    init(focusHistoryManager: FocusHistoryManager? = nil) {
        self.focusHistoryManager = focusHistoryManager
    }

    // MARK: - 公开方法

    /// 开始倒计时
    /// - Parameters:
    ///   - duration: 倒计时时长（秒）
    ///   - taskName: 任务名称
    func startFocusTimer(duration: TimeInterval, taskName: String = "") {
        stopTimer()

        // 创建新的会话
        let startTime = Date()
        let effectiveTaskName = normalizedTaskName(taskName)
        sessionStartTime = startTime
        accumulatedPausedDuration = 0
        currentSession = focusHistoryManager?.createSession(taskName: effectiveTaskName, startTime: startTime)

        // 设置结束时间并重新赋值整个 state 对象以触发 @Published
        state = FocusTimerState(
            endTime: startTime.addingTimeInterval(duration),
            lastDuration: duration,
            isPaused: false,
            pausedAt: nil,
            taskName: effectiveTaskName
        )

        // 启动定时器
        startTimer()
    }

    /// 重置倒计时
    /// 将倒计时重置到空闲状态
    func resetFocusTimer() {
        finalizeCurrentSession(isCompleted: false, endedAt: Date())

        // 回到 idle 状态，清除所有计时信息
        stopTimer()
        state = state.idlePreservingInputs()
    }

    /// 暂停倒计时
    func pauseFocusTimer() {
        guard state.status == .running else { return }

        // 先停止定时器，防止竞态条件
        stopTimer()

        // 计算当前精确的剩余时间（向上取整到秒）
        guard let endTime = state.endTime else { return }
        let currentRemaining = ceil(endTime.timeIntervalSinceNow)
        let pausedAt = Date()

        // 创建新的结束时间点，使得暂停时的剩余时间是整数秒
        let newEndTime = pausedAt.addingTimeInterval(currentRemaining)

        // 记录当前时间点
        state = FocusTimerState(
            endTime: newEndTime,
            lastDuration: state.lastDuration,
            isPaused: true,
            pausedAt: pausedAt,
            taskName: state.taskName
        )
    }

    /// 继续倒计时
    func resumeFocusTimer() {
        guard state.status == .paused,
              let oldEndTime = state.endTime,
              let pausedAt = state.pausedAt else { return }

        // 计算暂停了多久
        let now = Date()
        let pauseDuration = now.timeIntervalSince(pausedAt)
        accumulatedPausedDuration += pauseDuration

        // 新的结束时间 = 原结束时间 + 暂停时长
        let newEndTime = oldEndTime.addingTimeInterval(pauseDuration)

        state = FocusTimerState(
            endTime: newEndTime,
            lastDuration: state.lastDuration,
            isPaused: false,
            pausedAt: nil,
            taskName: state.taskName
        )
        startTimer()
    }

    /// 切换暂停/继续状态
    func togglePause() {
        if state.status == .running {
            pauseFocusTimer()
        } else if state.status == .paused {
            resumeFocusTimer()
        }
    }

    // MARK: - 私有方法

    /// 启动 1 秒定时器
    private func startTimer() {
        stopTimer() // 先停止之前的定时器

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateState()
            }
        }
    }

    /// 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 更新状态
    /// 检查倒计时是否完成，如果完成则停止定时器
    private func updateState() {
        // 如果已暂停，不更新状态
        if state.isPaused {
            return
        }

        // 检查是否完成
        if let remaining = state.remainingTime, remaining <= 0 {
            finalizeCurrentSession(isCompleted: true, endedAt: Date())
            stopTimer()
        }

        state = state.refreshed()
    }

    private func finalizeCurrentSession(isCompleted: Bool, endedAt: Date) {
        guard let session = currentSession, let startTime = sessionStartTime else {
            clearCurrentSession()
            return
        }

        let inFlightPauseDuration: TimeInterval
        if state.isPaused, let pausedAt = state.pausedAt {
            inFlightPauseDuration = endedAt.timeIntervalSince(pausedAt)
        } else {
            inFlightPauseDuration = 0
        }

        let actualDuration = max(
            0,
            endedAt.timeIntervalSince(startTime) - accumulatedPausedDuration - inFlightPauseDuration
        )

        focusHistoryManager?.finishSession(
            session,
            endTime: endedAt,
            duration: actualDuration,
            isCompleted: isCompleted
        )
        clearCurrentSession()
    }

    private func clearCurrentSession() {
        currentSession = nil
        sessionStartTime = nil
        accumulatedPausedDuration = 0
    }

    private func normalizedTaskName(_ taskName: String) -> String {
        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "专注时间" : trimmed
    }
}
