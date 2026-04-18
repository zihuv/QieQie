import Foundation

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
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "日"
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
        case .day:
            normalizedDate = calendar.startOfDay(for: anchorDate)
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
        case .day:
            component = .day
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
        case .day:
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
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
