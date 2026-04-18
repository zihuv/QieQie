import SwiftUI

struct StatisticsOverviewView: View {
    let statistics: FocusStatistics
    let recentSessions: [FocusSession]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
                summarySection
                recordsSection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(FocusPanelSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var summarySection: some View {
        FocusPanelSection(title: "概览") {
            FocusPanelGroup(horizontalPadding: FocusPanelSpacing.sm, verticalPadding: FocusPanelSpacing.md) {
                VStack(spacing: 0) {
                    ForEach(Array(summaryMetrics.enumerated()), id: \.element.id) { index, metric in
                        summaryMetricRow(metric)

                        if index < summaryMetrics.count - 1 {
                            FocusPanelDivider(leadingInset: FocusPanelSpacing.xl)
                        }
                    }
                }
            }
        }
    }

    private var recordsSection: some View {
        FocusPanelSection(title: "专注记录") {
            if daySections.isEmpty {
                FocusPanelGroup(horizontalPadding: FocusPanelSpacing.sm, verticalPadding: FocusPanelSpacing.sm) {
                    Text("完成一次专注后显示最近记录")
                        .font(FocusPanelTypography.supportingText)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                }
            } else {
                FocusPanelGroup(horizontalPadding: FocusPanelSpacing.md, verticalPadding: FocusPanelSpacing.sm) {
                    VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
                        ForEach(Array(daySections.enumerated()), id: \.element.id) { index, section in
                            daySection(section)

                            if index < daySections.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
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
        HStack(alignment: .center, spacing: FocusPanelSpacing.lg) {
            Text(metric.title)
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)

            Spacer(minLength: FocusPanelSpacing.sm)

            Text(metric.value)
                .font(FocusPanelTypography.metricValue)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()
        }
        .padding(.horizontal, FocusPanelSpacing.sm)
        .padding(.vertical, FocusPanelSpacing.sm)
    }

    private func daySection(_ section: StatisticsOverviewDaySection) -> some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
            Text(FocusDisplayFormatter.preciseDate(section.date))
                .font(FocusPanelTypography.dateLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
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
        FocusTimelineRow(
            timeText: StatisticsOverviewGrouping.timeRangeText(for: session),
            tagTitle: session.displayTagName,
            title: taskName(for: session),
            usesPlaceholderTitle: session.displayNote == nil,
            durationText: FocusDisplayFormatter.compactDuration(session.duration),
            showsConnector: showsConnector
        )
    }

    private func taskName(for session: FocusSession) -> String {
        session.displayNote ?? "未填写说明"
    }
}

struct StatisticsOverviewMetric: Identifiable {
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
