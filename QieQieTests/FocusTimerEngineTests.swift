import XCTest
@testable import QieQie

final class FocusTimerEngineTests: XCTestCase {
    private let engine = FocusTimerEngine()

    func testStartCreatesRunningStateAtProvidedTime() {
        let now = Date(timeIntervalSinceReferenceDate: 100)

        let state = engine.start(duration: 300, taskName: "Write", now: now)

        XCTAssertEqual(state.taskName, "Write")
        XCTAssertEqual(state.lastDuration, 300)
        XCTAssertEqual(state.endTime, now.addingTimeInterval(300))
        XCTAssertEqual(state.status(at: now.addingTimeInterval(1)), .running)
    }

    func testPauseRoundsRemainingTimeUpToWholeSecond() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let runningState = engine.start(duration: 10, taskName: "Write", now: start)

        let pauseTime = start.addingTimeInterval(3.2)
        let pausedState = try XCTUnwrap(engine.pause(runningState, now: pauseTime))

        XCTAssertTrue(pausedState.isPaused)
        XCTAssertEqual(pausedState.pausedAt, pauseTime)
        XCTAssertEqual(pausedState.remainingTime(at: pauseTime), 7)
    }

    func testResumeExtendsEndTimeByPauseDuration() throws {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let pausedAt = start.addingTimeInterval(3)
        let pausedState = FocusTimerState(
            endTime: pausedAt.addingTimeInterval(7),
            lastDuration: 10,
            isPaused: true,
            pausedAt: pausedAt,
            taskName: "Write"
        )

        let resumeTime = pausedAt.addingTimeInterval(5)
        let result = try XCTUnwrap(engine.resume(pausedState, now: resumeTime))

        XCTAssertEqual(result.pauseDuration, 5)
        XCTAssertEqual(result.state.endTime, pausedAt.addingTimeInterval(12))
        XCTAssertFalse(result.state.isPaused)
        XCTAssertNil(result.state.pausedAt)
    }

    func testUpdatePausedRemainingTimeReplacesRemainingTimeAndLastDuration() throws {
        let pausedAt = Date(timeIntervalSinceReferenceDate: 100)
        let pausedState = FocusTimerState(
            endTime: pausedAt.addingTimeInterval(20),
            lastDuration: 20,
            isPaused: true,
            pausedAt: pausedAt,
            taskName: "Write"
        )

        let updatedState = try XCTUnwrap(engine.updatePausedRemainingTime(pausedState, duration: 95.8))

        XCTAssertEqual(updatedState.endTime, pausedAt.addingTimeInterval(95))
        XCTAssertEqual(updatedState.lastDuration, 95)
        XCTAssertEqual(updatedState.remainingTime(at: pausedAt), 95)
    }

    func testActualDurationExcludesAccumulatedAndInFlightPauseTime() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        let pausedAt = startedAt.addingTimeInterval(40)
        let pausedState = FocusTimerState(
            endTime: pausedAt.addingTimeInterval(20),
            lastDuration: 60,
            isPaused: true,
            pausedAt: pausedAt,
            taskName: "Write"
        )

        let actualDuration = engine.actualDuration(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(50),
            accumulatedPausedDuration: 5,
            state: pausedState
        )

        XCTAssertEqual(actualDuration, 35)
    }

    func testStatusAndRemainingTimeUseInjectedNow() {
        let now = Date(timeIntervalSinceReferenceDate: 100)
        let state = FocusTimerState(
            endTime: now.addingTimeInterval(10),
            lastDuration: 10,
            isPaused: false,
            pausedAt: nil,
            taskName: "Write"
        )

        XCTAssertEqual(state.status(at: now.addingTimeInterval(5)), .running)
        XCTAssertEqual(state.status(at: now.addingTimeInterval(11)), .finished)
        XCTAssertEqual(state.remainingTime(at: now.addingTimeInterval(5)), 5)
        XCTAssertEqual(state.remainingTime(at: now.addingTimeInterval(11)), 0)
    }
}
