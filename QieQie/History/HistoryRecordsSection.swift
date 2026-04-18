import SwiftUI

struct HistoryRecordsSection: View {
    let query: FocusStatisticsQuery
    let recentSessions: [FocusSession]
    let cardHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text("专注记录")
                    .font(FocusPanelTypography.sectionTitle)
                Text(FocusDisplayFormatter.periodTitle(for: effectiveQuery))
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            if daySections.isEmpty {
                Text("当前周期还没有已完成的专注记录")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
                        ForEach(Array(daySections.enumerated()), id: \.element.id) { index, section in
                            HistoryTimelineDaySection(section: section)

                            if index < daySections.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, FocusPanelSpacing.xxs)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(
            minWidth: 304,
            maxWidth: 304,
            minHeight: cardHeight,
            maxHeight: cardHeight,
            alignment: .topLeading
        )
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var effectiveQuery: FocusStatisticsQuery {
        query.normalized()
    }

    private var daySections: [StatisticsOverviewDaySection] {
        StatisticsOverviewGrouping.sections(from: recentSessions)
    }
}

private struct HistoryTimelineDaySection: View {
    let section: StatisticsOverviewDaySection

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
            Text(FocusDisplayFormatter.preciseDate(section.date))
                .font(FocusPanelTypography.dateLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                ForEach(Array(section.sessions.enumerated()), id: \.element.id) { index, session in
                    FocusTimelineRow(
                        timeText: StatisticsOverviewGrouping.timeRangeText(for: session),
                        tagTitle: session.displayTagName,
                        title: session.displayNote ?? "未填写说明",
                        usesPlaceholderTitle: session.displayNote == nil,
                        durationText: FocusDisplayFormatter.compactDuration(session.duration),
                        showsConnector: index < section.sessions.count - 1
                    )
                }
            }
        }
    }
}
