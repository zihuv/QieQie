import Charts
import SwiftUI

/// 历史记录视图
struct HistoryView: View {
    /// 历史记录管理器
    let historyManager: FocusHistoryManager

    /// 返回按钮绑定
    @Binding var showHistory: Bool

    /// 按日期分组的会话数据
    @State private var groupedSessions: [(date: Date, sessions: [FocusSession])] = []

    /// 总统计
    @State private var totalStats: FocusStatistics = FocusStatistics()

    @State private var historyInsights = FocusHistoryInsights()

    /// 要删除的会话
    @State private var sessionToDelete: FocusSession?
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 头部
            headerSection

            // 统计信息
            statisticsSection

            Divider()

            // 历史记录列表
            historyList

            // 返回按钮
            Button(action: { showHistory = false }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .frame(width: 360, height: 540)
        .onAppear {
            loadData()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("确定要删除这条记录吗？")
        }
    }

    /// 头部
    private var headerSection: some View {
        HStack {
            Text("历史记录")
                .font(.headline)
            Spacer()
        }
    }

    /// 统计信息
    private var statisticsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                summaryCard(title: "总次数", value: "\(totalStats.sessionCount)", tint: .blue)
                summaryCard(title: "总时长", value: FocusStatistics.formatDuration(totalStats.allTimeTotal), tint: .orange)
                summaryCard(title: "已完成", value: "\(totalStats.completedCount)", tint: .green)
            }

            trendSection

            LazyVGrid(columns: insightGridColumns, spacing: 8) {
                insightCard(title: "完成率", value: FocusDisplayFormatter.percentage(totalStats.completionRate))
                insightCard(title: "平均每次", value: FocusStatistics.formatDuration(totalStats.averageSessionDuration))
                insightCard(title: "最长单次", value: FocusStatistics.formatDuration(historyInsights.longestSessionDuration))
                insightCard(title: "连续记录", value: "\(historyInsights.currentStreak)天")
            }
        }
    }

    /// 历史记录列表
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if groupedSessions.isEmpty {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(groupedSessions, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            // 日期标题
                            Text(FocusDisplayFormatter.date(group.date))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            // 会话列表
                            ForEach(group.sessions, id: \.id) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 会话行
    private func sessionRow(_ session: FocusSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Text(FocusDisplayFormatter.time(session.startTime))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(FocusStatistics.formatDuration(session.duration))
                .font(.system(size: 12))
                .fontWeight(.medium)

            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            // 删除按钮
            Button(action: {
                sessionToDelete = session
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .padding(.trailing, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - 私有方法

    /// 加载数据
    private func loadData() {
        let snapshot = historyManager.getHistorySnapshot()
        groupedSessions = snapshot.groupedSessions
        totalStats = snapshot.totalStatistics
        historyInsights = snapshot.insights
    }

    /// 删除会话
    private func deleteSession() {
        guard let session = sessionToDelete else { return }

        if historyManager.deleteSession(session) {
            loadData()
        }
    }

    private var insightGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("近 7 天趋势")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("累计 \(FocusStatistics.formatDuration(recentTrendTotal))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if totalStats.sessionCount == 0 {
                Text("开始一次专注后，这里会显示最近 7 天的变化。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(historyInsights.recentDailyTrend) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("时长", point.totalDuration)
                        )
                        .foregroundStyle(barColor(for: point.date))
                    }

                    if averageRecentDailyDuration > 0 {
                        RuleMark(y: .value("日均", averageRecentDailyDuration))
                            .foregroundStyle(Color.secondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: historyInsights.recentDailyTrend.map(\.date)) { value in
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(FocusDisplayFormatter.weekday(date))
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.18))
                        .cornerRadius(8)
                }
                .frame(height: 120)

                Text(trendSummaryText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }

    private func summaryCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func insightCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(8)
    }

    private var recentTrendTotal: TimeInterval {
        historyInsights.recentDailyTrend.reduce(0) { $0 + $1.totalDuration }
    }

    private var averageRecentDailyDuration: TimeInterval {
        guard !historyInsights.recentDailyTrend.isEmpty else { return 0 }
        return recentTrendTotal / Double(historyInsights.recentDailyTrend.count)
    }

    private var recentTrendSessionCount: Int {
        historyInsights.recentDailyTrend.reduce(0) { $0 + $1.sessionCount }
    }

    private var recentTrendCompletedCount: Int {
        historyInsights.recentDailyTrend.reduce(0) { $0 + $1.completedCount }
    }

    private var trendSummaryText: String {
        let averageText = FocusStatistics.formatDuration(averageRecentDailyDuration)
        return "日均 \(averageText)，近 7 天完成 \(recentTrendCompletedCount)/\(recentTrendSessionCount) 次。"
    }

    private func barColor(for date: Date) -> Color {
        Calendar.current.isDateInToday(date) ? .accentColor : .accentColor.opacity(0.35)
    }
}
