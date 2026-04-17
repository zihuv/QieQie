import XCTest
@testable import QieQie

final class FocusTimerEngineTests: XCTestCase {
    private let engine = FocusTimerEngine()
    private let autoStartConfiguration = FocusTimerConfiguration(
        autoStartBreak: true,
        autoStartNextFocus: true
    )

    func testStartCreatesRunningStateForCurrentPhase() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let idleState = engine.makeInitialState()

        let state = engine.start(idleState, now: now)

        XCTAssertEqual(state.currentPhase, .focus)
        XCTAssertEqual(state.phaseDuration, 25 * 60)
        XCTAssertEqual(state.endTime, now.addingTimeInterval(25 * 60))
        XCTAssertEqual(state.status(at: now), .running)
    }

    func testPauseRoundsRemainingTimeUpToWholeSecond() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let runningState = engine.start(engine.makeInitialState(), now: start)

        let pauseTime = start.addingTimeInterval(3.2)
        let pausedState = try XCTUnwrap(engine.pause(runningState, now: pauseTime))

        XCTAssertTrue(pausedState.isPaused)
        XCTAssertEqual(pausedState.pausedAt, pauseTime)
        XCTAssertEqual(pausedState.remainingTime(at: pauseTime), 1497)
    }

    func testResumeExtendsEndTimeByPauseDuration() throws {
        let pausedAt = Date(timeIntervalSinceReferenceDate: 100)
        let pausedState = FocusTimerState(
            configuration: .default,
            currentPhase: .focus,
            cycleFocusCount: 1,
            phaseDuration: 1500,
            endTime: pausedAt.addingTimeInterval(1200),
            isPaused: true,
            pausedAt: pausedAt
        )

        let resumeTime = pausedAt.addingTimeInterval(5)
        let result = try XCTUnwrap(engine.resume(pausedState, now: resumeTime))

        XCTAssertEqual(result.pauseDuration, 5)
        XCTAssertEqual(result.state.endTime, pausedAt.addingTimeInterval(1205))
        XCTAssertFalse(result.state.isPaused)
        XCTAssertNil(result.state.pausedAt)
    }

    func testAdvanceFromFocusMovesToShortBreakAndRecordsFocusDuration() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningFocus = FocusTimerState(
            configuration: autoStartConfiguration,
            currentPhase: .focus,
            cycleFocusCount: 1,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningFocus, now: now)

        XCTAssertEqual(result.completedFocusDuration, 1500)
        XCTAssertEqual(result.state.currentPhase, .shortBreak)
        XCTAssertEqual(result.state.cycleFocusCount, 2)
        XCTAssertEqual(result.state.phaseDuration, 5 * 60)
        XCTAssertEqual(result.state.status(at: now), .running)
    }

    func testAdvanceFromFocusLeavesBreakIdleWhenAutoBreakIsDisabled() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningFocus = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false),
            currentPhase: .focus,
            cycleFocusCount: 0,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningFocus, now: now)

        XCTAssertEqual(result.state.currentPhase, .shortBreak)
        XCTAssertEqual(result.state.status(at: now), .idle)
        XCTAssertEqual(result.state.phaseDuration, 5 * 60)
        XCTAssertNil(result.state.endTime)
    }

    func testAdvanceFromSkippedFocusMovesToShortBreakWithoutRecordingAndIncrementsCount() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningFocus = FocusTimerState(
            configuration: autoStartConfiguration,
            currentPhase: .focus,
            cycleFocusCount: 2,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningFocus, now: now, trigger: .skipped)

        XCTAssertNil(result.completedFocusDuration)
        XCTAssertEqual(result.state.currentPhase, .shortBreak)
        XCTAssertEqual(result.state.cycleFocusCount, 3)
        XCTAssertEqual(result.state.phaseDuration, 5 * 60)
        XCTAssertEqual(result.state.status(at: now), .running)
    }

    func testAdvanceFromSkippedFocusStartsBreakEvenWhenAutoBreakIsDisabled() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningFocus = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false),
            currentPhase: .focus,
            cycleFocusCount: 2,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningFocus, now: now, trigger: .skipped)

        XCTAssertNil(result.completedFocusDuration)
        XCTAssertEqual(result.state.currentPhase, .shortBreak)
        XCTAssertEqual(result.state.cycleFocusCount, 3)
        XCTAssertEqual(result.state.phaseDuration, 5 * 60)
        XCTAssertEqual(result.state.endTime, now.addingTimeInterval(5 * 60))
        XCTAssertEqual(result.state.status(at: now), .running)
    }

    func testAdvanceFromSkippedFocusEntersLongBreakAtCycleBoundary() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningFocus = FocusTimerState(
            configuration: autoStartConfiguration,
            currentPhase: .focus,
            cycleFocusCount: 3,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningFocus, now: now, trigger: .skipped)

        XCTAssertNil(result.completedFocusDuration)
        XCTAssertEqual(result.state.currentPhase, .longBreak)
        XCTAssertEqual(result.state.cycleFocusCount, 4)
        XCTAssertEqual(result.state.phaseDuration, 15 * 60)
        XCTAssertEqual(result.state.status(at: now), .running)
    }

    func testAdvanceToLongBreakAndResetAfterLongBreak() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let almostFinishedCycle = FocusTimerState(
            configuration: autoStartConfiguration,
            currentPhase: .focus,
            cycleFocusCount: 3,
            phaseDuration: 1500,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let longBreak = engine.advance(almostFinishedCycle, now: now)
        XCTAssertEqual(longBreak.state.currentPhase, .longBreak)
        XCTAssertEqual(longBreak.state.cycleFocusCount, 4)
        XCTAssertEqual(longBreak.state.phaseDuration, 15 * 60)

        let focusAfterLongBreak = engine.advance(longBreak.state, now: now)
        XCTAssertEqual(focusAfterLongBreak.completedFocusDuration, nil)
        XCTAssertEqual(focusAfterLongBreak.state.currentPhase, .focus)
        XCTAssertEqual(focusAfterLongBreak.state.cycleFocusCount, 0)
        XCTAssertEqual(focusAfterLongBreak.state.phaseDuration, 25 * 60)
    }

    func testAdvanceFromBreakLeavesNextFocusIdleWhenAutoNextFocusIsDisabled() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningBreak = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartNextFocus: false),
            currentPhase: .shortBreak,
            cycleFocusCount: 2,
            phaseDuration: 5 * 60,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningBreak, now: now)

        XCTAssertEqual(result.state.currentPhase, .focus)
        XCTAssertEqual(result.state.cycleFocusCount, 2)
        XCTAssertEqual(result.state.status(at: now), .idle)
        XCTAssertEqual(result.state.phaseDuration, 25 * 60)
        XCTAssertNil(result.state.endTime)
    }

    func testAdvanceFromSkippedBreakStartsNextFocusEvenWhenAutoNextFocusIsDisabled() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let runningBreak = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartNextFocus: false),
            currentPhase: .shortBreak,
            cycleFocusCount: 2,
            phaseDuration: 5 * 60,
            endTime: now,
            isPaused: false,
            pausedAt: nil
        )

        let result = engine.advance(runningBreak, now: now, trigger: .skipped)

        XCTAssertEqual(result.state.currentPhase, .focus)
        XCTAssertEqual(result.state.cycleFocusCount, 2)
        XCTAssertEqual(result.state.phaseDuration, 25 * 60)
        XCTAssertEqual(result.state.endTime, now.addingTimeInterval(25 * 60))
        XCTAssertEqual(result.state.status(at: now), .running)
    }

    func testApplyConfigurationUpdatesIdlePhaseDurationAndClampsInterval() {
        let idleState = engine.makeInitialState()
        let configuration = FocusTimerConfiguration(
            focusDuration: 30 * 60,
            shortBreakDuration: 3 * 60,
            longBreakDuration: 20 * 60,
            longBreakInterval: 99,
            autoStartBreak: false,
            autoStartNextFocus: false
        )

        let updatedState = engine.applyConfiguration(configuration, to: idleState)

        XCTAssertEqual(updatedState.configuration.focusDuration, 30 * 60)
        XCTAssertEqual(updatedState.configuration.longBreakInterval, 10)
        XCTAssertFalse(updatedState.configuration.autoStartBreak)
        XCTAssertFalse(updatedState.configuration.autoStartNextFocus)
        XCTAssertEqual(updatedState.phaseDuration, 30 * 60)
        XCTAssertEqual(updatedState.status, .idle)
    }
}
