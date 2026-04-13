import XCTest
@testable import QieQie

final class FocusHistoryAnalyticsTests: XCTestCase {
    func testChartDurationAxisLabelFormatsTimeValues() {
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 0), "0分")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 25), "25分")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 60), "1小时")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 90), "1小时30分")
    }

    func testAggregateStatisticsOnlyCountsCompletedFocusSessionsAcrossScopes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let now = makeDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0, calendar: calendar)
        let sessions = [
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 14, hour: 8, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 14, hour: 8, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 13, hour: 7, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 13, hour: 7, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 12, hour: 18, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 12, hour: 18, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: false
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 3, day: 31, hour: 22, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 1, hour: 8, minute: 0, calendar: calendar),
                duration: 1800,
                isCompleted: true
            )
        ]

        let statistics = FocusHistoryAnalytics.aggregateStatistics(from: sessions, now: now, calendar: calendar)

        XCTAssertEqual(statistics.today.sessionCount, 1)
        XCTAssertEqual(statistics.today.totalDuration, 1500)
        XCTAssertEqual(statistics.week.sessionCount, 3)
        XCTAssertEqual(statistics.week.totalDuration, 4500)
        XCTAssertEqual(statistics.month.sessionCount, 4)
        XCTAssertEqual(statistics.month.totalDuration, 6300)
        XCTAssertEqual(statistics.allTime.sessionCount, 4)
        XCTAssertEqual(statistics.allTime.totalDuration, 6300)
    }

    func testRecentDailyTrendUsesCompletionDateAndKeepsSevenDaysOfBuckets() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let now = makeDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0, calendar: calendar)
        let sessions = [
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 14, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 14, hour: 9, minute: 25, calendar: calendar),
                duration: 1200,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 10, hour: 23, minute: 40, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 11, hour: 0, minute: 5, calendar: calendar),
                duration: 1800,
                isCompleted: true
            ),
            makeSession(
                startTime: makeDate(year: 2026, month: 4, day: 9, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 9, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: false
            )
        ]

        let trend = FocusHistoryAnalytics.recentDailyTrend(from: sessions, now: now, calendar: calendar)

        XCTAssertEqual(trend.count, 7)
        XCTAssertEqual(trend.map(\.sessionCount), [0, 0, 1, 0, 0, 1, 1])
        XCTAssertEqual(trend.map(\.totalDuration), [0, 0, 1800, 0, 0, 1200, 1500])
    }

    private func makeSession(
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        isCompleted: Bool
    ) -> FocusSession {
        FocusSession(
            taskName: "专注",
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            isCompleted: isCompleted
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
