import XCTest
@testable import QieQie

@MainActor
final class FocusTimerManagerTests: XCTestCase {
    func testStartUsesInjectedClockAndSchedulesRepeatingTick() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )

        manager.startCurrentPhase()

        XCTAssertEqual(manager.state.currentPhase, .focus)
        XCTAssertEqual(manager.state.endTime, clock.now().addingTimeInterval(25 * 60))
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
        XCTAssertEqual(scheduler.lastInterval, 1)
    }

    func testStartPublishesUpdatedRunningStateToObjectWillChangeObservers() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )
        var observedStatuses: [FocusTimerStatus] = []

        let cancellable = manager.objectWillChange.sink {
            observedStatuses.append(manager.state.status(at: clock.now()))
        }

        manager.startCurrentPhase()

        XCTAssertEqual(observedStatuses, [.idle, .running])
        withExtendedLifetime(cancellable) {}
    }

    func testProcessTimerTickAdvancesToBreakAndRecordsCompletedFocus() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        var recordedDurations: [TimeInterval] = []
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults(),
            focusCompletionRecorder: { duration, _ in
                recordedDurations.append(duration)
            }
        )

        manager.startCurrentPhase()
        let task = try XCTUnwrap(scheduler.createdTasks.first)

        clock.currentDate = clock.currentDate.addingTimeInterval(25 * 60 + 1)
        manager.processTimerTick()

        XCTAssertEqual(task.cancelCallCount, 1)
        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.cycleFocusCount, 1)
        XCTAssertEqual(manager.state.phaseDuration, 5 * 60)
        XCTAssertEqual(recordedDurations, [TimeInterval(25 * 60)])
    }

    func testProcessTimerTickLeavesBreakIdleWhenAutoBreakIsDisabled() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let defaults = makeUserDefaults()
        defaults.set(false, forKey: "focusTimer.configuration.autoStartBreak")
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: defaults
        )

        manager.startCurrentPhase()
        clock.currentDate = clock.currentDate.addingTimeInterval(25 * 60 + 1)
        manager.processTimerTick()

        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.status(at: clock.now()), .idle)
        XCTAssertNil(manager.state.endTime)
    }

    func testSkipCurrentFocusAdvancesWithoutWaitingForTimerBoundary() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        var recordedDurations: [TimeInterval] = []
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults(),
            focusCompletionRecorder: { duration, _ in
                recordedDurations.append(duration)
            }
        )

        manager.startCurrentPhase()
        let runningTask = try XCTUnwrap(scheduler.createdTasks.first)

        manager.skipCurrentPhase()

        XCTAssertEqual(runningTask.cancelCallCount, 1)
        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.cycleFocusCount, 0)
        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(recordedDurations, [])
    }

    func testTogglePauseUsesInjectedClockForPauseAndResume() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )

        manager.startCurrentPhase()
        let firstTask = try XCTUnwrap(scheduler.createdTasks.first)

        clock.currentDate = clock.currentDate.addingTimeInterval(3)
        manager.togglePause()

        XCTAssertTrue(manager.state.isPaused)
        XCTAssertEqual(manager.state.remainingTime(at: clock.now()), 1497)
        XCTAssertEqual(firstTask.cancelCallCount, 1)

        clock.currentDate = clock.currentDate.addingTimeInterval(5)
        manager.togglePause()

        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(manager.state.endTime, Date(timeIntervalSinceReferenceDate: 1605))
        XCTAssertEqual(scheduler.scheduleCallCount, 2)
    }

    func testLegacyAutoAdvanceMigratesToBothAutoStartSettings() {
        let defaults = makeUserDefaults()
        defaults.set(false, forKey: "focusTimer.configuration.autoAdvance")

        let manager = FocusTimerManager(userDefaults: defaults)

        XCTAssertFalse(manager.configuration.autoStartBreak)
        XCTAssertFalse(manager.configuration.autoStartNextFocus)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
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
