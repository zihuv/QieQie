import XCTest
@testable import QieQie

final class FocusHistoryAnalyticsTests: XCTestCase {
    func testChartDurationAxisLabelFormatsTimeValues() {
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 0), "0m")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 25), "25m")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 60), "1h")
        XCTAssertEqual(FocusDisplayFormatter.chartDurationAxisLabel(minutes: 80), "1h20m")
    }

    func testChartLabelsUseChineseWeekdayAndMonthSymbols() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = makeDate(year: 2026, month: 4, day: 13, hour: 12, minute: 0, calendar: calendar)
        let april = makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 0, calendar: calendar)

        XCTAssertEqual(
            FocusDisplayFormatter.chartLabel(for: monday, granularity: .day, calendar: calendar),
            "12:00"
        )
        XCTAssertEqual(
            FocusDisplayFormatter.chartLabel(for: monday, granularity: .week, calendar: calendar),
            "一"
        )
        XCTAssertEqual(
            FocusDisplayFormatter.chartLabel(for: monday, granularity: .month, calendar: calendar),
            "13"
        )
        XCTAssertEqual(
            FocusDisplayFormatter.chartLabel(for: april, granularity: .year, calendar: calendar),
            "4月"
        )
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

    func testDayQueryNormalizesIntervalAndPeriodTitle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let anchor = makeDate(year: 2026, month: 5, day: 3, hour: 12, minute: 12, calendar: calendar)
        let normalized = FocusStatisticsQuery(granularity: .day, anchorDate: anchor)
            .normalized(calendar: calendar)
        let interval = normalized.interval(calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: normalized.anchorDate)
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: interval.start)
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: interval.end)

        XCTAssertEqual(normalizedComponents.year, 2026)
        XCTAssertEqual(normalizedComponents.month, 5)
        XCTAssertEqual(normalizedComponents.day, 3)
        XCTAssertEqual(normalizedComponents.hour, 0)
        XCTAssertEqual(normalizedComponents.minute, 0)
        XCTAssertEqual(startComponents.year, 2026)
        XCTAssertEqual(startComponents.month, 5)
        XCTAssertEqual(startComponents.day, 3)
        XCTAssertEqual(startComponents.hour, 0)
        XCTAssertEqual(startComponents.minute, 0)
        XCTAssertEqual(endComponents.year, 2026)
        XCTAssertEqual(endComponents.month, 5)
        XCTAssertEqual(endComponents.day, 4)
        XCTAssertEqual(endComponents.hour, 0)
        XCTAssertEqual(endComponents.minute, 0)
        XCTAssertEqual(FocusDisplayFormatter.periodTitle(for: normalized, calendar: calendar), "2026年5月3日")
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

    func testPageSnapshotBuildsChronologicalWeekTrendAndTagBreakdown() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let weekAnchor = makeDate(year: 2026, month: 4, day: 13, hour: 12, minute: 0, calendar: calendar)
        let sessions = [
            makeSession(
                taskName: "接口联调",
                tagName: "开发",
                note: "接口联调",
                startTime: makeDate(year: 2026, month: 4, day: 13, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 13, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                taskName: "读论文",
                tagName: "学习",
                note: "读论文",
                startTime: makeDate(year: 2026, month: 4, day: 15, hour: 10, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 15, hour: 10, minute: 40, calendar: calendar),
                duration: 2400,
                isCompleted: true
            ),
            makeSession(
                taskName: "专注",
                tagName: nil,
                note: nil,
                startTime: makeDate(year: 2026, month: 4, day: 18, hour: 8, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 18, hour: 8, minute: 30, calendar: calendar),
                duration: 1800,
                isCompleted: true
            ),
            makeSession(
                taskName: "下周准备",
                tagName: "会议",
                note: "下周准备",
                startTime: makeDate(year: 2026, month: 4, day: 20, hour: 8, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 4, day: 20, hour: 8, minute: 30, calendar: calendar),
                duration: 1800,
                isCompleted: true
            )
        ]

        let snapshot = FocusHistoryAnalytics.pageSnapshot(
            from: sessions,
            query: FocusStatisticsQuery(granularity: .week, anchorDate: weekAnchor),
            now: weekAnchor,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.tagSummaries.map(\.tagName), ["学习", "未分类", "开发"])
        XCTAssertEqual(snapshot.tagSummaries.map(\.sessionCount), [1, 1, 1])
        XCTAssertEqual(snapshot.trendPoints.count, 7)
        XCTAssertEqual(snapshot.trendPoints.map(\.label), ["日", "一", "二", "三", "四", "五", "六"])
        XCTAssertEqual(snapshot.trendPoints.map(\.sessionCount), [0, 1, 0, 1, 0, 0, 1])
        XCTAssertEqual(snapshot.trendPoints.map(\.totalDuration), [0, 1500, 0, 2400, 0, 0, 1800])
        XCTAssertEqual(snapshot.recentSessions.map(\.taskName), ["专注", "读论文", "接口联调"])
    }

    func testPageSnapshotSupportsDayGranularity() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let dayAnchor = makeDate(year: 2026, month: 5, day: 3, hour: 12, minute: 0, calendar: calendar)
        let sessions = [
            makeSession(
                taskName: "深夜收尾",
                tagName: "开发",
                note: "深夜收尾",
                startTime: makeDate(year: 2026, month: 5, day: 2, hour: 23, minute: 40, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 3, hour: 0, minute: 5, calendar: calendar),
                duration: 1500,
                isCompleted: true
            ),
            makeSession(
                taskName: "上午阅读",
                tagName: "学习",
                note: "上午阅读",
                startTime: makeDate(year: 2026, month: 5, day: 3, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 3, hour: 9, minute: 40, calendar: calendar),
                duration: 2400,
                isCompleted: true
            ),
            makeSession(
                taskName: "次日任务",
                tagName: "开发",
                note: "次日任务",
                startTime: makeDate(year: 2026, month: 5, day: 4, hour: 9, minute: 0, calendar: calendar),
                endTime: makeDate(year: 2026, month: 5, day: 4, hour: 9, minute: 25, calendar: calendar),
                duration: 1500,
                isCompleted: true
            )
        ]

        let snapshot = FocusHistoryAnalytics.pageSnapshot(
            from: sessions,
            query: FocusStatisticsQuery(granularity: .day, anchorDate: dayAnchor),
            now: dayAnchor,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.tagSummaries.map(\.tagName), ["学习", "开发"])
        XCTAssertEqual(snapshot.tagSummaries.map(\.sessionCount), [1, 1])
        XCTAssertEqual(snapshot.periodSessionCount, 2)
        XCTAssertEqual(snapshot.periodTotalDuration, 3900)
        XCTAssertEqual(snapshot.recentSessions.map(\.taskName), ["上午阅读", "深夜收尾"])
        XCTAssertEqual(snapshot.trendPoints.count, 24)
        XCTAssertEqual(snapshot.trendPoints.map(\.sessionCount).reduce(0, +), 2)
        XCTAssertEqual(snapshot.trendPoints[0].label, "00:00")
        XCTAssertEqual(snapshot.trendPoints[9].sessionCount, 1)
        XCTAssertEqual(snapshot.trendPoints[9].totalDuration, 2400)
    }

    private func makeSession(
        taskName: String = "专注",
        tagName: String? = nil,
        note: String? = nil,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        isCompleted: Bool
    ) -> FocusSession {
        FocusSession(
            taskName: taskName,
            tagName: tagName,
            note: note,
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
