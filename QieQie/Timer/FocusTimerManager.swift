import Combine
import Foundation

@MainActor
final class FocusTimerManager: ObservableObject {
    @Published var state: FocusTimerState
    @Published var currentTaskName: String
    @Published var selectedTagName: String?
    @Published private(set) var availableTags: [String]

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
        let initialConfiguration = FocusTimerStorage.loadConfiguration(from: userDefaults)
        self.focusHistoryManager = focusHistoryManager
        self.clock = clock
        self.tickerScheduler = tickerScheduler
        self.userDefaults = userDefaults
        self.focusCompletionRecorder = focusCompletionRecorder
        self.state = FocusTimerEngine().makeInitialState(configuration: initialConfiguration)
        self.currentTaskName = FocusTimerStorage.loadCurrentTaskName(from: userDefaults)
        let loadedTags = FocusTimerStorage.loadAvailableTags(from: userDefaults)
        let loadedSelectedTagName = FocusTimerStorage.loadSelectedTagName(from: userDefaults)
        self.availableTags = FocusTagCatalog.normalizedTags(
            from: loadedTags + (loadedSelectedTagName.map { [$0] } ?? [])
        )
        self.selectedTagName = loadedSelectedTagName
    }

    var configuration: FocusTimerConfiguration {
        state.configuration
    }

    func updateConfiguration(_ configuration: FocusTimerConfiguration) {
        let normalized = configuration.normalized()
        FocusTimerStorage.persist(configuration: normalized, in: userDefaults)
        publishState(engine.applyConfiguration(normalized, to: state))
    }

    func updateCurrentTaskName(_ taskName: String) {
        let normalized = FocusTimerStorage.normalizeTaskNameInput(taskName)
        guard normalized != currentTaskName else { return }

        currentTaskName = normalized
        FocusTimerStorage.persist(currentTaskName: normalized, in: userDefaults)
    }

    func updateSelectedTagName(_ tagName: String?) {
        let normalized = FocusTagCatalog.normalizeTagName(tagName)

        if let normalized, !availableTags.contains(normalized) {
            availableTags.append(normalized)
            FocusTimerStorage.persist(availableTags: availableTags, in: userDefaults)
        }

        guard normalized != selectedTagName else { return }

        selectedTagName = normalized
        FocusTimerStorage.persist(selectedTagName: normalized, in: userDefaults)
    }

    @discardableResult
    func addTag(_ tagName: String) -> String? {
        guard let normalized = FocusTagCatalog.normalizeTagName(tagName) else {
            return nil
        }

        if !availableTags.contains(normalized) {
            availableTags.append(normalized)
            FocusTimerStorage.persist(availableTags: availableTags, in: userDefaults)
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
        FocusTimerStorage.persist(availableTags: updatedTags, in: userDefaults)

        if selectedTagName == normalized {
            selectedTagName = nil
            FocusTimerStorage.persist(selectedTagName: nil, in: userDefaults)
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
        FocusTimerStorage.persist(availableTags: updatedTags, in: userDefaults)

        if selectedTagName == normalizedOldName {
            selectedTagName = normalizedNewName
            FocusTimerStorage.persist(selectedTagName: normalizedNewName, in: userDefaults)
        }

        return true
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
        let shouldPreservePause = trigger == .skipped && state.isPaused
        let result = engine.advance(state, now: date, trigger: trigger)
        let nextState = preservedPauseStateIfNeeded(
            from: result.state,
            at: date,
            shouldPreservePause: shouldPreservePause
        )
        if let duration = result.recordedFocusDuration {
            focusHistoryManager?.recordCompletedFocus(
                duration: duration,
                tagName: FocusTagCatalog.normalizeTagName(selectedTagName),
                note: recordedNote,
                completedAt: date
            )
            focusCompletionRecorder?(duration, date)
        }

        publishState(nextState)

        if nextState.status(at: date) == .running {
            startTimer()
        }
    }

    private func publishState(_ newState: FocusTimerState) {
        state = newState
        objectWillChange.send()
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
        FocusTimerStorage.normalizeTaskNameInput(currentTaskName)
    }
}
