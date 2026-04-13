import Foundation

enum FocusCalendar {
    static var analytics: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

struct FocusStatisticsPeriod: Equatable {
    var sessionCount: Int = 0
    var totalDuration: TimeInterval = 0
}

struct FocusDailyTrendPoint: Identifiable {
    let date: Date
    let totalDuration: TimeInterval
    let sessionCount: Int

    var id: Date { date }
}

struct FocusHistoryInsights {
    var recentDailyTrend: [FocusDailyTrendPoint] = []
}

struct FocusStatistics {
    var today = FocusStatisticsPeriod()
    var week = FocusStatisticsPeriod()
    var month = FocusStatisticsPeriod()
    var allTime = FocusStatisticsPeriod()

    var isEmpty: Bool {
        allTime.sessionCount == 0
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        FocusDisplayFormatter.duration(interval)
    }
}

/// 展示层格式化工具，集中管理倒计时、时长和日期格式化逻辑
enum FocusDisplayFormatter {
    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let preciseDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter
    }()

    static func countdown(_ interval: TimeInterval) -> String {
        // 倒计时展示使用向上取整，保证运行中看到的秒数与暂停后冻结的秒数一致。
        let time = max(0, Int(interval.rounded(.up)))
        let hours = time / 3600
        let minutes = (time % 3600) / 60
        let seconds = time % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }

        if minutes > 0 {
            return "\(minutes)分钟"
        }

        if seconds > 0 {
            return "\(seconds)秒"
        }

        return "0分钟"
    }

    static func compactDuration(_ interval: TimeInterval) -> String {
        let clampedInterval = max(0, Int(interval.rounded(.down)))
        let hours = clampedInterval / 3600
        let minutes = (clampedInterval % 3600) / 60
        let seconds = clampedInterval % 60

        if hours > 0, minutes > 0 {
            return "\(hours)h\(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        if minutes > 0 {
            return "\(minutes)m"
        }

        if seconds > 0 {
            return "\(seconds)s"
        }

        return "0m"
    }

    static func chartDurationAxisLabel(minutes: Double) -> String {
        let roundedMinutes = max(0, Int(minutes.rounded()))
        let hours = roundedMinutes / 60
        let remainingMinutes = roundedMinutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)小时\(remainingMinutes)分"
        }

        if hours > 0 {
            return "\(hours)小时"
        }

        return "\(remainingMinutes)分"
    }

    static func minutes(_ interval: TimeInterval) -> String {
        let minutes = Int(interval.rounded(.down)) / 60
        return "\(minutes)分钟"
    }

    static func date(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    static func preciseDate(_ date: Date) -> String {
        String(preciseDateTimeFormatter.string(from: date).prefix(10))
    }

    static func time(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    static func hourMinute(_ date: Date) -> String {
        hourMinuteFormatter.string(from: date)
    }

    static func preciseDateTime(_ date: Date) -> String {
        preciseDateTimeFormatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    static func percentage(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}
