import Combine
import Foundation

protocol FocusTimerClock {
    func now() -> Date
}

struct SystemFocusTimerClock: FocusTimerClock {
    func now() -> Date {
        Date()
    }
}

protocol FocusTimerScheduledTask: AnyObject {
    func cancel()
}

protocol FocusTimerTickerScheduling {
    func scheduleRepeating(
        interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FocusTimerScheduledTask
}

private final class FoundationFocusTimerScheduledTask: FocusTimerScheduledTask {
    private var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

struct RunLoopFocusTimerTickerScheduler: FocusTimerTickerScheduling {
    func scheduleRepeating(
        interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FocusTimerScheduledTask {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }

        return FoundationFocusTimerScheduledTask(timer: timer)
    }
}

/// 倒计时管理器
/// 核心职责：
/// 1. 维护倒计时状态（使用 endTime: Date 模型）
/// 2. 每秒触发状态更新
/// 3. 提供启动/重置倒计时的方法
@MainActor
final class FocusTimerManager: ObservableObject {
    /// 发布的倒计时状态
    @Published var state = FocusTimerState()

    private let engine = FocusTimerEngine()
    private let clock: FocusTimerClock
    private let tickerScheduler: FocusTimerTickerScheduling

    /// 重复 tick 任务
    private var tickerTask: FocusTimerScheduledTask?

    /// 专注历史记录管理器
    let focusHistoryManager: FocusHistoryManager?

    /// 当前进行中的会话
    private(set) var currentSession: FocusSession?

    /// 会话开始时间
    private var sessionStartTime: Date?

    /// 累计暂停时长，避免把暂停时间计入专注时长
    private var accumulatedPausedDuration: TimeInterval = 0

    init(
        focusHistoryManager: FocusHistoryManager? = nil,
        clock: FocusTimerClock = SystemFocusTimerClock(),
        tickerScheduler: FocusTimerTickerScheduling = RunLoopFocusTimerTickerScheduler()
    ) {
        self.focusHistoryManager = focusHistoryManager
        self.clock = clock
        self.tickerScheduler = tickerScheduler
    }

    // MARK: - 公开方法

    /// 开始倒计时
    /// - Parameters:
    ///   - duration: 倒计时时长（秒）
    ///   - taskName: 任务名称
    func startFocusTimer(duration: TimeInterval, taskName: String = "") {
        stopTimer()

        // 创建新的会话
        let now = clock.now()
        let effectiveTaskName = normalizedTaskName(taskName)
        sessionStartTime = now
        accumulatedPausedDuration = 0
        currentSession = focusHistoryManager?.createSession(taskName: effectiveTaskName, startTime: now)

        state = engine.start(duration: duration, taskName: effectiveTaskName, now: now)

        // 启动定时器
        startTimer()
    }

    /// 重置倒计时
    /// 将倒计时重置到空闲状态
    func resetFocusTimer() {
        finalizeCurrentSession(isCompleted: false, endedAt: clock.now())

        // 回到 idle 状态，清除所有计时信息
        stopTimer()
        state = engine.reset(state)
    }

    /// 暂停倒计时
    func pauseFocusTimer() {
        // 先停止定时器，防止竞态条件
        stopTimer()
        guard let pausedState = engine.pause(state, now: clock.now()) else { return }
        state = pausedState
    }

    /// 继续倒计时
    func resumeFocusTimer() {
        guard let resumeResult = engine.resume(state, now: clock.now()) else { return }
        accumulatedPausedDuration += resumeResult.pauseDuration
        state = resumeResult.state
        startTimer()
    }

    /// 切换暂停/继续状态
    func togglePause() {
        let currentStatus = state.status(at: clock.now())
        if currentStatus == .running {
            pauseFocusTimer()
        } else if currentStatus == .paused {
            resumeFocusTimer()
        }
    }

    /// 在暂停状态下更新剩余时间，供用户调整后继续计时
    func updatePausedRemainingTime(duration: TimeInterval) {
        guard let updatedState = engine.updatePausedRemainingTime(state, duration: duration) else { return }
        state = updatedState
    }

    /// 处理一次定时 tick，供测试或 focused harness 显式驱动状态刷新。
    func processTimerTick() {
        updateState(now: clock.now())
    }

    // MARK: - 私有方法

    /// 启动 1 秒定时器
    private func startTimer() {
        stopTimer() // 先停止之前的定时器

        tickerTask = tickerScheduler.scheduleRepeating(interval: 1.0) { [weak self] in
            self?.processTimerTick()
        }
    }

    /// 停止定时器
    private func stopTimer() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    /// 更新状态
    /// 检查倒计时是否完成，如果完成则停止定时器
    private func updateState(now: Date) {
        // 如果已暂停，不更新状态
        if state.isPaused {
            return
        }

        // 检查是否完成
        if engine.shouldFinish(state, now: now) {
            finalizeCurrentSession(isCompleted: true, endedAt: now)
            stopTimer()
        }

        state = state.refreshed()
    }

    private func finalizeCurrentSession(isCompleted: Bool, endedAt: Date) {
        guard let session = currentSession, let startTime = sessionStartTime else {
            clearCurrentSession()
            return
        }

        let actualDuration = engine.actualDuration(
            startedAt: startTime,
            endedAt: endedAt,
            accumulatedPausedDuration: accumulatedPausedDuration,
            state: state
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
