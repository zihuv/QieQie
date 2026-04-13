import XCTest
@testable import QieQie

final class FocusHistoryAnalyticsTests: XCTestCase {
    func testChartDurationAxisLabelFormatsTimeValues() {
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 0), "0分")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 25), "25分")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 60), "1小时")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 90), "1小时30分")
    }

    func testCompactDurationFormatsDashboardValues() {
        XCTAssertEqual(FocusDisplayFormatter.compactDuration(0), "0m")
        XCTAssertEqual(FocusDisplayFormatter.compactDuration(25 * 60), "25m")
        XCTAssertEqual(FocusDisplayFormatter.compactDuration(60 * 60), "1h")
        XCTAssertEqual(FocusDisplayFormatter.compactDuration((2 * 60 + 5) * 60), "2h5m")
    }

    func testSummaryDurationFormatsMainPanelValues() {
        XCTAssertEqual(FocusDisplayFormatter.summaryDuration(0), "0min")
        XCTAssertEqual(FocusDisplayFormatter.summaryDuration(25 * 60), "25min")
        XCTAssertEqual(FocusDisplayFormatter.summaryDuration(60 * 60), "1h")
        XCTAssertEqual(FocusDisplayFormatter.summaryDuration((2 * 60 + 30) * 60), "2h30min")
    }

    func testPreciseDateTimeUsesYearMonthDayAnd24HourTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = makeDate(year: 2026, month: 5, day: 3, hour: 12, minute: 12, calendar: calendar)

        XCTAssertEqual(FocusDisplayFormatter.preciseDateTime(date), "2026-05-03 12:12")
    }

    func testStatisticsOverviewGroupingSortsDaysDescendingAndSessionsDescending() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let sessions = [
            makeSession(
                taskName: "second-day-late",
                startTime: makeDate(year: 2026, month: 5, day: 3, hour: 18, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 3, hour: 18, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                taskName: "first-day-early",
                startTime: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 2, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                taskName: "second-day-early",
                startTime: makeDate(year: 2026, month: 5, day: 3, hour: 8, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 3, hour: 8, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                taskName: "ignored",
                startTime: makeDate(year: 2026, month: 5, day: 4, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 4, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: false
            )
        ]

        let sections = StatisticsOverviewGrouping.sections(from: sessions, calendar: calendar)

        XCTAssertEqual(sections.map { FocusDisplayFormatter.preciseDate($0.date) }, ["2026-05-03", "2026-05-02"])
        XCTAssertEqual(sections[0].sessions.map(\.taskName), ["second-day-late", "second-day-early"])
        XCTAssertEqual(sections[1].sessions.map(\.taskName), ["first-day-early"])
    }

    func testStatisticsOverviewGroupingFormatsTimeRangeIn24HourClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let session = makeSession(
            startTime: makeDate(year: 2026, month: 5, day: 3, hour: 9, minute: 5, calendar: calendar),
            endTime: makeDate(year: 2026, month: 5, day: 3, hour: 9, minute: 45, calendar: calendar),
            duration: 40 * 60,
            isCompleted: true
        )

        XCTAssertEqual(StatisticsOverviewGrouping.timeRangeText(for: session), "09:05 - 09:45")
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
        taskName: String = "专注",
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        isCompleted: Bool
    ) -> FocusSession {
        FocusSession(
            taskName: taskName,
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
