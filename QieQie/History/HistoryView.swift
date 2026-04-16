import Charts
import SwiftUI

enum StatisticsWindowLayout {
    static let defaultSize = FocusPanelLayout.unifiedPanelSize
    static let minSize = FocusPanelLayout.unifiedPanelSize
}

struct HistoryView: View {
    let historyManager: FocusHistoryManager

    @State private var statistics = FocusStatistics()
    @State private var historyInsights = FocusHistoryInsights()
    @State private var showClearConfirmation = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summarySection
            trendSection
            actionSection
        }
        .padding(12)
        .frame(
            minWidth: StatisticsWindowLayout.minSize.width,
            maxWidth: .infinity,
            minHeight: StatisticsWindowLayout.minSize.height,
            maxHeight: .infinity,
            alignment: .top
        )
        .onAppear(perform: loadData)
        .alert("清空所有统计？", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                if historyManager.clearAllSessions() {
                    loadData()
                }
            }
        } message: {
            Text("此操作无法恢复。")
        }
    }

    private var summarySection: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            summaryCard(title: "今日", period: statistics.today)
            summaryCard(title: "本周", period: statistics.week)
            summaryCard(title: "本月", period: statistics.month)
            summaryCard(title: "总计", period: statistics.allTime)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("近 7 天")
                    .font(FocusPanelTypography.sectionTitle)
                Text("累计 \(FocusStatistics.formatDuration(recentTrendTotal))")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
            }

            if statistics.isEmpty {
                Text("完成一次专注后显示趋势")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            } else {
                Chart {
                    ForEach(historyInsights.recentDailyTrend) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("时长", point.totalDuration / 60)
                        )
                        .foregroundStyle(Color.accentColor.opacity(Calendar.current.isDateInToday(point.date) ? 1 : 0.45))
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.16))
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.3))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self), minutes > 0 {
                                Text(FocusDisplayFormatter.chartDurationAxisLabel(minutes: minutes))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: historyInsights.recentDailyTrend.map(\.date)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(FocusDisplayFormatter.weekday(date))
                            }
                        }
                    }
                }
                .frame(height: 112)
            }
        }
        .padding(8)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            Button(action: loadData) {
                Text("刷新")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)

            Button(action: { showClearConfirmation = true }) {
                Text("清空统计")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(statistics.isEmpty)
        }
    }

    private func summaryCard(title: String, period: FocusStatisticsPeriod) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)

            Text("\(period.sessionCount) 次")
                .font(FocusPanelTypography.cardValue)

            Text(FocusStatistics.formatDuration(period.totalDuration))
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(8)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private func loadData() {
        let snapshot = historyManager.getHistorySnapshot()
        statistics = snapshot.statistics
        historyInsights = snapshot.insights
    }

    private var recentTrendTotal: TimeInterval {
        historyInsights.recentDailyTrend.reduce(0) { $0 + $1.totalDuration }
    }
}

struct StatisticsOverviewView: View {
    let statistics: FocusStatistics
    let recentSessions: [FocusSession]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                summarySection
                recordsSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("概览")
                .font(FocusPanelTypography.sectionTitle)

            VStack(spacing: 0) {
                ForEach(Array(summaryMetrics.enumerated()), id: \.element.id) { index, metric in
                    summaryMetricRow(metric)

                    if index < summaryMetrics.count - 1 {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .focusPanelSurface()
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("专注记录")
                .font(FocusPanelTypography.sectionTitle)

            if daySections.isEmpty {
                Text("完成一次专注后显示最近记录")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                    .padding(8)
                    .focusPanelSurface()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(daySections.enumerated()), id: \.element.id) { index, section in
                        daySection(section)

                        if index < daySections.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focusPanelSurface()
            }
        }
    }

    private var summaryMetrics: [StatisticsOverviewMetric] {
        [
            StatisticsOverviewMetric(title: "今日番茄", value: "\(statistics.today.sessionCount)"),
            StatisticsOverviewMetric(
                title: "今日专注时长",
                value: FocusDisplayFormatter.compactDuration(statistics.today.totalDuration)
            ),
            StatisticsOverviewMetric(title: "总番茄", value: "\(statistics.allTime.sessionCount)"),
            StatisticsOverviewMetric(
                title: "总专注时长",
                value: FocusDisplayFormatter.compactDuration(statistics.allTime.totalDuration)
            )
        ]
    }

    private var daySections: [StatisticsOverviewDaySection] {
        StatisticsOverviewGrouping.sections(from: recentSessions)
    }

    private func summaryMetricRow(_ metric: StatisticsOverviewMetric) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(metric.title)
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)

            Spacer(minLength: 10)

            Text(metric.value)
                .font(FocusPanelTypography.metricValue)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func daySection(_ section: StatisticsOverviewDaySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(FocusDisplayFormatter.preciseDate(section.date))
                .font(FocusPanelTypography.dateLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(section.sessions.enumerated()), id: \.element.id) { index, session in
                    sessionRow(
                        session,
                        showsConnector: index < section.sessions.count - 1
                    )
                }
            }
        }
    }

    private func sessionRow(_ session: FocusSession, showsConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            timelineMarker(showsConnector: showsConnector)

            VStack(alignment: .leading, spacing: 4) {
                Text(StatisticsOverviewGrouping.timeRangeText(for: session))
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Text(taskName(for: session))
                    .font(FocusPanelTypography.entryTitle)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(FocusDisplayFormatter.compactDuration(session.duration))
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .padding(.top, 1)
        }
        .padding(.vertical, 6)
    }

    private func timelineMarker(showsConnector: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 5)
                )

            if showsConnector {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.22))
                    .frame(width: 1, height: 34)
                    .padding(.top, 4)
            }
        }
        .frame(width: 12, alignment: .top)
        .padding(.top, 4)
    }

    private func taskName(for session: FocusSession) -> String {
        let trimmed = session.taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "专注" : trimmed
    }
}

private struct StatisticsOverviewMetric: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

struct StatisticsOverviewDaySection: Identifiable {
    let date: Date
    let sessions: [FocusSession]

    var id: Date { date }
}

enum StatisticsOverviewGrouping {
    static func sections(
        from recentSessions: [FocusSession],
        calendar: Calendar = FocusCalendar.analytics
    ) -> [StatisticsOverviewDaySection] {
        let completedSessions = recentSessions.filter(\.isCompleted)

        return Dictionary(grouping: completedSessions) { session in
            calendar.startOfDay(for: startDate(for: session))
        }
        .map { date, sessions in
            StatisticsOverviewDaySection(
                date: date,
                sessions: sessions.sorted { startDate(for: $0) > startDate(for: $1) }
            )
        }
        .sorted { $0.date > $1.date }
    }

    static func startDate(for session: FocusSession) -> Date {
        let end = session.endTime ?? session.startTime
        if
            session.duration > 0,
            session.startTime >= end || abs(session.startTime.timeIntervalSince(end)) < 1
        {
            return end.addingTimeInterval(-session.duration)
        }

        return session.startTime
    }

    static func endDate(for session: FocusSession) -> Date {
        session.endTime ?? session.startTime
    }

    static func timeRangeText(for session: FocusSession) -> String {
        "\(FocusDisplayFormatter.hourMinute(startDate(for: session))) - \(FocusDisplayFormatter.hourMinute(endDate(for: session)))"
    }
}
