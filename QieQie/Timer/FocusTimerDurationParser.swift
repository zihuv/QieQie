import Foundation

enum FocusTimerDurationParser {
    static func parse(minutes: String, seconds: String) -> TimeInterval? {
        guard let min = Int(minutes),
              let sec = Int(seconds),
              min >= 0,
              sec >= 0,
              sec < 60,
              min * 60 + sec > 0 else {
            return nil
        }

        return TimeInterval(min * 60 + sec)
    }

    static func sanitizeNumericInput(_ value: String, maxLength: Int, upperBound: Int? = nil) -> String {
        var sanitized = String(value.filter(\.isNumber).prefix(maxLength))

        if let upperBound, let number = Int(sanitized), number > upperBound {
            sanitized = String(upperBound)
        }

        return sanitized
    }
}
