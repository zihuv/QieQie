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
