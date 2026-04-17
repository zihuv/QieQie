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

    static func pageSnapshot(
        from sessions: [FocusSession],
        query: FocusStatisticsQuery,
        now: Date = Date(),
        calendar: Calendar = FocusCalendar.analytics,
        recordLimit: Int = 12
    ) -> FocusStatisticsPageSnapshot {
        let completedSessions = sessions
            .filter(\.isCompleted)
            .sorted { completionDate(for: $0) > completionDate(for: $1) }
        let normalizedQuery = query.normalized(calendar: calendar)
        let interval = normalizedQuery.interval(calendar: calendar)
        let periodSessions = completedSessions.filter {
            let completionDate = completionDate(for: $0)
            return completionDate >= interval.start && completionDate < interval.end
        }

        return FocusStatisticsPageSnapshot(
            overview: aggregateStatistics(from: completedSessions, now: now, calendar: calendar),
            tagSummaries: tagSummaries(from: periodSessions),
            trendPoints: trendPoints(from: periodSessions, query: normalizedQuery, calendar: calendar),
            recentSessions: Array(periodSessions.prefix(recordLimit)),
            periodSessionCount: periodSessions.count,
            periodTotalDuration: periodSessions.reduce(0) { $0 + $1.duration }
        )
    }

    private static func summary(from sessions: [FocusSession]) -> FocusStatisticsPeriod {
        FocusStatisticsPeriod(
            sessionCount: sessions.count,
            totalDuration: sessions.reduce(0) { $0 + $1.duration }
        )
    }

    static func tagSummaries(from sessions: [FocusSession]) -> [FocusTagSummary] {
        Dictionary(grouping: sessions, by: \.displayTagName)
            .map { tagName, groupedSessions in
                FocusTagSummary(
                    tagName: tagName,
                    totalDuration: groupedSessions.reduce(0) { $0 + $1.duration },
                    sessionCount: groupedSessions.count
                )
            }
            .sorted {
                if $0.totalDuration != $1.totalDuration {
                    return $0.totalDuration > $1.totalDuration
                }

                if $0.sessionCount != $1.sessionCount {
                    return $0.sessionCount > $1.sessionCount
                }

                return $0.tagName.localizedStandardCompare($1.tagName) == .orderedAscending
            }
    }

    static func trendPoints(
        from sessions: [FocusSession],
        query: FocusStatisticsQuery,
        calendar: Calendar = FocusCalendar.analytics
    ) -> [FocusTrendPoint] {
        let normalizedQuery = query.normalized(calendar: calendar)
        let buckets = orderedTrendBucketDates(for: normalizedQuery, calendar: calendar)
        let sessionsByBucket = Dictionary(grouping: sessions) { session in
            bucketDate(for: completionDate(for: session), granularity: normalizedQuery.granularity, calendar: calendar)
        }

        return buckets.map { date in
            let bucketSessions = sessionsByBucket[date] ?? []
            return FocusTrendPoint(
                date: date,
                totalDuration: bucketSessions.reduce(0) { $0 + $1.duration },
                sessionCount: bucketSessions.count,
                label: FocusDisplayFormatter.chartLabel(
                    for: date,
                    granularity: normalizedQuery.granularity,
                    calendar: calendar
                )
            )
        }
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
        session.completionDate
    }

    static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
            ?? calendar.startOfDay(for: date)
    }

    static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    static func startOfYear(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: date))
            ?? calendar.startOfDay(for: date)
    }

    private static func bucketDate(
        for date: Date,
        granularity: FocusStatisticsGranularity,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .day:
            return startOfHour(for: date, calendar: calendar)
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .year:
            return startOfMonth(for: date, calendar: calendar)
        }
    }

    private static func orderedTrendBucketDates(
        for query: FocusStatisticsQuery,
        calendar: Calendar
    ) -> [Date] {
        let normalizedQuery = query.normalized(calendar: calendar)
        switch normalizedQuery.granularity {
        case .day:
            return (0..<24).compactMap { offset in
                calendar.date(byAdding: .hour, value: offset, to: normalizedQuery.anchorDate)
            }
        case .week:
            let weekDates = (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: normalizedQuery.anchorDate)
            }
            return weekDates.sorted {
                let leftWeekday = calendar.component(.weekday, from: $0)
                let rightWeekday = calendar.component(.weekday, from: $1)

                if leftWeekday != rightWeekday {
                    return leftWeekday < rightWeekday
                }

                return $0 < $1
            }
        case .month:
            let interval = normalizedQuery.interval(calendar: calendar)
            let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
            return (0..<dayCount).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: normalizedQuery.anchorDate)
            }
        case .year:
            return (0..<12).compactMap { offset in
                calendar.date(byAdding: .month, value: offset, to: normalizedQuery.anchorDate)
            }
        }
    }

    private static func startOfHour(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: date))
            ?? calendar.startOfDay(for: date)
    }
}
