import XCTest
@testable import QieQie

final class FocusHistoryAnalyticsTests: XCTestCase {
    func testAggregateStatisticsAndInsightsProvideCompactHistorySummary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let now = makeDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0, calendar: calendar)
        let sessions = [
            makeSession(on: makeDate(year: 2026, month: 4, day: 15, hour: 9, minute: 0, calendar: calendar), duration: 1500, isCompleted: true),
            makeSession(on: makeDate(year: 2026, month: 4, day: 14, hour: 9, minute: 30, calendar: calendar), duration: 1200, isCompleted: false),
            makeSession(on: makeDate(year: 2026, month: 4, day: 13, hour: 10, minute: 0, calendar: calendar), duration: 2100, isCompleted: true),
            makeSession(on: makeDate(year: 2026, month: 4, day: 11, hour: 8, minute: 0, calendar: calendar), duration: 3600, isCompleted: true),
            makeSession(on: makeDate(year: 2026, month: 4, day: 9, hour: 16, minute: 0, calendar: calendar), duration: 900, isCompleted: false)
        ]

        let statistics = FocusHistoryAnalytics.aggregateStatistics(from: sessions, now: now, calendar: calendar)
        XCTAssertEqual(statistics.sessionCount, 5)
        XCTAssertEqual(statistics.completedCount, 3)
        XCTAssertEqual(statistics.todayTotal, 1500)
        XCTAssertEqual(statistics.weekTotal, 4800)
        XCTAssertEqual(statistics.monthTotal, 9300)
        XCTAssertEqual(statistics.allTimeTotal, 9300)
        XCTAssertEqual(statistics.completionRate, 0.6, accuracy: 0.0001)
        XCTAssertEqual(statistics.averageSessionDuration, 1860, accuracy: 0.0001)

        let insights = FocusHistoryAnalytics.buildInsights(from: sessions, now: now, calendar: calendar)
        XCTAssertEqual(insights.currentStreak, 3)
        XCTAssertEqual(insights.longestSessionDuration, 3600)
        XCTAssertEqual(insights.recentDailyTrend.map(\.sessionCount), [1, 0, 1, 0, 1, 1, 1])
        XCTAssertEqual(insights.recentDailyTrend.map(\.completedCount), [0, 0, 1, 0, 1, 0, 1])
        XCTAssertEqual(insights.recentDailyTrend.map(\.totalDuration), [900, 0, 3600, 0, 2100, 1200, 1500])
    }

    private func makeSession(on startTime: Date, duration: TimeInterval, isCompleted: Bool) -> FocusSession {
        FocusSession(
            taskName: "Deep Work",
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
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
