import XCTest
@testable import QieQie

@MainActor
final class FocusTimerManagerTests: XCTestCase {
    func testStartUsesInjectedClockAndSchedulesRepeatingTick() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)

        manager.startFocusTimer(duration: 30, taskName: "Write")

        XCTAssertEqual(manager.state.endTime, clock.now().addingTimeInterval(30))
        XCTAssertEqual(manager.state.lastDuration, 30)
        XCTAssertEqual(manager.state.taskName, "Write")
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
        XCTAssertEqual(scheduler.lastInterval, 1)
    }

    func testStartPublishesUpdatedRunningStateToObjectWillChangeObservers() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)
        var observedStatuses: [FocusTimerStatus] = []

        let cancellable = manager.objectWillChange.sink {
            observedStatuses.append(manager.state.status(at: clock.now()))
        }

        manager.startFocusTimer(duration: 30, taskName: "Write")

        XCTAssertEqual(observedStatuses, [.idle, .running])
        withExtendedLifetime(cancellable) {}
    }

    func testProcessTimerTickUsesInjectedClockToFinishTimer() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)

        manager.startFocusTimer(duration: 5, taskName: "Write")
        let task = try XCTUnwrap(scheduler.createdTasks.first)

        clock.currentDate = clock.currentDate.addingTimeInterval(6)
        manager.processTimerTick()

        XCTAssertEqual(manager.state.status(at: clock.now()), .finished)
        XCTAssertEqual(task.cancelCallCount, 1)
    }

    func testScheduledHandlerCanDriveTickWithoutRealTimer() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)

        manager.startFocusTimer(duration: 5, taskName: "Write")
        let task = try XCTUnwrap(scheduler.createdTasks.first)

        clock.currentDate = clock.currentDate.addingTimeInterval(6)
        scheduler.fireLatest()

        XCTAssertEqual(manager.state.status(at: clock.now()), .finished)
        XCTAssertEqual(task.cancelCallCount, 1)
    }

    func testTogglePauseUsesInjectedClockForPauseAndResume() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(clock: clock, tickerScheduler: scheduler)

        manager.startFocusTimer(duration: 10, taskName: "Write")
        let firstTask = try XCTUnwrap(scheduler.createdTasks.first)

        clock.currentDate = clock.currentDate.addingTimeInterval(3)
        manager.togglePause()

        XCTAssertTrue(manager.state.isPaused)
        XCTAssertEqual(manager.state.remainingTime(at: clock.now()), 7)
        XCTAssertEqual(firstTask.cancelCallCount, 1)

        clock.currentDate = clock.currentDate.addingTimeInterval(5)
        manager.togglePause()

        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(manager.state.endTime, Date(timeIntervalSinceReferenceDate: 115))
        XCTAssertEqual(scheduler.scheduleCallCount, 2)
    }
}

private final class ManualClock: FocusTimerClock {
    var currentDate: Date

    init(now: Date) {
        self.currentDate = now
    }

    func now() -> Date {
        currentDate
    }
}

private final class RecordingScheduledTask: FocusTimerScheduledTask {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

private final class RecordingTickerScheduler: FocusTimerTickerScheduling {
    private(set) var scheduleCallCount = 0
    private(set) var lastInterval: TimeInterval?
    private(set) var createdTasks: [RecordingScheduledTask] = []
    private var latestHandler: (@MainActor () -> Void)?

    func scheduleRepeating(
        interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FocusTimerScheduledTask {
        scheduleCallCount += 1
        lastInterval = interval
        latestHandler = handler

        let task = RecordingScheduledTask()
        createdTasks.append(task)
        return task
    }

    @MainActor
    func fireLatest() {
        latestHandler?()
    }
}
