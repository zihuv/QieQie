import Foundation

struct FocusTimerResumeResult {
    let state: FocusTimerState
    let pauseDuration: TimeInterval
}

/// 纯逻辑计时引擎，负责状态迁移和时间计算。
struct FocusTimerEngine {
    func start(duration: TimeInterval, taskName: String, now: Date) -> FocusTimerState {
        FocusTimerState(
            endTime: now.addingTimeInterval(duration),
            lastDuration: duration,
            isPaused: false,
            pausedAt: nil,
            taskName: taskName
        )
    }

    func reset(_ state: FocusTimerState) -> FocusTimerState {
        state.idlePreservingInputs()
    }

    func pause(_ state: FocusTimerState, now: Date) -> FocusTimerState? {
        guard state.status(at: now) == .running, let endTime = state.endTime else { return nil }

        let currentRemaining = max(0, ceil(endTime.timeIntervalSince(now)))

        return FocusTimerState(
            endTime: now.addingTimeInterval(currentRemaining),
            lastDuration: state.lastDuration,
            isPaused: true,
            pausedAt: now,
            taskName: state.taskName
        )
    }

    func resume(_ state: FocusTimerState, now: Date) -> FocusTimerResumeResult? {
        guard state.status(at: now) == .paused,
              let oldEndTime = state.endTime,
              let pausedAt = state.pausedAt else { return nil }

        let pauseDuration = max(0, now.timeIntervalSince(pausedAt))
        let resumedState = FocusTimerState(
            endTime: oldEndTime.addingTimeInterval(pauseDuration),
            lastDuration: state.lastDuration,
            isPaused: false,
            pausedAt: nil,
            taskName: state.taskName
        )

        return FocusTimerResumeResult(state: resumedState, pauseDuration: pauseDuration)
    }

    func updatePausedRemainingTime(_ state: FocusTimerState, duration: TimeInterval) -> FocusTimerState? {
        guard state.isPaused, let pausedAt = state.pausedAt else { return nil }

        let adjustedDuration = max(1, duration.rounded(.down))
        return FocusTimerState(
            endTime: pausedAt.addingTimeInterval(adjustedDuration),
            lastDuration: adjustedDuration,
            isPaused: true,
            pausedAt: pausedAt,
            taskName: state.taskName
        )
    }

    func shouldFinish(_ state: FocusTimerState, now: Date) -> Bool {
        guard let remaining = state.remainingTime(at: now) else { return false }
        return remaining <= 0
    }

    func actualDuration(
        startedAt: Date,
        endedAt: Date,
        accumulatedPausedDuration: TimeInterval,
        state: FocusTimerState
    ) -> TimeInterval {
        let inFlightPauseDuration: TimeInterval
        if state.isPaused, let pausedAt = state.pausedAt {
            inFlightPauseDuration = endedAt.timeIntervalSince(pausedAt)
        } else {
            inFlightPauseDuration = 0
        }

        return max(
            0,
            endedAt.timeIntervalSince(startedAt) - accumulatedPausedDuration - inFlightPauseDuration
        )
    }
}
