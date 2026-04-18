import Foundation

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

    static func summaryDuration(_ interval: TimeInterval) -> String {
        let clampedInterval = max(0, Int(interval.rounded(.down)))
        let hours = clampedInterval / 3600
        let minutes = (clampedInterval % 3600) / 60
        let seconds = clampedInterval % 60

        if hours > 0, minutes > 0 {
            return "\(hours)h\(minutes)min"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        if minutes > 0 {
            return "\(minutes)min"
        }

        if seconds > 0 {
            return "\(seconds)s"
        }

        return "0min"
    }

    static func chartDurationAxisLabel(minutes: Double) -> String {
        let roundedMinutes = max(0, Int(minutes.rounded()))
        let hours = roundedMinutes / 60
        let remainingMinutes = roundedMinutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)h\(remainingMinutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(remainingMinutes)m"
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
        weekdaySymbol(for: date)
    }

    static func chartLabel(
        for date: Date,
        granularity: FocusStatisticsGranularity,
        calendar: Calendar = FocusCalendar.analytics
    ) -> String {
        switch granularity {
        case .day:
            return hourMinute(date, calendar: calendar)
        case .week:
            return weekdaySymbol(for: date, calendar: calendar)
        case .month:
            return "\(calendar.component(.day, from: date))"
        case .year:
            return monthText(date)
        }
    }

    static func periodTitle(
        for query: FocusStatisticsQuery,
        calendar: Calendar = FocusCalendar.analytics
    ) -> String {
        let normalized = query.normalized(calendar: calendar)

        switch normalized.granularity {
        case .day:
            let year = calendar.component(.year, from: normalized.anchorDate)
            let month = calendar.component(.month, from: normalized.anchorDate)
            let day = calendar.component(.day, from: normalized.anchorDate)
            return "\(year)年\(month)月\(day)日"
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: normalized.anchorDate)
            let yearForWeek = calendar.component(.yearForWeekOfYear, from: normalized.anchorDate)
            return "\(yearForWeek)年第\(weekOfYear)周"
        case .month:
            let year = calendar.component(.year, from: normalized.anchorDate)
            let month = calendar.component(.month, from: normalized.anchorDate)
            return "\(year)年\(month)月"
        case .year:
            let year = calendar.component(.year, from: normalized.anchorDate)
            return "\(year)年"
        }
    }

    static func monthText(_ date: Date, calendar: Calendar = FocusCalendar.analytics) -> String {
        "\(calendar.component(.month, from: date))月"
    }

    static func chartSelectionTitle(
        for date: Date,
        granularity: FocusStatisticsGranularity,
        calendar: Calendar = FocusCalendar.analytics
    ) -> String {
        switch granularity {
        case .day:
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return "\(month)月\(day)日 \(hourMinute(date, calendar: calendar))"
        case .week, .month:
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return "\(month)月\(day)日"
        case .year:
            return monthText(date, calendar: calendar)
        }
    }

    static func weekdaySymbol(
        for date: Date,
        calendar: Calendar = FocusCalendar.analytics
    ) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1:
            return "日"
        case 2:
            return "一"
        case 3:
            return "二"
        case 4:
            return "三"
        case 5:
            return "四"
        case 6:
            return "五"
        case 7:
            return "六"
        default:
            return ""
        }
    }

    static func percentage(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static func hourMinute(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }
}
