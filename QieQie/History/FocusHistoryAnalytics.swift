import Foundation

enum FocusHistoryAnalytics {
    static func aggregateStatistics(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FocusStatistics {
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = self.startOfWeek(for: now, calendar: calendar)
        let startOfMonth = self.startOfMonth(for: now, calendar: calendar)

        var statistics = FocusStatistics()
        statistics.sessionCount = sessions.count
        statistics.completedCount = sessions.filter(\.isCompleted).count
        statistics.allTimeTotal = sessions.reduce(0) { $0 + $1.duration }
        statistics.todayTotal = sessions.filter { $0.startTime >= startOfDay }.reduce(0) { $0 + $1.duration }
        statistics.weekTotal = sessions.filter { $0.startTime >= startOfWeek }.reduce(0) { $0 + $1.duration }
        statistics.monthTotal = sessions.filter { $0.startTime >= startOfMonth }.reduce(0) { $0 + $1.duration }
        return statistics
    }

    static func buildInsights(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = .current,
        trendDayCount: Int = 7
    ) -> FocusHistoryInsights {
        FocusHistoryInsights(
            recentDailyTrend: recentDailyTrend(from: sessions, now: now, calendar: calendar, dayCount: trendDayCount),
            currentStreak: currentStreak(from: sessions, calendar: calendar),
            longestSessionDuration: sessions.map(\.duration).max() ?? 0
        )
    }

    static func recentDailyTrend(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = .current,
        dayCount: Int = 7
    ) -> [FocusDailyTrendPoint] {
        guard dayCount > 0 else { return [] }

        let sessionsByDay = groupedSessionsByDay(sessions, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)

        return (0..<dayCount).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return nil
            }

            let daySessions = sessionsByDay[day] ?? []
            return FocusDailyTrendPoint(
                date: day,
                totalDuration: daySessions.reduce(0) { $0 + $1.duration },
                sessionCount: daySessions.count,
                completedCount: daySessions.filter(\.isCompleted).count
            )
        }
    }

    static func currentStreak(
        from sessions: [FocusSession],
        calendar: Calendar = .current
    ) -> Int {
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
        guard var currentDay = activeDays.max() else { return 0 }

        var streak = 0
        while activeDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }

        return streak
    }

    private static func groupedSessionsByDay(
        _ sessions: [FocusSession],
        calendar: Calendar
    ) -> [Date: [FocusSession]] {
        Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
            ?? calendar.startOfDay(for: date)
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }
}
