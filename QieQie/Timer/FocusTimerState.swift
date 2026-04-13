import Foundation

enum FocusTimerPhase: String, CaseIterable, Equatable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus:
            return "专注时间"
        case .shortBreak:
            return "短休息"
        case .longBreak:
            return "长休息"
        }
    }

    var subtitle: String {
        switch self {
        case .focus:
            return "进入一个完整的番茄钟"
        case .shortBreak:
            return "给自己一点短暂缓冲"
        case .longBreak:
            return "这一轮结束，休息久一点"
        }
    }

    var symbolName: String {
        switch self {
        case .focus:
            return "target"
        case .shortBreak:
            return "cup.and.saucer"
        case .longBreak:
            return "bed.double"
        }
    }
}

enum FocusTimerStatus: Equatable {
    case idle
    case running
    case paused
}

struct FocusTimerConfiguration: Equatable {
    var focusDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    var longBreakInterval: Int = 4
    var autoStartBreak: Bool = true
    var autoStartNextFocus: Bool = true

    static let `default` = FocusTimerConfiguration()

    init(
        focusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        longBreakInterval: Int = 4,
        autoStartBreak: Bool = true,
        autoStartNextFocus: Bool = true
    ) {
        self.focusDuration = focusDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.longBreakInterval = longBreakInterval
        self.autoStartBreak = autoStartBreak
        self.autoStartNextFocus = autoStartNextFocus
    }

    func normalized() -> FocusTimerConfiguration {
        FocusTimerConfiguration(
            focusDuration: Self.normalizedDuration(focusDuration, fallback: Self.default.focusDuration),
            shortBreakDuration: Self.normalizedDuration(
                shortBreakDuration,
                fallback: Self.default.shortBreakDuration
            ),
            longBreakDuration: Self.normalizedDuration(
                longBreakDuration,
                fallback: Self.default.longBreakDuration
            ),
            longBreakInterval: min(max(longBreakInterval, 1), 10),
            autoStartBreak: autoStartBreak,
            autoStartNextFocus: autoStartNextFocus
        )
    }

    func duration(for phase: FocusTimerPhase) -> TimeInterval {
        switch phase {
        case .focus:
            return focusDuration
        case .shortBreak:
            return shortBreakDuration
        case .longBreak:
            return longBreakDuration
        }
    }

    func shouldAutoStartNextPhase(after phase: FocusTimerPhase) -> Bool {
        switch phase {
        case .focus:
            return autoStartBreak
        case .shortBreak, .longBreak:
            return autoStartNextFocus
        }
    }

    private static func normalizedDuration(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        let rounded = max(60, value.rounded(.down))
        return rounded.isFinite ? rounded : fallback
    }
}

struct FocusTimerState: Equatable {
    var configuration: FocusTimerConfiguration = .default
    var currentPhase: FocusTimerPhase = .focus
    var cycleFocusCount: Int = 0
    var phaseDuration: TimeInterval = FocusTimerConfiguration.default.focusDuration
    var endTime: Date?
    var isPaused: Bool = false
    var pausedAt: Date?

    var status: FocusTimerStatus {
        status(at: Date())
    }

    var remainingTime: TimeInterval {
        remainingTime(at: Date())
    }

    var progressText: String {
        "\(cycleFocusCount)/\(configuration.longBreakInterval)"
    }

    var canReset: Bool {
        status != .idle || currentPhase != .focus || cycleFocusCount > 0
    }

    var canSkip: Bool {
        status == .running || status == .paused
    }

    func status(at now: Date) -> FocusTimerStatus {
        if isPaused {
            return .paused
        }

        return endTime == nil ? .idle : .running
    }

    func remainingTime(at now: Date) -> TimeInterval {
        if isPaused, let pausedAt, let endTime {
            return max(0, endTime.timeIntervalSince(pausedAt))
        }

        if let endTime {
            return max(0, endTime.timeIntervalSince(now))
        }

        return phaseDuration
    }

    func refreshed() -> FocusTimerState {
        FocusTimerState(
            configuration: configuration,
            currentPhase: currentPhase,
            cycleFocusCount: cycleFocusCount,
            phaseDuration: phaseDuration,
            endTime: endTime,
            isPaused: isPaused,
            pausedAt: pausedAt
        )
    }
}
