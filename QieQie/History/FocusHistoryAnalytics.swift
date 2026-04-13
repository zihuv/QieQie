import Foundation

enum FocusHistoryAnalytics {
    static func aggregateStatistics(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = FocusCalendar.analytics
    ) -> FocusStatistics {
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = self.startOfWeek(for: now, calendar: calendar)
        let startOfMonth = self.startOfMonth(for: now, calendar: calendar)
        let completedSessions = sessions.filter(\.isCompleted)

        return FocusStatistics(
            today: summary(
                from: completedSessions.filter { completionDate(for: $0) >= startOfDay }
            ),
            week: summary(
                from: completedSessions.filter { completionDate(for: $0) >= startOfWeek }
            ),
            month: summary(
                from: completedSessions.filter { completionDate(for: $0) >= startOfMonth }
            ),
            allTime: summary(from: completedSessions)
        )
    }

    static func buildInsights(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = FocusCalendar.analytics,
        trendDayCount: Int = 7
    ) -> FocusHistoryInsights {
        FocusHistoryInsights(
            recentDailyTrend: recentDailyTrend(
                from: sessions,
                now: now,
                calendar: calendar,
                dayCount: trendDayCount
            )
        )
    }

    static func recentDailyTrend(
        from sessions: [FocusSession],
        now: Date = Date(),
        calendar: Calendar = FocusCalendar.analytics,
        dayCount: Int = 7
    ) -> [FocusDailyTrendPoint] {
        guard dayCount > 0 else { return [] }

        let completedSessions = sessions.filter(\.isCompleted)
        let sessionsByDay = groupedSessionsByDay(completedSessions, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)

        return (0..<dayCount).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return nil
            }

            let daySessions = sessionsByDay[day] ?? []
            return FocusDailyTrendPoint(
                date: day,
                totalDuration: daySessions.reduce(0) { $0 + $1.duration },
                sessionCount: daySessions.count
            )
        }
    }

    private static func summary(from sessions: [FocusSession]) -> FocusStatisticsPeriod {
        FocusStatisticsPeriod(
            sessionCount: sessions.count,
            totalDuration: sessions.reduce(0) { $0 + $1.duration }
        )
    }

    private static func groupedSessionsByDay(
        _ sessions: [FocusSession],
        calendar: Calendar
    ) -> [Date: [FocusSession]] {
        Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: completionDate(for: session))
        }
    }

    private static func completionDate(for session: FocusSession) -> Date {
        session.endTime ?? session.startTime
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
