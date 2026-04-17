import XCTest
import SwiftData
@testable import QieQie

@MainActor
final class FocusTimerManagerTests: XCTestCase {
    func testFreshManagerDefaultsAutoStartOptionsToDisabled() {
        let manager = FocusTimerManager(userDefaults: makeUserDefaults())

        XCTAssertFalse(manager.configuration.autoStartBreak)
        XCTAssertFalse(manager.configuration.autoStartNextFocus)
    }

    func testFreshManagerStartsWithoutBuiltInTags() {
        let manager = FocusTimerManager(userDefaults: makeUserDefaults())

        XCTAssertTrue(manager.availableTags.isEmpty)
        XCTAssertNil(manager.selectedTagName)
    }

    func testConfigurationPersistsAcrossManagerInstances() {
        let defaults = makeUserDefaults()
        let firstManager = FocusTimerManager(userDefaults: defaults)

        firstManager.updateConfiguration(
            FocusTimerConfiguration(
                focusDuration: 30 * 60,
                shortBreakDuration: 8 * 60,
                longBreakDuration: 18 * 60,
                longBreakInterval: 3,
                autoStartBreak: true,
                autoStartNextFocus: false
            )
        )

        let secondManager = FocusTimerManager(userDefaults: defaults)

        XCTAssertEqual(
            secondManager.configuration,
            FocusTimerConfiguration(
                focusDuration: 30 * 60,
                shortBreakDuration: 8 * 60,
                longBreakDuration: 18 * 60,
                longBreakInterval: 3,
                autoStartBreak: true,
                autoStartNextFocus: false
            )
        )
    }

    func testCurrentTaskNamePersistsAcrossManagerInstances() {
        let defaults = makeUserDefaults()
        let firstManager = FocusTimerManager(userDefaults: defaults)

        firstManager.updateCurrentTaskName("写周报")

        let secondManager = FocusTimerManager(userDefaults: defaults)

        XCTAssertEqual(secondManager.currentTaskName, "写周报")
    }

    func testSelectedTagPersistsAcrossManagerInstances() {
        let defaults = makeUserDefaults()
        let firstManager = FocusTimerManager(userDefaults: defaults)

        firstManager.updateSelectedTagName("开发")

        let secondManager = FocusTimerManager(userDefaults: defaults)

        XCTAssertEqual(secondManager.selectedTagName, "开发")
    }

    func testAddTagPersistsAcrossManagerInstances() {
        let defaults = makeUserDefaults()
        let firstManager = FocusTimerManager(userDefaults: defaults)

        firstManager.addTag("毕设")

        let secondManager = FocusTimerManager(userDefaults: defaults)

        XCTAssertTrue(secondManager.availableTags.contains("毕设"))
        XCTAssertEqual(secondManager.selectedTagName, "毕设")
    }

    func testRenameTagUpdatesSelectionAvailableTagsAndHistorySessions() throws {
        let defaults = makeUserDefaults()
        let historyManager = try makeHistoryManager()
        historyManager.recordCompletedFocus(
            duration: 25 * 60,
            tagName: "开发",
            note: "",
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        )
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            userDefaults: defaults
        )

        manager.updateSelectedTagName("开发")
        let renamed = manager.renameTag(from: "开发", to: "深度开发")

        XCTAssertTrue(renamed)
        XCTAssertEqual(manager.selectedTagName, "深度开发")
        XCTAssertTrue(manager.availableTags.contains("深度开发"))
        XCTAssertFalse(manager.availableTags.contains("开发"))

        let session = try XCTUnwrap(historyManager.getAllSessions().first)
        XCTAssertEqual(session.tagName, "深度开发")
        XCTAssertEqual(session.taskName, "深度开发")
        XCTAssertNil(session.displayNote)
    }

    func testRemoveTagClearsSelectionAvailableTagsAndHistorySessions() throws {
        let defaults = makeUserDefaults()
        let historyManager = try makeHistoryManager()
        historyManager.recordCompletedFocus(
            duration: 25 * 60,
            tagName: "开发",
            note: "",
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        )
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            userDefaults: defaults
        )

        manager.updateSelectedTagName("开发")
        let removed = manager.removeTag("开发")

        XCTAssertTrue(removed)
        XCTAssertNil(manager.selectedTagName)
        XCTAssertFalse(manager.availableTags.contains("开发"))

        let session = try XCTUnwrap(historyManager.getAllSessions().first)
        XCTAssertNil(session.tagName)
        XCTAssertEqual(session.displayTagName, "未分类")
        XCTAssertNil(session.displayNote)
    }

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

    func testRunLoopTickerSchedulerAddsTimerToCommonModes() throws {
        var capturedTimer: Timer?
        var capturedMode: RunLoop.Mode?
        let scheduler = RunLoopFocusTimerTickerScheduler { timer, mode in
            capturedTimer = timer
            capturedMode = mode
        }
        let expectation = expectation(description: "ticker fires")

        _ = scheduler.scheduleRepeating(interval: 1) {
            expectation.fulfill()
        }

        let timer = try XCTUnwrap(capturedTimer)
        XCTAssertEqual(timer.timeInterval, 1, accuracy: 0.001)
        XCTAssertEqual(capturedMode, .common)

        timer.fire()
        wait(for: [expectation], timeout: 1)
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
        manager.updateConfiguration(
            FocusTimerConfiguration(autoStartBreak: true, autoStartNextFocus: false)
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

    func testProcessTimerTickRecordsTagAndNoteCapturedWhenFocusStarts() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let historyManager = try makeHistoryManager()
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )

        manager.updateSelectedTagName("开发")
        manager.updateCurrentTaskName("设计评审")
        manager.startCurrentPhase()
        manager.updateSelectedTagName("会议")
        manager.updateCurrentTaskName("整理邮件")

        clock.currentDate = clock.currentDate.addingTimeInterval(25 * 60 + 1)
        manager.processTimerTick()

        let sessions = historyManager.getAllSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.taskName, "设计评审")
        XCTAssertEqual(sessions.first?.tagName, "开发")
        XCTAssertEqual(sessions.first?.note, "设计评审")
    }

    func testProcessTimerTickRecordsCompletedFocusWithTimeRange() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let historyManager = try makeHistoryManager()
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )

        manager.startCurrentPhase()

        clock.currentDate = clock.currentDate.addingTimeInterval(25 * 60 + 1)
        manager.processTimerTick()

        let session = try XCTUnwrap(historyManager.getAllSessions().first)
        XCTAssertEqual(session.duration, 25 * 60)
        XCTAssertEqual(session.endTime, clock.now())
        XCTAssertEqual(session.startTime, clock.now().addingTimeInterval(-(25 * 60)))
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
        XCTAssertEqual(manager.state.cycleFocusCount, 1)
        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(recordedDurations, [])
    }

    func testSkipCurrentFocusStartsBreakImmediatelyWhenAutoBreakIsDisabled() throws {
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
        let runningTask = try XCTUnwrap(scheduler.createdTasks.first)

        manager.skipCurrentPhase()

        XCTAssertEqual(runningTask.cancelCallCount, 1)
        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.cycleFocusCount, 1)
        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(manager.state.endTime, clock.now().addingTimeInterval(5 * 60))
        XCTAssertEqual(scheduler.scheduleCallCount, 2)
    }

    func testSkipCurrentFocusEntersLongBreakAtConfiguredBoundary() throws {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )
        manager.updateConfiguration(
            FocusTimerConfiguration(autoStartBreak: true, autoStartNextFocus: false)
        )

        manager.state = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: true, autoStartNextFocus: false),
            currentPhase: .focus,
            cycleFocusCount: 3,
            phaseDuration: 25 * 60,
            endTime: clock.now().addingTimeInterval(25 * 60),
            isPaused: false,
            pausedAt: nil
        )

        manager.skipCurrentPhase()

        XCTAssertEqual(manager.state.currentPhase, .longBreak)
        XCTAssertEqual(manager.state.cycleFocusCount, 4)
        XCTAssertEqual(manager.state.status(at: clock.now()), .running)
        XCTAssertEqual(manager.state.endTime, clock.now().addingTimeInterval(15 * 60))
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
    }

    func testSkipCurrentPhaseKeepsNextPhasesPausedWhenSkippingFromPausedState() {
        let clock = ManualClock(now: Date(timeIntervalSinceReferenceDate: 100))
        let scheduler = RecordingTickerScheduler()
        let manager = FocusTimerManager(
            clock: clock,
            tickerScheduler: scheduler,
            userDefaults: makeUserDefaults()
        )

        manager.state = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false, autoStartNextFocus: false),
            currentPhase: .focus,
            cycleFocusCount: 0,
            phaseDuration: 25 * 60,
            endTime: clock.now().addingTimeInterval(20 * 60),
            isPaused: true,
            pausedAt: clock.now()
        )

        manager.skipCurrentPhase()

        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.status(at: clock.now()), .paused)
        XCTAssertEqual(manager.state.remainingTime(at: clock.now()), 5 * 60)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)

        manager.skipCurrentPhase()

        XCTAssertEqual(manager.state.currentPhase, .focus)
        XCTAssertEqual(manager.state.status(at: clock.now()), .paused)
        XCTAssertEqual(manager.state.remainingTime(at: clock.now()), 25 * 60)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
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

    private func makeHistoryManager() throws -> FocusHistoryManager {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FocusSession.self, configurations: configuration)
        return FocusHistoryManager(modelContainer: container)
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
