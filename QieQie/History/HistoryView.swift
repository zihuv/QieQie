import Charts
import SwiftUI

enum StatisticsWindowLayout {
    static let defaultSize = CGSize(width: 480, height: 420)
    static let minSize = CGSize(width: 440, height: 380)
}

struct HistoryView: View {
    let historyManager: FocusHistoryManager

    @State private var statistics = FocusStatistics()
    @State private var historyInsights = FocusHistoryInsights()
    @State private var showClearConfirmation = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summarySection
            trendSection
            actionSection
        }
        .padding(16)
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
        LazyVGrid(columns: gridColumns, spacing: 10) {
            summaryCard(title: "今日", period: statistics.today)
            summaryCard(title: "本周", period: statistics.week)
            summaryCard(title: "本月", period: statistics.month)
            summaryCard(title: "总计", period: statistics.allTime)
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("近 7 天")
                    .font(.system(size: 14, weight: .semibold))
                Text("累计 \(FocusStatistics.formatDuration(recentTrendTotal))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if statistics.isEmpty {
                Text("完成一次专注后显示趋势")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
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
                .frame(height: 128)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(12)
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
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(period.sessionCount) 次")
                .font(.system(size: 15, weight: .semibold))

            Text(FocusStatistics.formatDuration(period.totalDuration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(12)
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
