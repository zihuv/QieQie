import Combine
import Foundation
import SwiftData

/// 倒计时管理器
/// 核心职责：
/// 1. 维护倒计时状态（使用 endTime: Date 模型）
/// 2. 每秒触发状态更新
/// 3. 提供启动/重置倒计时的方法
@MainActor
class CountdownManager: ObservableObject {
    /// 发布的倒计时状态
    @Published var state = CountdownState()

    /// 计时器
    private var timer: Timer?

    /// 模型容器（从 AppDelegate 传入）
    var modelContainer: ModelContainer?

    /// 专注历史记录管理器
    var focusHistoryManager: FocusHistoryManager?

    /// 当前进行中的会话
    private(set) var currentSession: FocusSession?

    /// 会话开始时间
    private var sessionStartTime: Date?

    // MARK: - 公开方法

    /// 初始化管理器
    func initialize(modelContainer: ModelContainer?) {
        self.modelContainer = modelContainer
        if let container = modelContainer {
            self.focusHistoryManager = FocusHistoryManager(modelContainer: container)
        }
    }

    /// 开始倒计时
    /// - Parameters:
    ///   - duration: 倒计时时长（秒）
    ///   - taskName: 任务名称
    func startCountdown(duration: TimeInterval, taskName: String = "") {
        // 创建新的会话
        let effectiveTaskName = taskName.isEmpty ? "专注时间" : taskName
        sessionStartTime = Date()
        currentSession = focusHistoryManager?.createSession(taskName: effectiveTaskName)

        // 设置结束时间并重新赋值整个 state 对象以触发 @Published
        state = CountdownState(
            endTime: Date().addingTimeInterval(duration),
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
    func resetCountdown() {
        // 保存未完成的会话
        if let session = currentSession, let startTime = sessionStartTime {
            let actualDuration = Date().timeIntervalSince(startTime)
            focusHistoryManager?.finishSession(session, duration: actualDuration, isCompleted: false)
        }

        // 回到 idle 状态，清除所有计时信息
        currentSession = nil
        sessionStartTime = nil
        state = CountdownState()
        stopTimer()
    }

    /// 暂停倒计时
    func pauseCountdown() {
        guard state.status == .running else { return }

        // 先停止定时器，防止竞态条件
        stopTimer()

        // 计算当前精确的剩余时间（向上取整到秒）
        guard let endTime = state.endTime else { return }
        let currentRemaining = ceil(endTime.timeIntervalSinceNow)

        // 创建新的结束时间点，使得暂停时的剩余时间是整数秒
        let newEndTime = Date().addingTimeInterval(currentRemaining)

        // 记录当前时间点
        state = CountdownState(
            endTime: newEndTime,
            lastDuration: state.lastDuration,
            isPaused: true,
            pausedAt: Date(),
            taskName: state.taskName
        )
    }

    /// 继续倒计时
    func resumeCountdown() {
        guard state.status == .paused,
              let oldEndTime = state.endTime,
              let pausedAt = state.pausedAt else { return }

        // 计算暂停了多久
        let pauseDuration = Date().timeIntervalSince(pausedAt)

        // 新的结束时间 = 原结束时间 + 暂停时长
        let newEndTime = oldEndTime.addingTimeInterval(pauseDuration)

        state = CountdownState(
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
            pauseCountdown()
        } else if state.status == .paused {
            resumeCountdown()
        }
    }

    // MARK: - 私有方法

    /// 启动 1 秒定时器
    private func startTimer() {
        stopTimer() // 先停止之前的定时器

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateState()
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
            // 保存完成的会话
            if let session = currentSession, let startTime = sessionStartTime {
                let actualDuration = Date().timeIntervalSince(startTime)
                focusHistoryManager?.finishSession(session, duration: actualDuration, isCompleted: true)
            }
            currentSession = nil
            sessionStartTime = nil
            stopTimer()
        }

        // 重新赋值 state 以触发 @Published 更新
        // 必须保留所有字段，否则会丢失状态信息
        state = CountdownState(
            endTime: state.endTime,
            lastDuration: state.lastDuration,
            isPaused: state.isPaused,
            pausedAt: state.pausedAt,
            taskName: state.taskName
        )
    }
}
