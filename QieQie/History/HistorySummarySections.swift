import Charts
import SwiftUI

struct HistorySummarySection: View {
    let overview: FocusStatistics
    let columns: [GridItem]

    var body: some View {
        FocusPanelSection(title: "概览", titleColor: .primary) {
            LazyVGrid(columns: columns, spacing: FocusPanelSpacing.lg) {
                ForEach(summaryMetrics) { metric in
                    HistorySummaryMetricTile(metric: metric)
                }
            }
        }
    }

    private var summaryMetrics: [HistorySummaryMetric] {
        [
            HistorySummaryMetric(title: "今日番茄", value: "\(overview.today.sessionCount)"),
            HistorySummaryMetric(title: "总番茄", value: "\(overview.allTime.sessionCount)"),
            HistorySummaryMetric(
                title: "今日专注时长",
                value: FocusDisplayFormatter.compactDuration(overview.today.totalDuration)
            ),
            HistorySummaryMetric(
                title: "总专注时长",
                value: FocusDisplayFormatter.compactDuration(overview.allTime.totalDuration)
            )
        ]
    }
}

struct HistoryFocusDetailSection: View {
    let query: FocusStatisticsQuery
    let snapshot: FocusStatisticsPageSnapshot
    let granularityOptions: [FocusStatisticsGranularity]
    let cardHeight: CGFloat
    let onGranularityChange: (FocusStatisticsGranularity) -> Void
    let onShift: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            HistorySectionHeader(
                title: "专注详情",
                subtitle: "按分类统计",
                query: effectiveQuery,
                granularityOptions: granularityOptions,
                canNavigateForward: !effectiveQuery.isCurrentPeriod(),
                onGranularityChange: onGranularityChange,
                onShift: onShift
            )

            Group {
                if snapshot.tagSummaries.isEmpty {
                    VStack(spacing: FocusPanelSpacing.lg) {
                        Circle()
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 18)
                            .frame(width: 178, height: 178)
                            .overlay(
                                Text("暂无数据")
                                    .font(FocusPanelTypography.bodyLabel)
                                    .foregroundColor(.secondary)
                            )

                        Text("当前周期没有已完成的专注记录")
                            .font(FocusPanelTypography.supportingText)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .center, spacing: FocusPanelSpacing.xxl) {
                        Chart {
                            ForEach(Array(chartTagSummaries.enumerated()), id: \.element.id) { index, item in
                                SectorMark(
                                    angle: .value("时长", item.totalDuration),
                                    innerRadius: .ratio(0.68),
                                    angularInset: 2
                                )
                                .cornerRadius(4)
                                .foregroundStyle(FocusPanelColor.chartColor(for: index))
                            }
                        }
                        .chartLegend(.hidden)
                        .frame(width: 224, height: 224)
                        .chartBackground { _ in
                            VStack(spacing: FocusPanelSpacing.xxs) {
                                Text(FocusDisplayFormatter.compactDuration(snapshot.periodTotalDuration))
                                    .font(FocusPanelTypography.chartValue)
                                    .monospacedDigit()

                                Text("\(snapshot.periodSessionCount) 次专注")
                                    .font(FocusPanelTypography.supportingText)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
                            ForEach(Array(snapshot.tagSummaries.prefix(6).enumerated()), id: \.element.id) { index, item in
                                HistoryTagSummaryRow(
                                    item: item,
                                    color: FocusPanelColor.chartColor(for: index),
                                    shareText: detailShareText(for: item)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var effectiveQuery: FocusStatisticsQuery {
        query.normalized()
    }

    private var chartTagSummaries: [FocusTagSummary] {
        let topTags = Array(snapshot.tagSummaries.prefix(5))
        let remainingTags = snapshot.tagSummaries.dropFirst(5)
        guard !remainingTags.isEmpty else { return topTags }

        let otherSummary = FocusTagSummary(
            tagName: "其他",
            totalDuration: remainingTags.reduce(0) { $0 + $1.totalDuration },
            sessionCount: remainingTags.reduce(0) { $0 + $1.sessionCount }
        )

        return topTags + [otherSummary]
    }

    private func detailShareText(for item: FocusTagSummary) -> String {
        guard snapshot.periodTotalDuration > 0 else { return "0%" }
        return FocusDisplayFormatter.percentage(item.totalDuration / snapshot.periodTotalDuration)
    }
}

private struct HistorySummaryMetric: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct HistorySummaryMetricTile: View {
    let metric: HistorySummaryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
            Text(metric.value)
                .font(FocusPanelTypography.heroMetric)
                .foregroundColor(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(metric.title)
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
    }
}

private struct HistoryTagSummaryRow: View {
    let item: FocusTagSummary
    let color: Color
    let shareText: String

    var body: some View {
        HStack(alignment: .center, spacing: FocusPanelSpacing.md) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text(item.tagName)
                    .font(FocusPanelTypography.bodyLabel)
                    .lineLimit(1)

                Text("\(item.sessionCount) 次")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: FocusPanelSpacing.sm)

            VStack(alignment: .trailing, spacing: FocusPanelSpacing.xxs) {
                Text(FocusDisplayFormatter.compactDuration(item.totalDuration))
                    .font(FocusPanelTypography.bodyLabel)
                    .monospacedDigit()

                Text(shareText)
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
