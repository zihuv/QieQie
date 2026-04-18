import Charts
import SwiftUI

struct HistoryTrendSection: View {
    let query: FocusStatisticsQuery
    let snapshot: FocusStatisticsPageSnapshot
    @Binding var selectedTrendPointDate: Date?
    let granularityOptions: [FocusStatisticsGranularity]
    let onGranularityChange: (FocusStatisticsGranularity) -> Void
    let onShift: (Int) -> Void

    private let trendSelectionCalloutWidth: CGFloat = 132
    private let trendPlotHeight: CGFloat = 228
    private let trendSelectionCalloutY: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
            HistorySectionHeader(
                title: "专注趋势",
                subtitle: "按时长查看变化",
                query: effectiveQuery,
                granularityOptions: granularityOptions,
                canNavigateForward: !effectiveQuery.isCurrentPeriod(),
                onGranularityChange: onGranularityChange,
                onShift: onShift
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
                                            updateTrendSelection(
                                                at: value.location,
                                                proxy: proxy,
                                                geometry: geometry
                                            )
                                        }
                                )
                        }
                    }
                }
            }
            .frame(height: trendPlotHeight)
            .overlay {
                if snapshot.periodTotalDuration == 0 {
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

    private var effectiveQuery: FocusStatisticsQuery {
        query.normalized()
    }

    private var displayTrendPoints: [TrendChartDisplayPoint] {
        snapshot.trendPoints.map { point in
            TrendChartDisplayPoint(
                point: point,
                categoryID: trendCategoryID(for: point)
            )
        }
    }

    private var trendAxisValues: [String] {
        switch effectiveQuery.granularity {
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
                    granularity: effectiveQuery.granularity
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
        switch effectiveQuery.granularity {
        case .day:
            return FocusDisplayFormatter.preciseDateTime(point.date)
        case .week, .month:
            return FocusDisplayFormatter.preciseDate(point.date)
        case .year:
            return "\(FocusDisplayFormatter.preciseDate(point.date))-\(FocusDisplayFormatter.chartLabel(for: point.date, granularity: .year))"
        }
    }
}

private struct TrendChartDisplayPoint: Identifiable {
    let point: FocusTrendPoint
    let categoryID: String

    var id: Date { point.date }
}
