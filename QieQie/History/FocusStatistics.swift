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

enum FocusStatisticsGranularity: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "周"
        case .month:
            return "月"
        case .year:
            return "年"
        }
    }
}

struct FocusStatisticsQuery: Equatable {
    var granularity: FocusStatisticsGranularity = .week
    var anchorDate: Date = Date()

    func normalized(calendar: Calendar = FocusCalendar.analytics) -> FocusStatisticsQuery {
        let normalizedDate: Date
        switch granularity {
        case .week:
            normalizedDate = FocusHistoryAnalytics.startOfWeek(for: anchorDate, calendar: calendar)
        case .month:
            normalizedDate = FocusHistoryAnalytics.startOfMonth(for: anchorDate, calendar: calendar)
        case .year:
            normalizedDate = FocusHistoryAnalytics.startOfYear(for: anchorDate, calendar: calendar)
        }

        return FocusStatisticsQuery(granularity: granularity, anchorDate: normalizedDate)
    }

    func shifted(by value: Int, calendar: Calendar = FocusCalendar.analytics) -> FocusStatisticsQuery {
        let component: Calendar.Component
        switch granularity {
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

        let normalized = normalized(calendar: calendar)
        let shiftedDate = calendar.date(byAdding: component, value: value, to: normalized.anchorDate)
            ?? normalized.anchorDate
        return FocusStatisticsQuery(granularity: granularity, anchorDate: shiftedDate)
            .normalized(calendar: calendar)
    }

    func interval(calendar: Calendar = FocusCalendar.analytics) -> DateInterval {
        let normalized = normalized(calendar: calendar)
        let start = normalized.anchorDate
        let end: Date

        switch granularity {
        case .week:
            end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        case .month:
            end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        case .year:
            end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        }

        return DateInterval(start: start, end: end)
    }

    func isCurrentPeriod(now: Date = Date(), calendar: Calendar = FocusCalendar.analytics) -> Bool {
        normalized(calendar: calendar) == FocusStatisticsQuery(
            granularity: granularity,
            anchorDate: now
        ).normalized(calendar: calendar)
    }
}

struct FocusTagSummary: Identifiable {
    let tagName: String
    let totalDuration: TimeInterval
    let sessionCount: Int

    var id: String { tagName }
}

struct FocusTrendPoint: Identifiable {
    let date: Date
    let totalDuration: TimeInterval
    let sessionCount: Int
    let label: String

    var id: Date { date }
}

struct FocusHistoryInsights {
    var recentDailyTrend: [FocusDailyTrendPoint] = []
}

struct FocusStatisticsPageSnapshot {
    var overview = FocusStatistics()
    var tagSummaries: [FocusTagSummary] = []
    var trendPoints: [FocusTrendPoint] = []
    var recentSessions: [FocusSession] = []
    var periodSessionCount: Int = 0
    var periodTotalDuration: TimeInterval = 0

    var isEmpty: Bool {
        periodSessionCount == 0
    }
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
        return "\(calendar.component(.month, from: date))月"
    }

    static func chartSelectionTitle(
        for date: Date,
        granularity: FocusStatisticsGranularity,
        calendar: Calendar = FocusCalendar.analytics
    ) -> String {
        switch granularity {
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
}
