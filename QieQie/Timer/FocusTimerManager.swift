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

@MainActor
final class FocusTimerManager: ObservableObject {
    @Published var state: FocusTimerState

    private enum StorageKey {
        static let focusDuration = "focusTimer.configuration.focusDuration"
        static let shortBreakDuration = "focusTimer.configuration.shortBreakDuration"
        static let longBreakDuration = "focusTimer.configuration.longBreakDuration"
        static let longBreakInterval = "focusTimer.configuration.longBreakInterval"
        static let autoStartBreak = "focusTimer.configuration.autoStartBreak"
        static let autoStartNextFocus = "focusTimer.configuration.autoStartNextFocus"
        static let autoAdvance = "focusTimer.configuration.autoAdvance"
    }

    private let engine = FocusTimerEngine()
    private let clock: FocusTimerClock
    private let tickerScheduler: FocusTimerTickerScheduling
    private let userDefaults: UserDefaults
    private let focusCompletionRecorder: ((TimeInterval, Date) -> Void)?

    private var tickerTask: FocusTimerScheduledTask?

    let focusHistoryManager: FocusHistoryManager?

    init(
        focusHistoryManager: FocusHistoryManager? = nil,
        clock: FocusTimerClock = SystemFocusTimerClock(),
        tickerScheduler: FocusTimerTickerScheduling = RunLoopFocusTimerTickerScheduler(),
        userDefaults: UserDefaults = .standard,
        focusCompletionRecorder: ((TimeInterval, Date) -> Void)? = nil
    ) {
        let initialConfiguration = Self.loadConfiguration(from: userDefaults)
        self.focusHistoryManager = focusHistoryManager
        self.clock = clock
        self.tickerScheduler = tickerScheduler
        self.userDefaults = userDefaults
        self.focusCompletionRecorder = focusCompletionRecorder
        self.state = FocusTimerEngine().makeInitialState(configuration: initialConfiguration)
    }

    var configuration: FocusTimerConfiguration {
        state.configuration
    }

    func updateConfiguration(_ configuration: FocusTimerConfiguration) {
        let normalized = configuration.normalized()
        persist(configuration: normalized)
        publishState(engine.applyConfiguration(normalized, to: state))
    }

    func startCurrentPhase() {
        guard state.status(at: clock.now()) == .idle else { return }

        stopTimer()
        publishState(engine.start(state, now: clock.now()))
        startTimer()
    }

    func resetCurrentPhase() {
        stopTimer()
        publishState(engine.reset(state))
    }

    func pauseCurrentPhase() {
        stopTimer()
        guard let pausedState = engine.pause(state, now: clock.now()) else { return }
        publishState(pausedState)
    }

    func resumeCurrentPhase() {
        guard let resumeResult = engine.resume(state, now: clock.now()) else { return }
        publishState(resumeResult.state)
        startTimer()
    }

    func togglePause() {
        let currentStatus = state.status(at: clock.now())
        if currentStatus == .running {
            pauseCurrentPhase()
        } else if currentStatus == .paused {
            resumeCurrentPhase()
        }
    }

    func skipCurrentPhase() {
        stopTimer()
        transitionToNextPhase(at: clock.now(), trigger: .skipped)
    }

    func processTimerTick() {
        updateState(now: clock.now())
    }

    private func startTimer() {
        stopTimer()

        tickerTask = tickerScheduler.scheduleRepeating(interval: 1.0) { [weak self] in
            self?.processTimerTick()
        }
    }

    private func stopTimer() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func updateState(now: Date) {
        if state.isPaused || state.status(at: now) == .idle {
            return
        }

        if engine.shouldAdvance(state, now: now) {
            stopTimer()
            transitionToNextPhase(at: now, trigger: .completed)
            return
        }

        publishState(state.refreshed())
    }

    private func transitionToNextPhase(
        at date: Date,
        trigger: FocusTimerAdvanceTrigger
    ) {
        let result = engine.advance(state, now: date, trigger: trigger)
        if let duration = result.completedFocusDuration {
            focusHistoryManager?.recordCompletedFocus(duration: duration, completedAt: date)
            focusCompletionRecorder?(duration, date)
        }

        publishState(result.state)

        if result.state.status(at: date) == .running {
            startTimer()
        }
    }

    private func publishState(_ newState: FocusTimerState) {
        state = newState
        objectWillChange.send()
    }

    private func persist(configuration: FocusTimerConfiguration) {
        userDefaults.set(configuration.focusDuration, forKey: StorageKey.focusDuration)
        userDefaults.set(configuration.shortBreakDuration, forKey: StorageKey.shortBreakDuration)
        userDefaults.set(configuration.longBreakDuration, forKey: StorageKey.longBreakDuration)
        userDefaults.set(configuration.longBreakInterval, forKey: StorageKey.longBreakInterval)
        userDefaults.set(configuration.autoStartBreak, forKey: StorageKey.autoStartBreak)
        userDefaults.set(configuration.autoStartNextFocus, forKey: StorageKey.autoStartNextFocus)
        userDefaults.removeObject(forKey: StorageKey.autoAdvance)
    }

    private static func loadConfiguration(from userDefaults: UserDefaults) -> FocusTimerConfiguration {
        let defaults = FocusTimerConfiguration.default
        let focusDuration = userDefaults.object(forKey: StorageKey.focusDuration) as? Double ?? defaults.focusDuration
        let shortBreakDuration = userDefaults.object(forKey: StorageKey.shortBreakDuration) as? Double ?? defaults.shortBreakDuration
        let longBreakDuration = userDefaults.object(forKey: StorageKey.longBreakDuration) as? Double ?? defaults.longBreakDuration
        let longBreakInterval = userDefaults.object(forKey: StorageKey.longBreakInterval) as? Int ?? defaults.longBreakInterval
        let legacyAutoAdvance = userDefaults.object(forKey: StorageKey.autoAdvance) as? Bool
        let autoStartBreak = userDefaults.object(forKey: StorageKey.autoStartBreak) as? Bool
            ?? legacyAutoAdvance
            ?? defaults.autoStartBreak
        let autoStartNextFocus = userDefaults.object(forKey: StorageKey.autoStartNextFocus) as? Bool
            ?? legacyAutoAdvance
            ?? defaults.autoStartNextFocus

        return FocusTimerConfiguration(
            focusDuration: focusDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            longBreakInterval: longBreakInterval,
            autoStartBreak: autoStartBreak,
            autoStartNextFocus: autoStartNextFocus
        ).normalized()
    }
}
