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
    private let addTimer: (Timer, RunLoop.Mode) -> Void

    init(runLoop: RunLoop = .main) {
        self.addTimer = { timer, mode in
            runLoop.add(timer, forMode: mode)
        }
    }

    init(addTimer: @escaping (Timer, RunLoop.Mode) -> Void) {
        self.addTimer = addTimer
    }

    func scheduleRepeating(
        interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FocusTimerScheduledTask {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }
        addTimer(timer, .common)

        return FoundationFocusTimerScheduledTask(timer: timer)
    }
}

@MainActor
final class FocusTimerManager: ObservableObject {
    @Published var state: FocusTimerState
    @Published var currentTaskName: String
    @Published var selectedTagName: String?
    @Published private(set) var availableTags: [String]

    private enum StorageKey {
        static let focusDuration = "focusTimer.configuration.focusDuration"
        static let shortBreakDuration = "focusTimer.configuration.shortBreakDuration"
        static let longBreakDuration = "focusTimer.configuration.longBreakDuration"
        static let longBreakInterval = "focusTimer.configuration.longBreakInterval"
        static let autoStartBreak = "focusTimer.configuration.autoStartBreak"
        static let autoStartNextFocus = "focusTimer.configuration.autoStartNextFocus"
        static let autoAdvance = "focusTimer.configuration.autoAdvance"
        static let currentTaskName = "focusTimer.currentTaskName"
        static let selectedTagName = "focusTimer.selectedTagName"
        static let availableTags = "focusTimer.availableTags"
    }

    private struct ActiveFocusMetadata {
        let tagName: String?
        let note: String
    }

    private let engine = FocusTimerEngine()
    private let clock: FocusTimerClock
    private let tickerScheduler: FocusTimerTickerScheduling
    private let userDefaults: UserDefaults
    private let focusCompletionRecorder: ((TimeInterval, Date) -> Void)?

    private var tickerTask: FocusTimerScheduledTask?
    private var activeFocusMetadata: ActiveFocusMetadata?

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
        self.currentTaskName = Self.loadCurrentTaskName(from: userDefaults)
        let loadedTags = Self.loadAvailableTags(from: userDefaults)
        let loadedSelectedTagName = Self.loadSelectedTagName(from: userDefaults)
        self.availableTags = FocusTagCatalog.normalizedTags(from: loadedTags + (loadedSelectedTagName.map { [$0] } ?? []))
        self.selectedTagName = loadedSelectedTagName
    }

    var configuration: FocusTimerConfiguration {
        state.configuration
    }

    func updateConfiguration(_ configuration: FocusTimerConfiguration) {
        let normalized = configuration.normalized()
        persist(configuration: normalized)
        publishState(engine.applyConfiguration(normalized, to: state))
    }

    func updateCurrentTaskName(_ taskName: String) {
        let normalized = Self.normalizeTaskNameInput(taskName)
        guard normalized != currentTaskName else { return }

        currentTaskName = normalized
        persist(currentTaskName: normalized)
    }

    func updateSelectedTagName(_ tagName: String?) {
        let normalized = FocusTagCatalog.normalizeTagName(tagName)

        if let normalized, !availableTags.contains(normalized) {
            availableTags.append(normalized)
            persist(availableTags: availableTags)
        }

        guard normalized != selectedTagName else { return }

        selectedTagName = normalized
        persist(selectedTagName: normalized)
    }

    @discardableResult
    func addTag(_ tagName: String) -> String? {
        guard let normalized = FocusTagCatalog.normalizeTagName(tagName) else {
            return nil
        }

        if !availableTags.contains(normalized) {
            availableTags.append(normalized)
            persist(availableTags: availableTags)
        }

        updateSelectedTagName(normalized)
        return normalized
    }

    @discardableResult
    func removeTag(_ tagName: String) -> Bool {
        guard let normalized = FocusTagCatalog.normalizeTagName(tagName) else { return false }

        if focusHistoryManager?.deleteTag(named: normalized) == false {
            return false
        }

        let updatedTags = availableTags.filter { $0 != normalized }
        guard updatedTags != availableTags else { return true }

        availableTags = updatedTags
        persist(availableTags: updatedTags)

        if selectedTagName == normalized {
            selectedTagName = nil
            persist(selectedTagName: nil)
        }

        return true
    }

    @discardableResult
    func renameTag(from oldName: String, to newName: String) -> Bool {
        guard
            let normalizedOldName = FocusTagCatalog.normalizeTagName(oldName),
            let normalizedNewName = FocusTagCatalog.normalizeTagName(newName),
            normalizedOldName != normalizedNewName
        else {
            return false
        }

        if focusHistoryManager?.renameTag(from: normalizedOldName, to: normalizedNewName) == false {
            return false
        }

        var updatedTags = availableTags.map { $0 == normalizedOldName ? normalizedNewName : $0 }
        updatedTags = FocusTagCatalog.normalizedTags(from: updatedTags)
        availableTags = updatedTags
        persist(availableTags: updatedTags)

        if selectedTagName == normalizedOldName {
            selectedTagName = normalizedNewName
            persist(selectedTagName: normalizedNewName)
        }

        return true
    }

    func startCurrentPhase() {
        guard state.status(at: clock.now()) == .idle else { return }

        if state.currentPhase == .focus {
            activeFocusMetadata = ActiveFocusMetadata(
                tagName: FocusTagCatalog.normalizeTagName(selectedTagName),
                note: recordedNote
            )
        }

        stopTimer()
        publishState(engine.start(state, now: clock.now()))
        startTimer()
    }

    func resetCurrentPhase() {
        stopTimer()
        activeFocusMetadata = nil
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
        let shouldPreservePause = trigger == .skipped && state.isPaused
        let result = engine.advance(state, now: date, trigger: trigger)
        let nextState = preservedPauseStateIfNeeded(
            from: result.state,
            at: date,
            shouldPreservePause: shouldPreservePause
        )
        if let duration = result.completedFocusDuration {
            focusHistoryManager?.recordCompletedFocus(
                duration: duration,
                tagName: activeFocusMetadata?.tagName,
                note: activeFocusMetadata?.note ?? recordedNote,
                completedAt: date
            )
            focusCompletionRecorder?(duration, date)
            activeFocusMetadata = nil
        }

        publishState(nextState)

        if nextState.currentPhase == .focus, nextState.status(at: date) != .idle {
            activeFocusMetadata = ActiveFocusMetadata(
                tagName: FocusTagCatalog.normalizeTagName(selectedTagName),
                note: recordedNote
            )
        } else if nextState.currentPhase != .focus {
            activeFocusMetadata = nil
        }

        if nextState.status(at: date) == .running {
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

    private func persist(currentTaskName: String) {
        userDefaults.set(currentTaskName, forKey: StorageKey.currentTaskName)
    }

    private func persist(selectedTagName: String?) {
        if let selectedTagName {
            userDefaults.set(selectedTagName, forKey: StorageKey.selectedTagName)
        } else {
            userDefaults.removeObject(forKey: StorageKey.selectedTagName)
        }
    }

    private func persist(availableTags: [String]) {
        userDefaults.set(availableTags, forKey: StorageKey.availableTags)
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

    private static func loadCurrentTaskName(from userDefaults: UserDefaults) -> String {
        normalizeTaskNameInput(userDefaults.string(forKey: StorageKey.currentTaskName) ?? "")
    }

    private static func loadSelectedTagName(from userDefaults: UserDefaults) -> String? {
        FocusTagCatalog.normalizeTagName(userDefaults.string(forKey: StorageKey.selectedTagName))
    }

    private static func loadAvailableTags(from userDefaults: UserDefaults) -> [String] {
        let storedTags = userDefaults.stringArray(forKey: StorageKey.availableTags) ?? FocusTagCatalog.defaultTags
        return FocusTagCatalog.normalizedTags(from: storedTags)
    }

    private static func normalizeTaskNameInput(_ taskName: String) -> String {
        FocusTagCatalog.sanitize(taskName, maxLength: 80)
    }

    private func preservedPauseStateIfNeeded(
        from state: FocusTimerState,
        at date: Date,
        shouldPreservePause: Bool
    ) -> FocusTimerState {
        guard shouldPreservePause else { return state }
        return engine.pause(state, now: date) ?? state
    }

    private var recordedNote: String {
        Self.normalizeTaskNameInput(currentTaskName)
    }
}
