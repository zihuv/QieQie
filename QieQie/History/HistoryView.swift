import Charts
import SwiftUI

enum StatisticsWindowLayout {
    static let defaultSize = CGSize(width: 880, height: 640)
    static let minSize = CGSize(width: 800, height: 560)
}

struct HistoryView: View {
    let historyManager: FocusHistoryManager

    @State private var detailQuery = FocusStatisticsQuery(granularity: .week, anchorDate: Date())
    @State private var trendQuery = FocusStatisticsQuery(granularity: .week, anchorDate: Date())
    @State private var detailSnapshot = FocusStatisticsPageSnapshot()
    @State private var trendSnapshot = FocusStatisticsPageSnapshot()
    @State private var selectedTrendPointDate: Date?

    private let summaryColumns = [
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg),
        GridItem(.flexible(), spacing: FocusPanelSpacing.lg)
    ]

    private let detailCardHeight: CGFloat = 356
    private let trendSelectionCalloutWidth: CGFloat = 132
    private let trendPlotHeight: CGFloat = 228
    private let trendSelectionCalloutY: CGFloat = 28
    private let detailGranularityOptions: [FocusStatisticsGranularity] = [.day, .week, .month, .year]
    private let trendGranularityOptions: [FocusStatisticsGranularity] = [.week, .month, .year]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xl) {
                summarySection

                HStack(alignment: .top, spacing: FocusPanelSpacing.lg) {
                    focusDetailSection
                    recordsSection
                }

                trendSection
            }
            .padding(FocusPanelSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: StatisticsWindowLayout.minSize.width,
            maxWidth: .infinity,
            minHeight: StatisticsWindowLayout.minSize.height,
            maxHeight: .infinity,
            alignment: .top
        )
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear(perform: loadData)
        .onChange(of: detailQuery) { _, _ in
            loadData()
        }
        .onChange(of: trendQuery) { _, _ in
            loadData()
        }
    }

    private var summarySection: some View {
        FocusPanelSection(title: "概览", titleColor: .primary) {
            LazyVGrid(columns: summaryColumns, spacing: FocusPanelSpacing.lg) {
                ForEach(summaryMetrics) { metric in
                    summaryMetricTile(metric)
                }
            }
        }
    }

    private var focusDetailSection: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            sectionHeader(
                title: "专注详情",
                subtitle: "按分类统计",
                query: detailQuery,
                granularityOptions: detailGranularityOptions,
                canNavigateForward: !effectiveDetailQuery.isCurrentPeriod(),
                onGranularityChange: { granularity in
                    detailQuery = FocusStatisticsQuery(granularity: granularity, anchorDate: detailQuery.anchorDate)
                },
                onShift: { offset in
                    detailQuery = effectiveDetailQuery.shifted(by: offset)
                }
            )

            Group {
                if detailSnapshot.tagSummaries.isEmpty {
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
                                .foregroundStyle(tagColor(for: index))
                            }
                        }
                        .chartLegend(.hidden)
                        .frame(width: 224, height: 224)
                        .chartBackground { _ in
                            VStack(spacing: FocusPanelSpacing.xxs) {
                                Text(FocusDisplayFormatter.compactDuration(detailSnapshot.periodTotalDuration))
                                    .font(FocusPanelTypography.chartValue)
                                    .monospacedDigit()

                                Text("\(detailSnapshot.periodSessionCount) 次专注")
                                    .font(FocusPanelTypography.supportingText)
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
                            ForEach(Array(detailSnapshot.tagSummaries.prefix(6).enumerated()), id: \.element.id) { index, item in
                                tagSummaryRow(item, color: tagColor(for: index))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: detailCardHeight, maxHeight: detailCardHeight, alignment: .topLeading)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text("专注记录")
                    .font(FocusPanelTypography.sectionTitle)
                Text(FocusDisplayFormatter.periodTitle(for: effectiveDetailQuery))
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            if detailSnapshot.recentSessions.isEmpty {
                Text("当前周期还没有已完成的专注记录")
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
                        ForEach(Array(detailDaySections.enumerated()), id: \.element.id) { index, section in
                            dayTimelineSection(section)

                            if index < detailDaySections.count - 1 {
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
            minHeight: detailCardHeight,
            maxHeight: detailCardHeight,
            alignment: .topLeading
        )
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            sectionHeader(
                title: "专注趋势",
                subtitle: "按时长查看变化",
                query: trendQuery,
                granularityOptions: trendGranularityOptions,
                canNavigateForward: !effectiveTrendQuery.isCurrentPeriod(),
                onGranularityChange: { granularity in
                    trendQuery = FocusStatisticsQuery(granularity: granularity, anchorDate: trendQuery.anchorDate)
                },
                onShift: { offset in
                    trendQuery = effectiveTrendQuery.shifted(by: offset)
                }
            )

            Chart {
                ForEach(displayTrendPoints) { point in
                    AreaMark(
                        x: .value("位置", point.categoryID),
                        y: .value("时长", point.point.totalDuration / 60)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("位置", point.categoryID),
                        y: .value("时长", point.point.totalDuration / 60)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.accentColor)

                    PointMark(
                        x: .value("位置", point.categoryID),
                        y: .value("时长", point.point.totalDuration / 60)
                    )
                    .foregroundStyle(Color.white)
                    .symbolSize(point.point.totalDuration > 0 ? 42 : 28)
                    .annotation(position: .overlay) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(
                                width: point.point.totalDuration > 0 ? 7 : 5,
                                height: point.point.totalDuration > 0 ? 7 : 5
                            )
                    }
                }

                if let selectedTrendPointEntry {
                    RuleMark(x: .value("选中位置", selectedTrendPointEntry.categoryID))
                        .foregroundStyle(Color.accentColor.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    PointMark(
                        x: .value("选中位置", selectedTrendPointEntry.categoryID),
                        y: .value("时长", selectedTrendPointEntry.point.totalDuration / 60)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(72)
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: 0...trendYScaleUpperBound)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.12))
                    AxisTick()
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(FocusDisplayFormatter.chartDurationAxisLabel(minutes: minutes))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: trendAxisValues) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.clear)
                    AxisTick()
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel(centered: true) {
                        if let categoryID = value.as(String.self),
                           let point = trendPoint(forCategoryID: categoryID) {
                            Text(point.point.label)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let plotRect = geometry[plotFrame]

                        ZStack(alignment: .topLeading) {
                            trendSelectionOverlay(proxy: proxy, geometry: geometry, plotRect: plotRect)

                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .frame(width: plotRect.width, height: plotRect.height)
                                .offset(x: plotRect.minX, y: plotRect.minY)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            updateTrendSelection(at: value.location, proxy: proxy, geometry: geometry)
                                        }
                                )
                        }
                    }
                }
            }
            .frame(height: trendPlotHeight)
            .overlay {
                if trendSnapshot.periodTotalDuration == 0 {
                    Text("当前周期暂无数据")
                        .font(FocusPanelTypography.bodyLabel)
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private func sectionHeader(
        title: String,
        subtitle: String,
        query: FocusStatisticsQuery,
        granularityOptions: [FocusStatisticsGranularity],
        canNavigateForward: Bool,
        onGranularityChange: @escaping (FocusStatisticsGranularity) -> Void,
        onShift: @escaping (Int) -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: FocusPanelSpacing.lg) {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                Text(title)
                    .font(FocusPanelTypography.sectionTitle)

                Text(subtitle)
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: FocusPanelSpacing.sm)

            VStack(alignment: .trailing, spacing: FocusPanelSpacing.sm) {
                Picker("", selection: Binding(
                    get: { query.granularity },
                    set: onGranularityChange
                )) {
                    ForEach(granularityOptions) { granularity in
                        Text(granularity.title).tag(granularity)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: segmentedControlWidth(for: granularityOptions))

                HStack(spacing: FocusPanelSpacing.xxs) {
                    Button(action: { onShift(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Text(FocusDisplayFormatter.periodTitle(for: query.normalized()))
                        .font(FocusPanelTypography.bodyLabel)
                        .monospacedDigit()
                        .frame(minWidth: 108)

                    Button(action: { onShift(1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canNavigateForward)
                }
            }
        }
    }

    private func summaryMetricTile(_ metric: StatisticsOverviewMetric) -> some View {
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

    private func tagSummaryRow(_ item: FocusTagSummary, color: Color) -> some View {
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

                Text(detailShareText(for: item))
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func dayTimelineSection(_ section: StatisticsOverviewDaySection) -> some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
            Text(FocusDisplayFormatter.preciseDate(section.date))
                .font(FocusPanelTypography.dateLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: FocusPanelSpacing.xxs) {
                ForEach(Array(section.sessions.enumerated()), id: \.element.id) { index, session in
                    timelineSessionRow(
                        session,
                        showsConnector: index < section.sessions.count - 1
                    )
                }
            }
        }
    }

    private func timelineSessionRow(_ session: FocusSession, showsConnector: Bool) -> some View {
        FocusTimelineRow(
            timeText: StatisticsOverviewGrouping.timeRangeText(for: session),
            tagTitle: session.displayTagName,
            title: session.displayNote ?? "未填写说明",
            usesPlaceholderTitle: session.displayNote == nil,
            durationText: FocusDisplayFormatter.compactDuration(session.duration),
            showsConnector: showsConnector
        )
    }

    private func loadData() {
        detailSnapshot = historyManager.getStatisticsPageSnapshot(query: effectiveDetailQuery)
        trendSnapshot = historyManager.getStatisticsPageSnapshot(query: effectiveTrendQuery)
        if let selectedTrendPointDate,
           !trendSnapshot.trendPoints.contains(where: { $0.date == selectedTrendPointDate }) {
            self.selectedTrendPointDate = nil
        }
    }

    private func detailShareText(for item: FocusTagSummary) -> String {
        guard detailSnapshot.periodTotalDuration > 0 else { return "0%" }
        return FocusDisplayFormatter.percentage(item.totalDuration / detailSnapshot.periodTotalDuration)
    }

    private func tagColor(for index: Int) -> Color {
        FocusPanelColor.chartColor(for: index)
    }

    private var summaryMetrics: [StatisticsOverviewMetric] {
        [
            StatisticsOverviewMetric(title: "今日番茄", value: "\(detailSnapshot.overview.today.sessionCount)"),
            StatisticsOverviewMetric(title: "总番茄", value: "\(detailSnapshot.overview.allTime.sessionCount)"),
            StatisticsOverviewMetric(
                title: "今日专注时长",
                value: FocusDisplayFormatter.compactDuration(detailSnapshot.overview.today.totalDuration)
            ),
            StatisticsOverviewMetric(
                title: "总专注时长",
                value: FocusDisplayFormatter.compactDuration(detailSnapshot.overview.allTime.totalDuration)
            )
        ]
    }

    private var effectiveDetailQuery: FocusStatisticsQuery {
        detailQuery.normalized()
    }

    private var effectiveTrendQuery: FocusStatisticsQuery {
        trendQuery.normalized()
    }

    private var displayTrendPoints: [TrendChartDisplayPoint] {
        trendSnapshot.trendPoints.map { point in
            TrendChartDisplayPoint(
                point: point,
                categoryID: trendCategoryID(for: point)
            )
        }
    }

    private var trendAxisValues: [String] {
        switch effectiveTrendQuery.granularity {
        case .day:
            let evenHours = displayTrendPoints.filter {
                FocusCalendar.analytics.component(.hour, from: $0.point.date).isMultiple(of: 4)
            }
            let axisValues = evenHours.map(\.categoryID)
            return axisValues.isEmpty ? displayTrendPoints.map(\.categoryID) : axisValues
        case .week, .year:
            return displayTrendPoints.map(\.categoryID)
        case .month:
            let oddDays = displayTrendPoints.filter {
                FocusCalendar.analytics.component(.day, from: $0.point.date).isMultiple(of: 2) == false
            }
            let axisValues = oddDays.map(\.categoryID)
            return axisValues.isEmpty ? displayTrendPoints.map(\.categoryID) : axisValues
        }
    }

    private var chartTagSummaries: [FocusTagSummary] {
        let topTags = Array(detailSnapshot.tagSummaries.prefix(5))
        let remainingTags = detailSnapshot.tagSummaries.dropFirst(5)
        guard !remainingTags.isEmpty else { return topTags }

        let otherSummary = FocusTagSummary(
            tagName: "其他",
            totalDuration: remainingTags.reduce(0) { $0 + $1.totalDuration },
            sessionCount: remainingTags.reduce(0) { $0 + $1.sessionCount }
        )

        return topTags + [otherSummary]
    }

    private var detailDaySections: [StatisticsOverviewDaySection] {
        StatisticsOverviewGrouping.sections(from: detailSnapshot.recentSessions)
    }

    private var selectedTrendPoint: FocusTrendPoint? {
        guard let selectedTrendPointDate else { return nil }
        return trendSnapshot.trendPoints.first { $0.date == selectedTrendPointDate }
    }

    private var selectedTrendPointEntry: TrendChartDisplayPoint? {
        guard let selectedTrendPointDate else { return nil }
        return displayTrendPoints.first { $0.point.date == selectedTrendPointDate }
    }

    private var trendYScaleUpperBound: Double {
        let maximumMinutes = displayTrendPoints.map { $0.point.totalDuration / 60 }.max() ?? 0
        guard maximumMinutes > 0 else { return 60 }

        let step: Double
        switch maximumMinutes {
        case ...60:
            step = 10
        case ...180:
            step = 30
        default:
            step = 60
        }

        return max(step, ceil((maximumMinutes * 1.15) / step) * step)
    }

    private func trendSelectionCallout(_ point: FocusTrendPoint) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(
                FocusDisplayFormatter.chartSelectionTitle(
                    for: point.date,
                    granularity: effectiveTrendQuery.granularity
                )
            )
            .font(FocusPanelTypography.supportingText)
            .foregroundColor(.secondary)

            Text(FocusDisplayFormatter.compactDuration(point.totalDuration))
                .font(FocusPanelTypography.bodyLabel)
                .monospacedDigit()

            Text("\(point.sessionCount) 次专注")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, FocusPanelSpacing.md)
        .padding(.vertical, FocusPanelSpacing.sm)
        .focusPanelFieldSurface(cornerRadius: FocusPanelCornerRadius.large)
    }

    @ViewBuilder
    private func trendSelectionOverlay(
        proxy: ChartProxy,
        geometry: GeometryProxy,
        plotRect: CGRect
    ) -> some View {
        if let selectedTrendPointEntry,
           let plotXRange = proxy.positionRange(forX: selectedTrendPointEntry.categoryID) {
            trendSelectionCallout(selectedTrendPointEntry.point)
                .frame(width: trendSelectionCalloutWidth, alignment: .leading)
                .position(
                    x: clampedTrendCalloutX(
                        plotRect.minX + ((plotXRange.lowerBound + plotXRange.upperBound) / 2),
                        containerWidth: geometry.size.width
                    ),
                    y: trendSelectionCalloutY
                )
                .allowsHitTesting(false)
        }
    }

    private func clampedTrendCalloutX(_ value: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let halfWidth = trendSelectionCalloutWidth / 2
        return min(
            max(value, halfWidth + FocusPanelSpacing.sm),
            max(halfWidth + FocusPanelSpacing.sm, containerWidth - halfWidth - FocusPanelSpacing.sm)
        )
    }

    private func updateTrendSelection(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedTrendPointDate = nil
            return
        }

        let plotAreaFrame = geometry[plotFrame]
        let plotX = location.x - plotAreaFrame.origin.x
        guard plotX >= 0, plotX <= plotAreaFrame.width else {
            selectedTrendPointDate = nil
            return
        }

        if let categoryID = proxy.value(atX: plotX, as: String.self),
           let point = trendPoint(forCategoryID: categoryID) {
            selectedTrendPointDate = point.point.date
        } else {
            selectedTrendPointDate = nearestTrendPoint(at: plotX, proxy: proxy)?.point.date
        }
    }

    private func nearestTrendPoint(at plotX: CGFloat, proxy: ChartProxy) -> TrendChartDisplayPoint? {
        displayTrendPoints.min {
            let leftDistance = distance(from: plotX, to: $0, proxy: proxy)
            let rightDistance = distance(from: plotX, to: $1, proxy: proxy)
            return leftDistance < rightDistance
        }
    }

    private func trendPoint(forCategoryID categoryID: String) -> TrendChartDisplayPoint? {
        displayTrendPoints.first { $0.categoryID == categoryID }
    }

    private func distance(from plotX: CGFloat, to point: TrendChartDisplayPoint, proxy: ChartProxy) -> CGFloat {
        guard let range = proxy.positionRange(forX: point.categoryID) else {
            return .greatestFiniteMagnitude
        }

        let midpoint = (range.lowerBound + range.upperBound) / 2
        return abs(midpoint - plotX)
    }

    private func trendCategoryID(for point: FocusTrendPoint) -> String {
        switch effectiveTrendQuery.granularity {
        case .day:
            return FocusDisplayFormatter.preciseDateTime(point.date)
        case .week, .month:
            return FocusDisplayFormatter.preciseDate(point.date)
        case .year:
            return "\(FocusDisplayFormatter.preciseDate(point.date))-\(FocusDisplayFormatter.chartLabel(for: point.date, granularity: .year))"
        }
    }

    private func segmentedControlWidth(for options: [FocusStatisticsGranularity]) -> CGFloat {
        CGFloat(max(156, options.count * 44))
    }
}

private struct TrendChartDisplayPoint: Identifiable {
    let point: FocusTrendPoint
    let categoryID: String

    var id: Date { point.date }
}

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
