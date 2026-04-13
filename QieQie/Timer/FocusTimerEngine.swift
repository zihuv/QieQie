import Foundation

struct FocusTimerResumeResult {
    let state: FocusTimerState
    let pauseDuration: TimeInterval
}

struct FocusTimerAdvanceResult {
    let state: FocusTimerState
    let completedFocusDuration: TimeInterval?
}

enum FocusTimerAdvanceTrigger {
    case completed
    case skipped
}

struct FocusTimerEngine {
    func makeInitialState(configuration: FocusTimerConfiguration = .default) -> FocusTimerState {
        makePhaseState(
            phase: .focus,
            cycleFocusCount: 0,
            configuration: configuration.normalized(),
            shouldAutoStart: false,
            now: Date()
        )
    }

    func applyConfiguration(_ configuration: FocusTimerConfiguration, to state: FocusTimerState) -> FocusTimerState {
        let normalized = configuration.normalized()
        let clampedCycleFocusCount = min(state.cycleFocusCount, normalized.longBreakInterval)
        let phaseDuration: TimeInterval

        if state.status == .idle {
            phaseDuration = normalized.duration(for: state.currentPhase)
        } else {
            phaseDuration = state.phaseDuration
        }

        return FocusTimerState(
            configuration: normalized,
            currentPhase: state.currentPhase,
            cycleFocusCount: clampedCycleFocusCount,
            phaseDuration: phaseDuration,
            endTime: state.endTime,
            isPaused: state.isPaused,
            pausedAt: state.pausedAt
        )
    }

    func start(_ state: FocusTimerState, now: Date) -> FocusTimerState {
        FocusTimerState(
            configuration: state.configuration,
            currentPhase: state.currentPhase,
            cycleFocusCount: state.cycleFocusCount,
            phaseDuration: state.phaseDuration,
            endTime: now.addingTimeInterval(state.phaseDuration),
            isPaused: false,
            pausedAt: nil
        )
    }

    func reset(_ state: FocusTimerState) -> FocusTimerState {
        makePhaseState(
            phase: state.currentPhase,
            cycleFocusCount: state.cycleFocusCount,
            configuration: state.configuration,
            shouldAutoStart: false,
            now: Date()
        )
    }

    func pause(_ state: FocusTimerState, now: Date) -> FocusTimerState? {
        guard state.status(at: now) == .running, let endTime = state.endTime else {
            return nil
        }

        let currentRemaining = max(0, ceil(endTime.timeIntervalSince(now)))

        return FocusTimerState(
            configuration: state.configuration,
            currentPhase: state.currentPhase,
            cycleFocusCount: state.cycleFocusCount,
            phaseDuration: state.phaseDuration,
            endTime: now.addingTimeInterval(currentRemaining),
            isPaused: true,
            pausedAt: now
        )
    }

    func resume(_ state: FocusTimerState, now: Date) -> FocusTimerResumeResult? {
        guard state.status(at: now) == .paused,
              let pausedAt = state.pausedAt,
              let endTime = state.endTime else {
            return nil
        }

        let pauseDuration = max(0, now.timeIntervalSince(pausedAt))
        let resumedState = FocusTimerState(
            configuration: state.configuration,
            currentPhase: state.currentPhase,
            cycleFocusCount: state.cycleFocusCount,
            phaseDuration: state.phaseDuration,
            endTime: endTime.addingTimeInterval(pauseDuration),
            isPaused: false,
            pausedAt: nil
        )

        return FocusTimerResumeResult(state: resumedState, pauseDuration: pauseDuration)
    }

    func shouldAdvance(_ state: FocusTimerState, now: Date) -> Bool {
        state.status(at: now) == .running && state.remainingTime(at: now) <= 0
    }

    func advance(
        _ state: FocusTimerState,
        now: Date,
        trigger: FocusTimerAdvanceTrigger = .completed
    ) -> FocusTimerAdvanceResult {
        switch state.currentPhase {
        case .focus:
            let nextFocusCount: Int
            let nextPhase: FocusTimerPhase

            if trigger == .completed {
                nextFocusCount = min(state.cycleFocusCount + 1, state.configuration.longBreakInterval)
                if nextFocusCount >= state.configuration.longBreakInterval {
                    nextPhase = .longBreak
                } else {
                    nextPhase = .shortBreak
                }
            } else {
                nextFocusCount = state.cycleFocusCount
                nextPhase = .shortBreak
            }

            return FocusTimerAdvanceResult(
                state: makePhaseState(
                    phase: nextPhase,
                    cycleFocusCount: nextFocusCount,
                    configuration: state.configuration,
                    shouldAutoStart: state.configuration.shouldAutoStartNextPhase(after: .focus),
                    now: now
                ),
                completedFocusDuration: trigger == .completed ? state.phaseDuration : nil
            )
        case .shortBreak:
            return FocusTimerAdvanceResult(
                state: makePhaseState(
                    phase: .focus,
                    cycleFocusCount: state.cycleFocusCount,
                    configuration: state.configuration,
                    shouldAutoStart: state.configuration.shouldAutoStartNextPhase(after: .shortBreak),
                    now: now
                ),
                completedFocusDuration: nil
            )
        case .longBreak:
            return FocusTimerAdvanceResult(
                state: makePhaseState(
                    phase: .focus,
                    cycleFocusCount: 0,
                    configuration: state.configuration,
                    shouldAutoStart: state.configuration.shouldAutoStartNextPhase(after: .longBreak),
                    now: now
                ),
                completedFocusDuration: nil
            )
        }
    }

    private func makePhaseState(
        phase: FocusTimerPhase,
        cycleFocusCount: Int,
        configuration: FocusTimerConfiguration,
        shouldAutoStart: Bool,
        now: Date
    ) -> FocusTimerState {
        let duration = configuration.duration(for: phase)
        return FocusTimerState(
            configuration: configuration,
            currentPhase: phase,
            cycleFocusCount: cycleFocusCount,
            phaseDuration: duration,
            endTime: shouldAutoStart ? now.addingTimeInterval(duration) : nil,
            isPaused: false,
            pausedAt: nil
        )
    }
}
